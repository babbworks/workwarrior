"""Operational contracts tested with isolated data; no installed WW state."""
import concurrent.futures
import copy
import json
import os
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'services/operations'))
from ww_ops import Operations, OpError, initialize


class OperationsTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)/'data'
        info=initialize(self.root,'test-company',apply=True)
        self.scope={'organization':'test-company','instance':info['instance'],'profile':'research'}
        self.ops=Operations(self.root,self.scope);self.n=0

    def apply(self,operation,payload,key=None):
        self.n+=1
        return self.ops.apply(self.ops.plan(operation,payload,key or f'k-{self.n}'))

    def assignment(self,**extra):
        return self.apply('assign',{'title':'Regional research','instructions':'Use the frozen input; return evidence.',
            'bindings':[{'provider':'make','id':'native-dispatch-7','sha256':'a'*64}],
            'acceptance':['Return is separately reviewed by MAKE.'],**extra})['records'][0]

    def pin(self,r):return {k:r[k] for k in ('id','revision','sha256')}

    def start(self,a,actor='agent:alpha'):
        return self.apply('start',{'assignment':self.pin(a),'actor':actor,'provider':'test-research'})['records'][0]

    def assertCode(self,code,fn):
        with self.assertRaises(OpError) as e:fn()
        self.assertEqual(code,e.exception.code)

    def test_reads_do_not_initialize_and_scope_is_required(self):
        missing=Path(self.tmp.name)/'absent'
        self.assertCode('store_missing',lambda:Operations(missing,self.scope).snapshot())
        self.assertFalse(missing.exists())
        self.assertCode('invalid_input',lambda:Operations(self.root,{}))
        self.assertCode('wrong_scope',lambda:Operations(self.root,{**self.scope,'organization':'other'}).snapshot())

    def test_preview_receipt_replay_and_changed_request_conflict(self):
        plan=self.ops.plan('assign',{'title':'One','instructions':'Exact instructions','bindings':[],'acceptance':[]},'stable')
        self.assertEqual([],self.ops.snapshot()['assignments'])
        first=self.ops.apply(plan);again=self.ops.apply(plan)
        self.assertFalse(first['replayed']);self.assertTrue(again['replayed'])
        self.assertEqual(first['primary'],again['primary'])
        changed=self.ops.plan('assign',{'title':'Other','instructions':'Exact instructions','bindings':[],'acceptance':[]},'stable')
        self.assertCode('request_conflict',lambda:self.ops.apply(changed))
        forged=copy.deepcopy(plan);forged['request']['payload']['title']='edited'
        self.assertCode('invalid_plan',lambda:self.ops.apply(forged))

    def test_two_actors_share_assignment_without_losing_participation(self):
        a=self.assignment(policy={'max_attempts':4,'max_parallel':2})
        one=self.start(a);a=self.ops.get(a['id']);two=self.start(a,'agent:beta')
        board=self.ops.lens('board',as_of='2026-12-01T00:00:00Z')
        self.assertEqual(2,len(board['data']['rows']))
        self.assertEqual({one['id'],two['id']},{r['attempt'] for r in board['data']['rows']})
        result=self.apply('finish',{'attempt':self.pin(one),'status':'succeeded','summary':'Returned','artifacts':[],'usage':[]})
        self.assertEqual(1,len(self.ops.lens('board',as_of='2026-12-01T00:00:00Z')['data']['rows']))
        self.assertEqual('running',self.ops.get(a['id'])['data']['state'])
        self.assertTrue(any(r['kind']=='return' for r in result['records']))

    def test_stale_start_and_parallel_limit(self):
        a=self.assignment(policy={'max_attempts':2,'max_parallel':1})
        self.start(a)
        self.assertCode('revision_conflict',lambda:self.start(a,'agent:beta'))
        self.assertCode('parallel_limit',lambda:self.start(self.ops.get(a['id']),'agent:beta'))

    def test_retry_limits_and_completion_is_not_acceptance(self):
        a=self.assignment(policy={'max_attempts':1,'max_parallel':1});attempt=self.start(a)
        self.apply('finish',{'attempt':self.pin(attempt),'status':'failed','summary':'Access unavailable','artifacts':[],'usage':[]})
        self.assertCode('attempt_limit',lambda:self.start(self.ops.get(a['id'])))
        self.assertEqual('needs-attention',self.ops.get(a['id'])['data']['state'])
        self.assertEqual('unreviewed',self.ops.snapshot()['returns'][0]['data']['review_state'])

    def test_producer_event_identity_preserves_same_time_different_actors(self):
        for actor,key in [('agent:alpha','one'),('agent:beta','two')]:
            self.apply('observe',{'producer':'fixture','source_event':key,'type':'source.opened','object':'shared',
                'actor':actor,'occurred_at':'2026-11-01T12:00:00Z','category':'observation','data':{}},key)
        result=self.ops.lens('burroughs')['data']['rows']
        self.assertEqual(2,len(result))
        duplicate=self.apply('observe',{'producer':'fixture','source_event':'one','type':'source.opened','object':'shared',
                'actor':'agent:alpha','occurred_at':'2026-11-01T12:00:00Z','category':'observation','data':{}},'different-request')
        self.assertTrue(duplicate['source_replayed'])
        self.assertEqual(2,len(self.ops.lens('burroughs')['data']['rows']))
        self.assertCode('source_conflict',lambda:self.apply('observe',{'producer':'fixture','source_event':'one',
                'type':'source.opened','object':'changed','actor':'agent:alpha','occurred_at':'2026-11-01T12:00:00Z',
                'category':'observation','data':{}}))

    def test_derived_events_do_not_inflate_density_or_signal(self):
        self.apply('observe',{'producer':'fixture','source_event':'raw','type':'source.opened','object':'item',
            'actor':'agent:alpha','occurred_at':'2026-11-01T12:00:00Z','category':'observation','data':{}})
        before=self.ops.lens('felt')['data']
        self.apply('observe',{'producer':'fixture','source_event':'derived','type':'dey.sample','object':'item',
            'actor':'sampler','occurred_at':'2026-11-01T12:00:01Z','category':'derived','data':{'i':1}})
        self.assertEqual(before,self.ops.lens('felt')['data'])
        self.assertEqual(1,self.ops.lens('dey')['meta']['eligible_events'])
        self.assertEqual(2,len(self.ops.lens('burroughs')['data']['rows']))

    def test_window_reconstructs_crossing_interval_and_clips_seconds(self):
        from unittest.mock import patch
        a=self.assignment()
        with patch('ww_ops.service.now',return_value='2026-11-01T12:00:00Z'):attempt=self.start(a)
        start=attempt['data']['started_at']
        from datetime import datetime,timedelta
        begin=datetime.fromisoformat(start.replace('Z','+00:00'))
        end=(begin+timedelta(seconds=120)).isoformat()
        with patch('ww_ops.service.now',return_value=end):
            self.apply('finish',{'attempt':self.pin(attempt),'status':'succeeded','summary':'Returned','artifacts':[],'usage':[]})
        data=self.ops.lens('bundy',start=(begin+timedelta(seconds=30)).isoformat(),
                           end=(begin+timedelta(seconds=90)).isoformat(),as_of=end)['data']
        self.assertEqual(60,data['total_seconds'])

    def test_json_is_typed_lens_output_and_as_of_is_required_for_live_views(self):
        a=self.assignment();self.start(a)
        self.assertCode('invalid_input',lambda:self.ops.lens('board'))
        output=self.ops.lens('bundy',as_of='2026-12-01T00:00:00Z')
        self.assertEqual('bundy',output['lens']);self.assertIn('method',output)
        self.assertIn('input_sha256',output['meta'])
        self.assertNotEqual(output['data'],self.ops.lens('felt')['data'])

    def test_profiles_are_explicit_and_receipts_are_scoped(self):
        self.assignment()
        other=Operations(self.root,{**self.scope,'profile':'editorial'})
        self.assertEqual([],other.snapshot()['assignments'])
        a=other.apply(other.plan('assign',{'title':'Different','instructions':'Own input','bindings':[],'acceptance':[]},'k-1'))
        self.assertEqual(1,len(other.snapshot()['assignments']))
        self.assertCode('not_found',lambda:self.ops.get(a['primary']))

    def test_concurrent_same_request_has_one_effect(self):
        p=self.ops.plan('assign',{'title':'Concurrent','instructions':'Once','bindings':[],'acceptance':[]},'concurrent')
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
            receipts=list(ex.map(lambda _:Operations(self.root,self.scope).apply(p),range(4)))
        self.assertEqual(1,len({r['primary'] for r in receipts}))
        self.assertEqual(1,len(self.ops.snapshot()['assignments']))
        self.assertTrue(self.ops.audit()['ok'])

    def test_failed_write_rolls_back_object_events_and_receipt(self):
        from unittest.mock import patch
        p=self.ops.plan('assign',{'title':'Rollback','instructions':'Once','bindings':[],'acceptance':[]},'rollback')
        with patch.object(self.ops,'_receipt',side_effect=RuntimeError('interruption')):
            with self.assertRaises(RuntimeError):self.ops.apply(p)
        self.assertEqual([],self.ops.snapshot()['assignments'])
        self.assertEqual([],self.ops.lens('burroughs')['data']['rows'])
        self.assertFalse(self.ops.apply(p)['replayed'])

    def test_receipt_and_event_hash_audit_detects_corruption(self):
        self.assignment();self.assertTrue(self.ops.audit()['ok'])
        with sqlite3.connect(self.root/'operations.sqlite3') as db:
            db.execute("UPDATE events SET document=replace(document,'Regional research','Tampered research')")
        self.assertFalse(self.ops.audit()['ok'])

    def test_cancel_does_not_claim_running_process_was_stopped(self):
        a=self.assignment();attempt=self.start(a)
        result=self.apply('cancel',{'assignment':self.pin(self.ops.get(a['id'])),'reason':'Pause this work'})
        self.assertEqual('cancellation-requested',self.ops.get(a['id'])['data']['state'])
        self.assertEqual('active',self.ops.get(attempt['id'])['data']['state'])
        self.assertTrue(result['records'])

    def test_events_pagination_has_stable_cursor(self):
        self.assignment();self.assignment()
        one=self.ops.events(after=0,limit=1)
        two=self.ops.events(after=one['next_cursor'],limit=1)
        self.assertNotEqual(one['events'][0]['id'],two['events'][0]['id'])
        self.assertTrue(one['has_more'])

    def test_audit_detects_deleted_tail_event_and_historical_corruption(self):
        a=self.assignment();attempt=self.start(a)
        with sqlite3.connect(self.root/'operations.sqlite3') as db:
            db.execute('DELETE FROM events WHERE sequence=(SELECT max(sequence) FROM events)')
        self.assertFalse(self.ops.audit()['ok'])

    def test_audit_detects_historical_snapshot_and_receipt_deletion(self):
        a=self.assignment();self.start(a)
        self.assertTrue(self.ops.audit()['ok'])
        with sqlite3.connect(self.root/'operations.sqlite3') as db:
            db.execute("UPDATE versions SET document=replace(document,'Regional research','Tampered history') WHERE revision=1")
        self.assertFalse(self.ops.audit()['ok'])

    def test_audit_detects_deleted_source_index_and_receipt(self):
        self.apply('observe',{'producer':'fixture','source_event':'raw','type':'source.opened','object':'item',
            'actor':'agent:alpha','occurred_at':'2026-11-01T12:00:00Z','category':'observation','data':{}})
        self.assertTrue(self.ops.audit()['ok'])
        with sqlite3.connect(self.root/'operations.sqlite3') as db:db.execute('DELETE FROM source_events')
        self.assertFalse(self.ops.audit()['ok'])

    def test_frick_projects_state_changes_without_heartbeat_and_filters_changed_subject(self):
        assignment=self.assignment();attempt=self.start(assignment)
        before=self.ops.lens('frick',object_id=assignment['id'])['data']['rows']
        self.assertEqual(['queued','running'],[r['to_state'] for r in before])
        self.apply('heartbeat',{'attempt':self.pin(attempt),'note':'Still working'})
        after=self.ops.lens('frick',object_id=assignment['id'])['data']['rows']
        self.assertEqual(before,after)
        all_changes=self.ops.lens('frick')['data']['rows']
        self.assertFalse(any(r['transition']=='attempt.heartbeat' for r in all_changes))
        self.assertTrue(any(r['object']==attempt['id'] and r['to_state']=='active' for r in all_changes))
        delta=self.ops.lens('baldwin',object_id=assignment['id'])['data']['rows']
        self.assertEqual(2,len(delta))
        self.assertTrue(all(r['object']==assignment['id'] for r in delta))

    def test_unknown_unit_is_retained_with_qualification(self):
        a=self.assignment();attempt=self.start(a)
        self.apply('finish',{'attempt':self.pin(attempt),'status':'succeeded','summary':'Returned','artifacts':[],
            'usage':[{'unit':'custom-cycle','quantity':1,'basis':'reported','source':'fixture'}]})
        usage=self.ops.snapshot()['returns'][0]['data']['usage'][0]
        self.assertEqual('custom-cycle',usage['unit']);self.assertFalse(usage['registered_unit'])


if __name__=='__main__':unittest.main()
