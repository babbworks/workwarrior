"""Imported observations retain their own semantics and historical knowledge clock."""
import copy,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'services/operations'))
from ww_ops.lenses import project
from ww_ops.contracts import OpError
S={'organization':'fixture','instance':'test','profile':'research'}
def e(n,t,kind,**data):
 return {'id':str(n),'sequence':n,'scope':S,'producer':'make-harness/v1','source_event':str(n),'type':'make.'+kind,'object':'DP-1/task','actor':'agent:test','occurred_at':t,'recorded_at':'2026-11-05T12:00:00Z','category':'observation','data':{'contract':'ww-source-observation/v1','kind':kind,'mode':'reconstructed',**data}}
class SourceTelemetryTests(unittest.TestCase):
 def test_recorded_before_does_not_backdate_knowledge(self):
  x=[e(1,'2026-11-01T00:00:00Z','state-change',before='pending',after='done')]
  self.assertEqual(0,project('felt',x,S,recorded_before='2026-11-05T11:00:00Z')['meta']['selected_events'])
  self.assertEqual(1,project('felt',x,S,recorded_before='2026-11-05T12:00:01Z')['meta']['selected_events'])
 def test_imported_intervals_require_explicit_method_and_keep_elapsed_basis(self):
  x=[e(1,'2026-11-01T00:00:00Z','activity-started',activity='a'),e(2,'2026-11-01T00:00:10Z','activity-finished',activity='a')]
  self.assertEqual([],project('bundy',x,S,as_of='2026-11-01T00:01:00Z')['data']['rows'])
  r=project('bundy',x,S,method='source-activity-intervals/v1',as_of='2026-11-01T00:01:00Z');self.assertEqual(10,r['data']['total_seconds']);self.assertEqual('source-activity-seconds',r['data']['unit'])
 def test_external_state_and_snapshot_are_separate_from_native(self):
  x=[e(1,'2026-11-01T00:00:00Z','state-change',before='reserved',after='succeeded'),e(2,'2026-11-01T00:00:10Z','snapshot-change',before={'a':None},after={'a':1})]
  self.assertEqual([],project('frick',x,S)['data']['rows']);self.assertEqual(1,len(project('frick',x,S,method='source-state-transitions/v1')['data']['rows']))
  self.assertEqual(1,len(project('baldwin',x,S,method='source-snapshot-deltas/v1')['data']['rows']))
 def test_simulation_is_inspectable_but_not_real_activity(self):
  x=[e(1,'2026-11-01T00:00:00Z','state-change',before='a',after='b',mode='simulation')]
  self.assertEqual(0,project('felt',x,S)['meta']['eligible_events']);self.assertEqual(1,len(project('burroughs',x,S)['data']['rows']))
 def test_unmatched_or_changed_actor_finish_fails(self):
  x=[e(1,'2026-11-01T00:00:00Z','activity-finished',activity='a')]
  with self.assertRaises(OpError):project('bundy',x,S,method='source-activity-intervals/v1',as_of='2026-11-01T00:01:00Z')
 def test_source_interval_clips_and_derived_is_excluded(self):
  x=[e(1,'2026-11-01T00:00:00Z','activity-started',activity='a'),e(2,'2026-11-01T00:01:00Z','activity-finished',activity='a')]
  r=project('bundy',x,S,method='source-activity-intervals/v1',start='2026-11-01T00:00:10Z',end='2026-11-01T00:00:30Z',as_of='2026-11-01T00:02:00Z');self.assertEqual(20,r['data']['total_seconds'])
if __name__=='__main__':unittest.main()
