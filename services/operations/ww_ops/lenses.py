"""Pure inventor-named projections; computation and interpretation remain distinct."""
from collections import Counter, defaultdict
import math

from .contracts import OpError, canonical, digest, timestamp
from .temporal import MICROSECOND, buckets, iso, participation, ticks

CATALOG = {
 'burroughs': {'description': 'Chronological event inspection', 'method': 'scoped-events/v1', 'role': 'inspection'},
 'baldwin': {'description': 'Recorded state and revision differencing', 'method': 'object-field-deltas/v2', 'role': 'structural-comparison'},
 'frick': {'description': 'Discrete operational transitions', 'method': 'native-state-transitions/v2', 'role': 'transition-projection'},
 'bundy': {'description': 'Interval reconstruction and accumulation', 'method': 'attempt-actor-wall-unions/v2', 'role': 'duration-measurement'},
 'board': {'description': 'Open participation and recorded heartbeats', 'method': 'open-attempts/v2', 'role': 'state-reconstruction'},
 'felt': {'description': 'Eligible event counts by hour', 'method': 'eligible-hour-count/v1', 'role': 'aggregation',
          'alternate_methods': ['hourly-count-first-difference/v1']},
 'grant': {'description': 'Declared operational aggregates', 'method': 'operational-counts/v1', 'role': 'aggregation',
           'alternate_methods': ['hourly-count-second-difference/v1']},
 'dey': {'description': 'Exploratory event-rate and type-diversity features', 'method': 'rate-type-entropy-features/v2', 'role': 'experimental-features'},
 'cooper': {'description': 'Daily polar rendering of Dey event rate', 'method': 'utc-rate-polar/v2', 'role': 'visualization'},
 'hollerith': {'description': 'Time by object symbolic matrix', 'method': 'all-event-ids-per-cell/v1', 'role': 'indexing'},
 'pacioli': {'description': 'Within-window event prefix counts', 'method': 'event-count-not-signed-balance/v1', 'role': 'aggregation'},
}


def differences(before, after, path=''):
    if isinstance(before, dict) and isinstance(after, dict):
        result = []
        for key in sorted(set(before) | set(after)):
            pointer = path + '/' + key.replace('~', '~0').replace('/', '~1')
            if key not in before or key not in after:
                result.append({'path': pointer, 'operation': 'add' if key in after else 'remove',
                               'before_present': key in before, 'after_present': key in after,
                               'before': before.get(key), 'after': after.get(key)})
            else:
                result.extend(differences(before[key], after[key], pointer))
        return result
    # JSON null/missing, booleans/numbers and array/object kinds are not conflated.
    return [] if canonical(before) == canonical(after) else [
        {'path': path, 'operation': 'replace', 'before_present': True, 'after_present': True,
         'before': before, 'after': after}]


def intervals(events):
    starts = {}
    ended = {}
    for event in events:
        if event['producer'] != 'ww-operations':
            continue
        data = event['data']
        if event['type'] == 'attempt.started':
            identity = data['attempt']
            if identity in starts:
                raise OpError('invalid_event_history', 'Duplicate native attempt start.')
            starts[identity] = {'attempt': identity, 'assignment': data['assignment'], 'actor': event['actor'],
                                'started_at': data['started_at'], 'heartbeat_at': data['started_at']}
        elif event['type'] == 'attempt.heartbeat':
            row = starts.get(event['object'])
            if row is None or event['object'] in ended:
                raise OpError('invalid_event_history', 'Heartbeat has no active native start.')
            row['heartbeat_at'] = event['occurred_at']
        elif event['type'] == 'attempt.finished':
            identity = data['attempt']
            row = starts.get(identity)
            if row is None or identity in ended or ticks(data['ended_at']) < ticks(row['started_at']):
                raise OpError('invalid_event_history', 'Finish is unmatched, repeated or precedes its start.')
            ended[identity] = data['ended_at']
    return [{**row, 'ended_at': ended.get(identity), 'open': identity not in ended}
            for identity, row in starts.items()]


def signal_samples(events):
    rows = []
    for bucket in buckets(events, 300):
        counts = Counter(e['type'] for e in bucket['events'])
        total = bucket['count']
        entropy = -sum((n / total) * math.log2(n / total) for n in counts.values())
        rows.append({'at': bucket['start'], 'count': total, 'bucket_seconds': 300,
                     'events_per_second': total / 300, 'type_richness': len(counts),
                     'type_entropy_bits': entropy,
                     'type_evenness': entropy / math.log2(len(counts)) if len(counts) > 1 else 0})
    return rows


def difference_data(events, order, lo, hi, clock):
    if clock is not None and hi is not None and hi > clock:
        raise OpError('invalid_input', 'Difference windows cannot extend beyond as_of.')
    rows = buckets(events, start=lo, end=hi, dense=True)
    counts = [row['count'] for row in rows]
    for i, row in enumerate(rows):
        row.pop('events')
        row['difference'] = None if i < order else (
            counts[i] - counts[i - 1] if order == 1 else counts[i] - 2 * counts[i - 1] + counts[i - 2])
    return {'buckets': rows, 'order': order, 'step_seconds': 3600,
            'unit': 'events per bucket-step' if order == 1 else 'events per bucket-step squared',
            'basis': 'Differences of logged counts; zero bins mean no eligible recorded events, not proven inactivity.'}


def project(name, events, scope, *, start=None, end=None, as_of=None, actor=None, object_id=None, method=None):
    if name not in CATALOG:
        raise OpError('unsupported_lens', 'Unknown inventor lens.')
    spec = CATALOG[name]
    method = method or spec['method']
    if method not in [spec['method'], *spec.get('alternate_methods', [])]:
        raise OpError('unsupported_method', 'Select a method declared for this inventor lens.')
    if name in ('board', 'bundy') and as_of is None:
        raise OpError('invalid_input', 'Supply an explicit as_of timestamp for interval views.')
    lo = ticks(start) if start else None
    hi = ticks(end) if end else None
    clock = ticks(as_of) if as_of else None
    if lo is not None and hi is not None and lo >= hi:
        raise OpError('invalid_input', 'Time range must increase; bounds are [start,end).')
    if any(e['scope'] != scope for e in events):
        raise OpError('wrong_scope', 'Lens input contains a different operational scope.')
    if len({e['id'] for e in events}) != len(events):
        raise OpError('invalid_event_history', 'Repeated event identities are not independent observations.')
    # Event time orders projections; source cursor and hash make late arrivals visible.
    all_events = sorted((e for e in events if clock is None or ticks(e['occurred_at']) <= clock),
                        key=lambda e: (ticks(e['occurred_at']), e['sequence']))
    def matches_object(event):
        if object_id is None or event['object'] == object_id:
            return True
        return name in ('baldwin', 'frick') and event['producer'] == 'ww-operations' and any(
            change.get('after', {}).get('id') == object_id for change in event['data'].get('changes', []))

    selected = [e for e in all_events if (lo is None or lo <= ticks(e['occurred_at']))
                and (hi is None or ticks(e['occurred_at']) < hi)
                and (actor is None or e['actor'] == actor) and matches_object(e)]
    eligible = [e for e in selected if e['category'] == 'observation']
    warnings = ['Quantities describe recorded inputs; completeness and external truth are not established by this lens.']
    if method in ('hourly-count-first-difference/v1', 'hourly-count-second-difference/v1'):
        data = difference_data(eligible, 1 if name == 'felt' else 2, lo, hi, clock)
        warnings.append('Unscaled finite differences of counts are not a physical derivative or proof of acceleration in useful work.')
    elif name == 'burroughs':
        data = {'rows': selected}
    elif name == 'baldwin':
        data = {'rows': [{'event': e['id'], 'object': change['after']['id'], 'revision': change['after']['revision'],
                         'changes': differences(change['before'] or {}, change['after'])} for e in selected
                        if e['producer'] == 'ww-operations' and e['type'].startswith(('assignment.', 'attempt.'))
                        for change in e['data'].get('changes', []) if object_id is None or change['after']['id'] == object_id]}
    elif name == 'frick':
        rows = []
        for event in selected:
            if event['producer'] != 'ww-operations':
                continue
            for change in event['data'].get('changes', []):
                after = change['after']
                before = change['before']
                if after['kind'] not in ('assignment', 'attempt') or (object_id is not None and after['id'] != object_id):
                    continue
                old_state = before['data']['state'] if before else None
                new_state = after['data']['state']
                if old_state != new_state:
                    rows.append({'event': event['id'], 'at': event['occurred_at'], 'object': after['id'],
                                 'kind': after['kind'], 'from_state': old_state, 'to_state': new_state,
                                 'transition': event['type'], 'actor': event['actor']})
        data = {'rows': rows}
        warnings.append('Recorded state changes; heartbeats without state change are excluded. No transition authority or independent validation.')
    elif name in ('bundy', 'board'):
        rows = intervals(all_events)
        rows = [r for r in rows if (actor is None or r['actor'] == actor)
                and (object_id is None or object_id in (r['assignment'], r['attempt']))]
        if name == 'board':
            rows = [r for r in rows if r['open'] and (hi is None or ticks(r['started_at']) < hi)
                    and (lo is None or clock >= lo)]
            for row in rows:
                row['duration_seconds'] = (clock - ticks(row['started_at'])) / MICROSECOND
                row['heartbeat_age_seconds'] = (clock - ticks(row['heartbeat_at'])) / MICROSECOND
            data = {'rows': rows, 'snapshot_at': timestamp(as_of)}
            warnings.append('Snapshot at as_of; optional window filters interval overlap. Open or old does not prove live or hung.')
        else:
            clipped = []
            for row in rows:
                first = max(lo, ticks(row['started_at'])) if lo is not None else ticks(row['started_at'])
                last = ticks(row['ended_at']) if row['ended_at'] else clock
                if hi is not None:
                    last = min(hi, last)
                if last > first:
                    clipped.append({**row, 'window_microseconds': last - first, 'window_seconds': (last - first) / MICROSECOND,
                                    'clipped_start': iso(first), 'clipped_end': iso(last)})
            data = {'rows': clipped, **participation(clipped)}
            warnings.append('Attempt-seconds, actor-union seconds and elapsed union differ under concurrency; none proves productive effort.')
    elif name == 'felt':
        data = {'buckets': [{'start': b['start'], 'count': b['count']} for b in buckets(eligible)], 'unit': 'eligible-events',
                'bucket_seconds': 3600, 'empty_buckets': 'omitted; not evidence of source completeness'}
    elif name == 'grant':
        counts = Counter(e['type'] for e in eligible)
        data = {'events_by_type': dict(sorted(counts.items())), 'attempts_started': counts['attempt.started'],
                'attempts_finished': counts['attempt.finished'],
                'successful_attempts': sum(e['type'] == 'attempt.finished' and e['data'].get('status') == 'succeeded' for e in eligible)}
        warnings.append('Aggregate counts overlap Felt. Finished/started in one window is not a valid cohort success rate. MAKE acceptance is separate.')
    elif name in ('dey', 'cooper'):
        samples = signal_samples(eligible)
        data = {'samples': samples, 'basis': 'Descriptive logged event-rate and event-type distribution; sparse fixed UTC five-minute bins.'}
        warnings.append('Experimental operational features; no inferred stability, fragmentation, fatigue or productivity. Partial bins use the fixed 300-second denominator.')
        if name == 'cooper':
            points = []
            for sample in samples:
                angle = (ticks(sample['at']) % (86400 * MICROSECOND)) / (86400 * MICROSECOND) * 2 * math.pi
                radius = sample['events_per_second']
                points.append({**sample, 'angle': angle, 'radius': radius,
                               'x': radius * math.cos(angle), 'y': radius * math.sin(angle)})
            data = {'points': points, 'timezone': 'UTC', 'angle_unit': 'radians', 'radius_unit': 'events per second',
                    'normalization': 'none; absolute rate retained', 'source_method': CATALOG['dey']['method'], 'basis': data['basis']}
            warnings.append('A rendering of Dey, not independent evidence. Daily angles repeat; full dates are retained to distinguish days.')
    elif name == 'hollerith':
        cells = defaultdict(list)
        for event in selected:
            key = (ticks(event['occurred_at']) // (3600 * MICROSECOND) * (3600 * MICROSECOND), event['object'])
            cells[key].append({'event': event['id'], 'type': event['type'], 'actor': event['actor']})
        data = {'cells': [{'hour': iso(t), 'object': obj, 'events': values} for (t, obj), values in sorted(cells.items())]}
    elif name == 'pacioli':
        counts = Counter()
        rows = []
        for event in selected:
            counts[event['object']] += 1
            rows.append({'event': event['id'], 'object': event['object'], 'running_count': counts[event['object']]})
        data = {'rows': rows, 'unit': 'events', 'initial_count': 0,
                'interpretation': 'Selected-window event prefix count, not lifetime balance or signed/double-entry accounting.'}
    meta = {'input_sha256': digest(all_events), 'input_cursor': max((e['sequence'] for e in all_events), default=0),
            'source_events': len(all_events), 'selected_events': len(selected), 'eligible_events': len(eligible),
            'excluded_from_activity': len(selected) - len(eligible), 'scope': scope,
            'window': {'start': timestamp(start) if start else None, 'end': timestamp(end) if end else None, 'bounds': '[start,end)'},
            'as_of': timestamp(as_of) if as_of else None, 'clock_semantics': 'event-time cutoff with currently recorded knowledge; late arrivals may revise results',
            'actor': actor, 'object': object_id, 'role': spec['role'], 'qualification': 'local computational contract; external construct validity unestablished',
            'warnings': warnings}
    return {'protocol': 'ww-lens-result/v1', 'lens': name, 'description': spec['description'], 'method': method, 'data': data, 'meta': meta}
