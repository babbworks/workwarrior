"""Cross-check local journal indexes, history, events and retained receipts."""
import json

from .contracts import digest


def inspect(db):
    errors = []
    versions = {}
    objects = {}
    events = {}
    changed_versions = set()

    def document(raw, label):
        try:
            value = json.loads(raw)
            if not isinstance(value, dict):
                raise ValueError()
            return value
        except (ValueError, TypeError):
            errors.append(label + ':invalid-json')
            return None

    def checked_record(record):
        return (record.get('sha256') == digest({k: v for k, v in record.items() if k != 'sha256'})
                and isinstance(record.get('scope'), dict))

    for row in db.execute('SELECT * FROM versions'):
        label = 'version:' + row['id'] + ':' + str(row['revision'])
        r = document(row['document'], label)
        if r is None:
            continue
        key = (row['id'], row['revision'])
        versions[key] = r
        if not checked_record(r) or r.get('id') != key[0] or r.get('revision') != key[1]:
            errors.append(label)

    for row in db.execute('SELECT * FROM objects'):
        label = 'object:' + row['id']
        r = document(row['document'], label)
        if r is None:
            continue
        objects[row['id']] = r
        history = sorted(rev for identity, rev in versions if identity == row['id'])
        if (not checked_record(r) or r.get('id') != row['id'] or r.get('kind') != row['kind']
                or r.get('scope', {}).get('profile') != row['profile']
                or versions.get((row['id'], r.get('revision'))) != r
                or history != list(range(1, r.get('revision', 0) + 1))):
            errors.append(label)
    if {identity for identity, _ in versions} != set(objects):
        errors.append('history:orphan-or-missing-object')

    previous = None
    for sequence, row in enumerate(db.execute('SELECT * FROM events ORDER BY sequence'), 1):
        label = 'event:' + str(row['sequence'])
        e = document(row['document'], label)
        if e is None:
            previous = row['sha256']
            continue
        if (digest(e) != row['sha256'] or e.get('previous_sha256') != previous
                or e.get('sequence') != row['sequence'] or row['sequence'] != sequence
                or e.get('scope', {}).get('profile') != row['profile']):
            errors.append(label)
        previous = row['sha256']
        events[e.get('id')] = {**e, 'sha256': row['sha256']}
        if e.get('producer') == 'ww-operations':
            changes = e.get('data', {}).get('changes', [])
            if not isinstance(changes, list) or not changes:
                errors.append(label + ':missing-changes')
                continue
            for change in changes:
                after = change.get('after', {})
                key = (after.get('id'), after.get('revision'))
                if key in changed_versions or versions.get(key) != after:
                    errors.append(label + ':history-mismatch')
                changed_versions.add(key)
                before = change.get('before')
                if before is not None and versions.get((before.get('id'), before.get('revision'))) != before:
                    errors.append(label + ':prior-history-mismatch')
    if set(versions) != changed_versions:
        errors.append('history:event-coverage')

    source_ids = set()
    for row in db.execute('SELECT * FROM source_events'):
        e = events.get(row['event_id'])
        source_ids.add(row['event_id'])
        if not e:
            errors.append('source:missing-event')
            continue
        original = {k: e.get(k) for k in ('producer', 'source_event', 'type', 'object', 'actor', 'occurred_at', 'category', 'data')}
        if (e.get('scope', {}).get('profile') != row['profile'] or e.get('producer') != row['producer']
                or e.get('source_event') != row['source_event'] or digest(original) != row['fingerprint']):
            errors.append('source:' + row['event_id'])
    if source_ids != {identity for identity, e in events.items() if e.get('producer') != 'ww-operations'}:
        errors.append('source:event-coverage')

    receipt_events = set()
    for row in db.execute('SELECT * FROM requests'):
        label = 'request:' + row['profile'] + ':' + row['key']
        p = document(row['plan'], label)
        r = document(row['receipt'], label)
        if p is None or r is None:
            continue
        request = p.get('request', {})
        if (digest({k: v for k, v in p.items() if k != 'plan_sha256'}) != p.get('plan_sha256')
                or digest({'operation': p.get('operation'), 'request': request}) != row['fingerprint']
                or r.get('plan_sha256') != p.get('plan_sha256') or r.get('scope') != p.get('scope')
                or p.get('scope', {}).get('profile') != row['profile']
                or request.get('key') != row['key'] or r.get('key') != row['key']):
            errors.append(label)
        for record in r.get('records', []):
            if versions.get((record.get('id'), record.get('revision'))) != record:
                errors.append(label + ':record')
        event = r.get('event')
        if event:
            receipt_events.add(event.get('id'))
            if events.get(event.get('id')) != event:
                errors.append(label + ':event')
        if r.get('primary') not in objects and r.get('primary') not in events:
            errors.append(label + ':primary')
    if set(events) != receipt_events:
        errors.append('request:event-coverage')
    return errors
