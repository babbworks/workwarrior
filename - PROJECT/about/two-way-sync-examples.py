#!/usr/bin/env python3
"""
Two-Way Sync Service - Code Examples
=====================================

This file contains example implementations of key components for a
bidirectional sync service between TaskWarrior and external issue trackers.

NOTE: This is EXPLORATORY CODE ONLY - not for production use.
"""

import json
import sqlite3
import hashlib
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from enum import Enum


# ============================================================================
# DATA MODELS
# ============================================================================

class SyncDirection(Enum):
    PULL = "pull"
    PUSH = "push"
    BIDIRECTIONAL = "bidirectional"


class ConflictStrategy(Enum):
    LAST_WRITE_WINS = "last_write_wins"
    EXTERNAL_AUTHORITATIVE = "external_authoritative"
    MANUAL = "manual"
    FIELD_LEVEL_MERGE = "field_level_merge"


class ChangeType(Enum):
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"


@dataclass
class TaskState:
    """Represents the state of a task at a point in time"""
    uuid: str
    description: str
    status: str
    priority: Optional[str]
    tags: List[str]
    annotations: List[str]
    modified: datetime
    
    def checksum(self) -> str:
        """Generate checksum for quick comparison"""
        data = f"{self.description}|{self.status}|{self.priority}|{','.join(sorted(self.tags))}"
        return hashlib.sha256(data.encode()).hexdigest()


@dataclass
class IssueState:
    """Represents the state of an external issue"""
    service_type: str
    service_id: str
    title: str
    state: str
    priority: Optional[str]
    labels: List[str]
    comments: List[str]
    updated: datetime
    
    def checksum(self) -> str:
        """Generate checksum for quick comparison"""
        data = f"{self.title}|{self.state}|{self.priority}|{','.join(sorted(self.labels))}"
        return hashlib.sha256(data.encode()).hexdigest()


@dataclass
class SyncState:
    """Tracks sync state for a task-issue pair"""
    task_uuid: str
    service_type: str
    service_id: str
    last_sync_time: datetime
    last_local_state: Optional[TaskState]
    last_remote_state: Optional[IssueState]
    local_checksum: str
    remote_checksum: str
    conflict_count: int = 0
    sync_direction: SyncDirection = SyncDirection.BIDIRECTIONAL


@dataclass
class Conflict:
    """Represents a sync conflict"""
    task_uuid: str
    field: str
    local_value: Any
    remote_value: Any
    last_known_value: Any
    conflict_time: datetime


# ============================================================================
# FIELD MAPPER
# ============================================================================

class FieldMapper:
    """Maps fields between TaskWarrior and external services"""
    
    # GitHub mappings
    GITHUB_MAPPINGS = {
        'title': 'description',
        'state': 'status',
        'labels': 'tags',
    }
    
    # Status mappings
    STATUS_TO_GITHUB = {
        'pending': 'open',
        'started': 'open',
        'completed': 'closed',
        'deleted': 'closed',
    }
    
    GITHUB_TO_STATUS = {
        'open': 'pending',
        'closed': 'completed',
    }
    
    # Priority mappings
    PRIORITY_TO_GITHUB = {
        'H': 'high',
        'M': 'medium',
        'L': 'low',
    }
    
    GITHUB_TO_PRIORITY = {
        'high': 'H',
        'medium': 'M',
        'low': 'L',
    }
    
    @classmethod
    def task_to_github(cls, task: TaskState) -> Dict[str, Any]:
        """Convert TaskWarrior task to GitHub issue format"""
        issue = {
            'title': task.description,
            'state': cls.STATUS_TO_GITHUB.get(task.status, 'open'),
            'labels': task.tags,
        }
        
        # Add priority label if present
        if task.priority:
            priority_label = f"priority:{cls.PRIORITY_TO_GITHUB.get(task.priority, 'medium')}"
            if priority_label not in issue['labels']:
                issue['labels'].append(priority_label)
        
        # Convert annotations to body
        if task.annotations:
            issue['body'] = '\n\n'.join(task.annotations)
        
        return issue
    
    @classmethod
    def github_to_task(cls, issue: IssueState) -> Dict[str, Any]:
        """Convert GitHub issue to TaskWarrior task format"""
        task = {
            'description': issue.title,
            'status': cls.GITHUB_TO_STATUS.get(issue.state, 'pending'),
            'tags': [label for label in issue.labels if not label.startswith('priority:')],
        }
        
        # Extract priority from labels
        priority_labels = [l for l in issue.labels if l.startswith('priority:')]
        if priority_labels:
            priority_str = priority_labels[0].split(':')[1]
            task['priority'] = cls.GITHUB_TO_PRIORITY.get(priority_str)
        
        # Convert comments to annotations
        if issue.comments:
            task['annotations'] = issue.comments
        
        return task


# ============================================================================
# CHANGE DETECTOR
# ============================================================================

class ChangeDetector:
    """Detects changes between task states"""
    
    @staticmethod
    def detect_changes(old_state: TaskState, new_state: TaskState) -> Dict[str, Tuple[Any, Any]]:
        """
        Detect what changed between two states.
        Returns dict of {field: (old_value, new_value)}
        """
        changes = {}
        
        if old_state.description != new_state.description:
            changes['description'] = (old_state.description, new_state.description)
        
        if old_state.status != new_state.status:
            changes['status'] = (old_state.status, new_state.status)
        
        if old_state.priority != new_state.priority:
            changes['priority'] = (old_state.priority, new_state.priority)
        
        old_tags = set(old_state.tags)
        new_tags = set(new_state.tags)
        if old_tags != new_tags:
            changes['tags'] = (old_state.tags, new_state.tags)
        
        if old_state.annotations != new_state.annotations:
            changes['annotations'] = (old_state.annotations, new_state.annotations)
        
        return changes
    
    @staticmethod
    def has_conflicts(local_changes: Dict, remote_changes: Dict) -> bool:
        """Check if local and remote changes conflict"""
        # Conflict exists if same field changed on both sides
        return bool(set(local_changes.keys()) & set(remote_changes.keys()))


# ============================================================================
# CONFLICT RESOLVER
# ============================================================================

class ConflictResolver:
    """Resolves conflicts between local and remote changes"""
    
    @staticmethod
    def last_write_wins(
        local_state: TaskState,
        remote_state: IssueState,
        sync_state: SyncState
    ) -> Tuple[str, Any]:
        """
        Simple conflict resolution: most recent change wins.
        Returns: (direction, winning_state)
        """
        if local_state.modified > remote_state.updated:
            return ("push", local_state)
        else:
            return ("pull", remote_state)
    
    @staticmethod
    def field_level_merge(
        local_state: TaskState,
        remote_state: IssueState,
        sync_state: SyncState
    ) -> Dict[str, Any]:
        """
        Smart conflict resolution: merge at field level.
        Returns: merged state as dict
        """
        merged = {}
        
        # Get last known states
        last_local = sync_state.last_local_state
        last_remote = sync_state.last_remote_state
        
        if not last_local or not last_remote:
            # No history, use last write wins
            direction, winner = ConflictResolver.last_write_wins(
                local_state, remote_state, sync_state
            )
            return asdict(winner)
        
        # Check each field
        fields_to_check = ['description', 'status', 'priority', 'tags']
        
        for field in fields_to_check:
            local_val = getattr(local_state, field, None)
            remote_val = getattr(remote_state, FieldMapper.GITHUB_MAPPINGS.get(field, field), None)
            last_local_val = getattr(last_local, field, None)
            last_remote_val = getattr(last_remote, FieldMapper.GITHUB_MAPPINGS.get(field, field), None)
            
            if local_val == remote_val:
                # No conflict
                merged[field] = local_val
            elif local_val == last_local_val:
                # Only remote changed
                merged[field] = remote_val
            elif remote_val == last_remote_val:
                # Only local changed
                merged[field] = local_val
            else:
                # Both changed - need resolution
                # For now, use last write wins for this field
                if local_state.modified > remote_state.updated:
                    merged[field] = local_val
                else:
                    merged[field] = remote_val
        
        return merged
    
    @staticmethod
    def detect_conflicts(
        local_state: TaskState,
        remote_state: IssueState,
        sync_state: SyncState
    ) -> List[Conflict]:
        """
        Detect all conflicts between local and remote states.
        Returns list of Conflict objects.
        """
        conflicts = []
        
        if not sync_state.last_local_state or not sync_state.last_remote_state:
            return conflicts
        
        last_local = sync_state.last_local_state
        last_remote = sync_state.last_remote_state
        
        # Check description
        if (local_state.description != last_local.description and
            remote_state.title != last_remote.title and
            local_state.description != remote_state.title):
            conflicts.append(Conflict(
                task_uuid=local_state.uuid,
                field='description',
                local_value=local_state.description,
                remote_value=remote_state.title,
                last_known_value=last_local.description,
                conflict_time=datetime.now()
            ))
        
        # Check status
        if (local_state.status != last_local.status and
            remote_state.state != last_remote.state):
            conflicts.append(Conflict(
                task_uuid=local_state.uuid,
                field='status',
                local_value=local_state.status,
                remote_value=remote_state.state,
                last_known_value=last_local.status,
                conflict_time=datetime.now()
            ))
        
        # Check tags/labels
        local_tags_changed = set(local_state.tags) != set(last_local.tags)
        remote_labels_changed = set(remote_state.labels) != set(last_remote.labels)
        if local_tags_changed and remote_labels_changed:
            conflicts.append(Conflict(
                task_uuid=local_state.uuid,
                field='tags',
                local_value=local_state.tags,
                remote_value=remote_state.labels,
                last_known_value=last_local.tags,
                conflict_time=datetime.now()
            ))
        
        return conflicts


# ============================================================================
# STATE DATABASE
# ============================================================================

class StateDatabase:
    """Manages sync state persistence"""
    
    def __init__(self, db_path: str = "~/.task/sync_state.db"):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
        self._init_schema()
    
    def _init_schema(self):
        """Initialize database schema"""
        self.conn.executescript("""
            CREATE TABLE IF NOT EXISTS sync_state (
                task_uuid TEXT PRIMARY KEY,
                service_type TEXT NOT NULL,
                service_id TEXT NOT NULL,
                last_sync_time TIMESTAMP NOT NULL,
                last_local_state TEXT,
                last_remote_state TEXT,
                local_checksum TEXT,
                remote_checksum TEXT,
                conflict_count INTEGER DEFAULT 0,
                sync_direction TEXT DEFAULT 'bidirectional',
                UNIQUE(service_type, service_id)
            );
            
            CREATE TABLE IF NOT EXISTS change_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_uuid TEXT NOT NULL,
                change_type TEXT NOT NULL,
                direction TEXT NOT NULL,
                changes TEXT NOT NULL,
                status TEXT DEFAULT 'pending',
                priority INTEGER DEFAULT 5,
                retry_count INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (task_uuid) REFERENCES sync_state(task_uuid)
            );
            
            CREATE TABLE IF NOT EXISTS conflict_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_uuid TEXT NOT NULL,
                conflict_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                conflict_fields TEXT,
                local_values TEXT,
                remote_values TEXT,
                resolution_strategy TEXT,
                resolved_values TEXT,
                FOREIGN KEY (task_uuid) REFERENCES sync_state(task_uuid)
            );
            
            CREATE INDEX IF NOT EXISTS idx_queue_status ON change_queue(status);
            CREATE INDEX IF NOT EXISTS idx_queue_priority ON change_queue(priority DESC);
        """)
        self.conn.commit()
    
    def get_sync_state(self, task_uuid: str) -> Optional[SyncState]:
        """Retrieve sync state for a task"""
        cursor = self.conn.execute(
            "SELECT * FROM sync_state WHERE task_uuid = ?",
            (task_uuid,)
        )
        row = cursor.fetchone()
        
        if not row:
            return None
        
        return SyncState(
            task_uuid=row[0],
            service_type=row[1],
            service_id=row[2],
            last_sync_time=datetime.fromisoformat(row[3]),
            last_local_state=json.loads(row[4]) if row[4] else None,
            last_remote_state=json.loads(row[5]) if row[5] else None,
            local_checksum=row[6],
            remote_checksum=row[7],
            conflict_count=row[8],
            sync_direction=SyncDirection(row[9])
        )
    
    def save_sync_state(self, state: SyncState):
        """Save sync state to database"""
        self.conn.execute("""
            INSERT OR REPLACE INTO sync_state
            (task_uuid, service_type, service_id, last_sync_time,
             last_local_state, last_remote_state, local_checksum,
             remote_checksum, conflict_count, sync_direction)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            state.task_uuid,
            state.service_type,
            state.service_id,
            state.last_sync_time.isoformat(),
            json.dumps(asdict(state.last_local_state)) if state.last_local_state else None,
            json.dumps(asdict(state.last_remote_state)) if state.last_remote_state else None,
            state.local_checksum,
            state.remote_checksum,
            state.conflict_count,
            state.sync_direction.value
        ))
        self.conn.commit()
    
    def queue_change(self, task_uuid: str, change_type: ChangeType,
                     direction: SyncDirection, changes: Dict):
        """Add change to processing queue"""
        self.conn.execute("""
            INSERT INTO change_queue
            (task_uuid, change_type, direction, changes)
            VALUES (?, ?, ?, ?)
        """, (
            task_uuid,
            change_type.value,
            direction.value,
            json.dumps(changes)
        ))
        self.conn.commit()
    
    def get_pending_changes(self, limit: int = 10) -> List[Dict]:
        """Get pending changes from queue"""
        cursor = self.conn.execute("""
            SELECT id, task_uuid, change_type, direction, changes
            FROM change_queue
            WHERE status = 'pending'
            ORDER BY priority DESC, created_at ASC
            LIMIT ?
        """, (limit,))
        
        return [
            {
                'id': row[0],
                'task_uuid': row[1],
                'change_type': ChangeType(row[2]),
                'direction': SyncDirection(row[3]),
                'changes': json.loads(row[4])
            }
            for row in cursor.fetchall()
        ]
    
    def mark_change_processed(self, change_id: int, success: bool, error: str = None):
        """Mark a queued change as processed"""
        status = 'completed' if success else 'failed'
        self.conn.execute("""
            UPDATE change_queue
            SET status = ?, processed_at = ?
            WHERE id = ?
        """, (status, datetime.now().isoformat(), change_id))
        self.conn.commit()
    
    def log_conflict(self, conflict: Conflict, resolution: Dict):
        """Log conflict to history"""
        self.conn.execute("""
            INSERT INTO conflict_history
            (task_uuid, conflict_fields, local_values, remote_values,
             resolution_strategy, resolved_values)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            conflict.task_uuid,
            json.dumps([conflict.field]),
            json.dumps({conflict.field: conflict.local_value}),
            json.dumps({conflict.field: conflict.remote_value}),
            resolution.get('strategy', 'unknown'),
            json.dumps(resolution.get('values', {}))
        ))
        self.conn.commit()


# ============================================================================
# SYNC ENGINE
# ============================================================================

class SyncEngine:
    """Main sync engine coordinating all operations"""
    
    def __init__(self, db_path: str = "~/.task/sync_state.db"):
        self.db = StateDatabase(db_path)
        self.mapper = FieldMapper()
        self.detector = ChangeDetector()
        self.resolver = ConflictResolver()
    
    def sync_task(self, task: TaskState, issue: IssueState,
                  strategy: ConflictStrategy = ConflictStrategy.LAST_WRITE_WINS) -> Dict:
        """
        Sync a single task with its external issue.
        Returns sync result with actions taken.
        """
        result = {
            'task_uuid': task.uuid,
            'action': None,
            'conflicts': [],
            'changes_applied': {},
            'success': False
        }
        
        # Get sync state
        sync_state = self.db.get_sync_state(task.uuid)
        
        if not sync_state:
            # First sync - create state
            sync_state = SyncState(
                task_uuid=task.uuid,
                service_type=issue.service_type,
                service_id=issue.service_id,
                last_sync_time=datetime.now(),
                last_local_state=task,
                last_remote_state=issue,
                local_checksum=task.checksum(),
                remote_checksum=issue.checksum()
            )
            self.db.save_sync_state(sync_state)
            result['action'] = 'initialized'
            result['success'] = True
            return result
        
        # Check for changes
        local_changed = task.checksum() != sync_state.local_checksum
        remote_changed = issue.checksum() != sync_state.remote_checksum
        
        if not local_changed and not remote_changed:
            result['action'] = 'no_changes'
            result['success'] = True
            return result
        
        # Detect conflicts
        conflicts = self.resolver.detect_conflicts(task, issue, sync_state)
        
        if conflicts:
            result['conflicts'] = conflicts
            
            # Resolve based on strategy
            if strategy == ConflictStrategy.LAST_WRITE_WINS:
                direction, winner = self.resolver.last_write_wins(task, issue, sync_state)
                result['action'] = f'conflict_resolved_{direction}'
                result['changes_applied'] = asdict(winner)
                
            elif strategy == ConflictStrategy.FIELD_LEVEL_MERGE:
                merged = self.resolver.field_level_merge(task, issue, sync_state)
                result['action'] = 'conflict_merged'
                result['changes_applied'] = merged
                
            elif strategy == ConflictStrategy.MANUAL:
                result['action'] = 'conflict_requires_manual_resolution'
                result['success'] = False
                return result
            
            # Log conflicts
            for conflict in conflicts:
                self.db.log_conflict(conflict, {
                    'strategy': strategy.value,
                    'values': result['changes_applied']
                })
            
            sync_state.conflict_count += 1
        
        elif local_changed and not remote_changed:
            # Only local changed - push
            result['action'] = 'push'
            result['changes_applied'] = self.mapper.task_to_github(task)
            
        elif remote_changed and not local_changed:
            # Only remote changed - pull
            result['action'] = 'pull'
            result['changes_applied'] = self.mapper.github_to_task(issue)
        
        # Update sync state
        sync_state.last_sync_time = datetime.now()
        sync_state.last_local_state = task
        sync_state.last_remote_state = issue
        sync_state.local_checksum = task.checksum()
        sync_state.remote_checksum = issue.checksum()
        self.db.save_sync_state(sync_state)
        
        result['success'] = True
        return result
    
    def process_queue(self, batch_size: int = 10):
        """Process pending changes from queue"""
        changes = self.db.get_pending_changes(batch_size)
        
        results = []
        for change in changes:
            try:
                # Process change based on direction
                if change['direction'] == SyncDirection.PUSH:
                    # Push to external service
                    success = self._push_to_service(
                        change['task_uuid'],
                        change['changes']
                    )
                elif change['direction'] == SyncDirection.PULL:
                    # Pull from external service
                    success = self._pull_from_service(
                        change['task_uuid'],
                        change['changes']
                    )
                
                self.db.mark_change_processed(change['id'], success)
                results.append({'id': change['id'], 'success': success})
                
            except Exception as e:
                self.db.mark_change_processed(change['id'], False, str(e))
                results.append({'id': change['id'], 'success': False, 'error': str(e)})
        
        return results
    
    def _push_to_service(self, task_uuid: str, changes: Dict) -> bool:
        """Push changes to external service (stub)"""
        # This would call the actual service API
        # e.g., GitHub API, Jira API, etc.
        print(f"PUSH: Task {task_uuid} changes: {changes}")
        return True
    
    def _pull_from_service(self, task_uuid: str, changes: Dict) -> bool:
        """Pull changes from external service (stub)"""
        # This would update TaskWarrior
        # e.g., task modify command
        print(f"PULL: Task {task_uuid} changes: {changes}")
        return True


# ============================================================================
# EXAMPLE USAGE
# ============================================================================

def example_sync_workflow():
    """Example of how the sync engine would be used"""
    
    # Initialize sync engine
    engine = SyncEngine()
    
    # Example: Task modified locally
    local_task = TaskState(
        uuid="abc-123",
        description="Fix bug in login",
        status="started",
        priority="H",
        tags=["bug", "urgent"],
        annotations=["Working on this now"],
        modified=datetime.now()
    )
    
    # Example: Issue state from GitHub
    github_issue = IssueState(
        service_type="github",
        service_id="42",
        title="Fix bug in login",
        state="open",
        priority="high",
        labels=["bug", "urgent"],
        comments=["Assigned to developer"],
        updated=datetime.now()
    )
    
    # Sync with last-write-wins strategy
    result = engine.sync_task(
        local_task,
        github_issue,
        strategy=ConflictStrategy.LAST_WRITE_WINS
    )
    
    print(f"Sync result: {result}")
    
    # Example: Conflict scenario
    # Both sides modified
    local_task.description = "Fix critical bug in login"
    local_task.modified = datetime.now()
    
    github_issue.title = "Fix security bug in login"
    github_issue.updated = datetime.now()
    
    result = engine.sync_task(
        local_task,
        github_issue,
        strategy=ConflictStrategy.FIELD_LEVEL_MERGE
    )
    
    print(f"Conflict resolution result: {result}")


if __name__ == "__main__":
    print("Two-Way Sync Service - Example Implementation")
    print("=" * 60)
    print("\nThis is exploratory code demonstrating key concepts.")
    print("NOT intended for production use.\n")
    
    example_sync_workflow()
