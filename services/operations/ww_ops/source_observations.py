"""Explicit source methods, separate from the native assignment/attempt semantics."""
from .contracts import OpError
from .temporal import ticks,iso,MICROSECOND,participation

CONTRACT='ww-source-observation/v1'

def project_source(name,history,selected,lo,hi,clock,actor,object_id):
    def valid(e):
        return e['category']=='observation' and e['data'].get('contract')==CONTRACT and e['data'].get('mode') in ('live','reconstructed')
    if name in ('frick','baldwin'):
        rows=[]
        for e in selected:
            if not valid(e):continue
            d=e['data'];kind=d.get('kind')
            if name=='frick' and kind=='state-change' and d.get('before')!=d.get('after'):
                rows.append({'event':e['id'],'at':e['occurred_at'],'object':e['object'],'from_state':d.get('before'),'to_state':d.get('after'),'actor':e['actor'],'mode':d['mode'],'producer':e['producer']})
            if name=='baldwin' and kind=='snapshot-change':
                from .lenses import differences
                if not isinstance(d.get('before'),dict) or not isinstance(d.get('after'),dict):raise OpError('invalid_source_observation','Snapshot deltas need explicit before/after objects.')
                rows.append({'event':e['id'],'object':e['object'],'changes':differences(d['before'],d['after']),'mode':d['mode'],'producer':e['producer']})
        return {'rows':rows,'basis':'attributed source changes; no native state authority'}
    starts={};ends={}
    for e in history:
        if not valid(e):continue
        d=e['data'];kind=d.get('kind')
        if kind not in ('activity-started','activity-finished'):continue
        if not isinstance(d.get('activity'),str) or not d['activity']:raise OpError('invalid_source_observation','Source activity identity is required.')
        key=(e['producer'],d['activity'])
        if kind=='activity-started':
            if key in starts:raise OpError('invalid_event_history','Repeated source activity start.')
            starts[key]={'activity':d['activity'],'producer':e['producer'],'object':e['object'],'actor':e['actor'],'started_at':e['occurred_at'],'heartbeat_at':e['occurred_at'],'mode':d['mode']}
        else:
            if key not in starts or key in ends or ticks(e['occurred_at'])<ticks(starts[key]['started_at']) or e['actor']!=starts[key]['actor'] or e['object']!=starts[key]['object']:
                raise OpError('invalid_event_history','Unmatched or conflicting source activity finish.')
            ends[key]=e['occurred_at']
    rows=[]
    for key,row in starts.items():
        if actor is not None and row['actor']!=actor:continue
        if object_id is not None and object_id!=row['object']:continue
        end=ends.get(key);row={**row,'ended_at':end,'open':end is None}
        first=max(lo,ticks(row['started_at'])) if lo is not None else ticks(row['started_at']);last=min(ticks(end) if end else clock,hi if hi is not None else clock)
        if last<=first:continue
        if name=='board':
            if row['open']:rows.append({**row,'duration_seconds':(clock-ticks(row['started_at']))/MICROSECOND})
        else:rows.append({**row,'clipped_start':iso(first),'clipped_end':iso(last),'window_microseconds':last-first,'window_seconds':(last-first)/MICROSECOND})
    if name=='board':return {'rows':rows,'basis':'source-declared open activities; liveness unknown','snapshot_at':iso(clock)}
    data=participation(rows);data['peak_concurrent_activities']=data.pop('peak_concurrent_attempts');data['unit']='source-activity-seconds'
    return {'rows':rows,**data,'basis':'recorded boundary elapsed intervals; waiting and unobserved activity may be included'}
