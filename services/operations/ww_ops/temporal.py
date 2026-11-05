"""Exact microsecond interval arithmetic and explicitly bounded event bins."""
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from .contracts import OpError, timestamp

EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
MICROSECOND = 1_000_000


def ticks(value):
    delta = datetime.fromisoformat(timestamp(value)) - EPOCH
    return (delta.days * 86400 + delta.seconds) * MICROSECOND + delta.microseconds


def iso(value):
    return (EPOCH + timedelta(microseconds=value)).isoformat(timespec='microseconds')


def union_length(intervals):
    result = 0
    last = None
    for first, end in sorted(intervals):
        if end <= first:
            continue
        if last is None or first > last:
            result += end - first
        elif end > last:
            result += end - last
        last = max(last, end) if last is not None else end
    return result


def participation(rows):
    """Count attempts, per-actor unions and all-actor union separately."""
    by_actor = defaultdict(list)
    changes = defaultdict(int)
    for row in rows:
        interval = (ticks(row['clipped_start']), ticks(row['clipped_end']))
        by_actor[row['actor']].append(interval)
        changes[interval[0]] += 1
        changes[interval[1]] -= 1
    actors = [{'actor': actor, 'microseconds': union_length(values),
               'seconds': union_length(values) / MICROSECOND} for actor, values in sorted(by_actor.items())]
    active = peak = 0
    for _, change in sorted(changes.items()):
        active += change
        peak = max(peak, active)
    total = sum(ticks(r['clipped_end']) - ticks(r['clipped_start']) for r in rows)
    wall = union_length([i for values in by_actor.values() for i in values])
    return {'total_microseconds': total, 'total_seconds': total / MICROSECOND,
            'unit': 'attempt-seconds', 'actors': actors,
            'actor_seconds': sum(a['microseconds'] for a in actors) / MICROSECOND,
            'wall_covered_seconds': wall / MICROSECOND, 'peak_concurrent_attempts': peak}


def buckets(events, width_seconds=3600, *, start=None, end=None, dense=False):
    width = width_seconds * MICROSECOND
    grouped = defaultdict(list)
    for event in events:
        grouped[ticks(event['occurred_at']) // width * width].append(event)
    if dense:
        if start is None or end is None or start >= end or start % width or end % width:
            raise OpError('invalid_input', 'Difference methods require a finite increasing window aligned to UTC hours.')
        if (end - start) // width > 10000:
            raise OpError('invalid_input', 'Difference window exceeds 10000 buckets.')
        keys = range(start, end, width)
    else:
        keys = sorted(grouped)
    return [{'start': iso(t), 'events': grouped[t], 'count': len(grouped[t])} for t in keys]
