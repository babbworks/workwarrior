"""Scoped assignments, concurrent attempts, externally reported returns and receipts."""
import json
import os
import uuid

from . import contracts as c
from .contracts import OpError, canonical, digest, now
from .store import Store


class Operations:
    def __init__(self,path,scope):self.store=Store(path);self.scope=c.scope(scope)

    def _scope(self,db,write=False):
        info=self.store.info(db)
        if any(info[k]!=self.scope[k] for k in ('organization','instance')):
            raise OpError('wrong_scope','Request organization or instance does not match the store.')
        if write and info['principal_uid']!=os.getuid():raise OpError('authority_required','Only the initialized local OS principal can write.')
        return info

    def info(self):
        with self.store.connection() as db:
            return {**self._scope(db),'scope':self.scope,'authority':'local OS principal; actor names are attribution only'}

    @staticmethod
    def capabilities():
        from .lenses import CATALOG
        return {'protocol':'ww-operations-capabilities/v1','operations':['assign','start','heartbeat','finish','cancel','observe'],
            'reads':['snapshot','get','events','receipt','lens','audit'],'lenses':CATALOG,
            'execution':'Records assignments and execution evidence; never executes commands or infers native acceptance.',
            'transactions':'Local SQLite; external effects and source-service decisions are separate.',
            'scope_fields':['organization','instance','profile']}

    def _get(self,db,identity):
        row=db.execute('SELECT document FROM objects WHERE id=? AND profile=?',(identity,self.scope['profile'])).fetchone()
        if not row:raise OpError('not_found','No object with that identity in this scope.')
        return json.loads(row['document'])

    def get(self,identity):
        with self.store.connection() as db:self._scope(db);return self._get(db,identity)

    def _all(self,db,kind=None):
        sql='SELECT document FROM objects WHERE profile=?';args=[self.scope['profile']]
        if kind:sql+=' AND kind=?';args.append(kind)
        return [json.loads(r['document']) for r in db.execute(sql+' ORDER BY rowid',args)]

    def _pin(self,db,pin,kind):
        p=c.pin(pin);r=self._get(db,p['id'])
        if r['kind']!=kind:raise OpError('invalid_input','Wrong object kind for this operation.')
        if r['revision']!=p['revision'] or r['sha256']!=p['sha256']:
            raise OpError('revision_conflict','The referenced object changed; prepare from its current revision.')
        return r

    def _normalize(self,db,op,payload):
        dependencies=[]
        def pinned(value,kind):
            r=self._pin(db,value,kind);dependencies.append(c.pin({k:r[k] for k in ('id','revision','sha256')}));return r
        if op=='assign':
            c.fields(payload,('title','instructions','bindings','acceptance','inputs','policy'),('title','instructions','bindings','acceptance'))
            policy=payload.get('policy',{'max_attempts':3,'max_parallel':1})
            c.fields(policy,('max_attempts','max_parallel'),('max_attempts','max_parallel'))
            if any(type(n) is not int or not 1<=n<=100 for n in policy.values()) or policy['max_parallel']>policy['max_attempts']:
                raise OpError('invalid_input','Set explicit bounded attempt and concurrency allowances.')
            result={'title':c.text(payload['title']),'instructions':c.text(payload['instructions']),
                'bindings':c.bindings(payload['bindings']),'acceptance':c.texts(payload['acceptance']),
                'inputs':c.artifacts(payload.get('inputs',[])),'policy':policy}
        elif op=='start':
            c.fields(payload,('assignment','actor','provider'),('assignment','actor','provider'))
            a=pinned(payload['assignment'],'assignment')
            if a['data']['state'] in ('cancelled','cancellation-requested'):raise OpError('assignment_closed','Assignment is cancelled or cancellation was requested.')
            attempts=[r for r in self._all(db,'attempt') if r['data']['assignment']==a['id']]
            if len(attempts)>=a['data']['policy']['max_attempts']:raise OpError('attempt_limit','Assignment attempt allowance is exhausted.')
            if sum(r['data']['state']=='active' for r in attempts)>=a['data']['policy']['max_parallel']:
                raise OpError('parallel_limit','Assignment concurrency allowance is exhausted.')
            result={'assignment':payload['assignment'],'actor':c.text(payload['actor']),'provider':c.text(payload['provider'])}
        elif op in ('heartbeat','finish'):
            allowed=('attempt','status','summary','artifacts','usage') if op=='finish' else ('attempt','note')
            c.fields(payload,allowed,allowed)
            a=pinned(payload['attempt'],'attempt')
            if a['data']['state']!='active':raise OpError('attempt_closed','The attempt is already closed.')
            if op=='heartbeat':result={'attempt':payload['attempt'],'note':c.text(payload['note'])}
            else:
                if payload['status'] not in ('succeeded','failed','interrupted'):raise OpError('invalid_input','Unknown execution outcome.')
                result={'attempt':payload['attempt'],'status':payload['status'],'summary':c.text(payload['summary']),
                    'artifacts':c.artifacts(payload['artifacts']),'usage':c.usage(payload['usage'])}
        elif op=='cancel':
            c.fields(payload,('assignment','reason'),('assignment','reason'));pinned(payload['assignment'],'assignment')
            result={'assignment':payload['assignment'],'reason':c.text(payload['reason'])}
        elif op=='observe':
            required=('producer','source_event','type','object','actor','occurred_at','category','data')
            c.fields(payload,required,required)
            if payload['category'] not in ('observation','derived','administrative'):raise OpError('invalid_input','Unknown event category.')
            if not isinstance(payload['data'],dict):raise OpError('invalid_input','Event data must be an object.')
            if payload['producer']=='ww-operations':raise OpError('invalid_input','The native producer namespace is reserved.')
            if any(c.text(payload['type']).startswith(n) for n in ('attempt.','assignment.','return.')):
                raise OpError('invalid_input','Native operational events are issued only by their owning operations.')
            result={**payload,**{k:c.text(payload[k],k) for k in ('producer','source_event','type','object','actor')},
                    'occurred_at':c.timestamp(payload['occurred_at'])}
            canonical(result)
        else:raise OpError('unsupported_operation','Unknown operational action.')
        return result,dependencies

    def _plan(self,db,operation,payload,key):
        self._scope(db);c.text(key,'request key')
        payload,dependencies=self._normalize(db,operation,payload)
        plan={'protocol':'ww-operations-plan/v1','scope':self.scope,'operation':operation,
              'request':{'key':key,'payload':payload},'dependencies':dependencies}
        return {**plan,'plan_sha256':digest(plan)}

    def plan(self,operation,payload,key):
        with self.store.connection() as db:return self._plan(db,operation,payload,key)

    def receipt(self,key):
        with self.store.connection() as db:
            self._scope(db)
            r=db.execute('SELECT receipt FROM requests WHERE profile=? AND key=?',(self.scope['profile'],key)).fetchone()
            if not r:raise OpError('not_found','No receipt for that request in this scope.')
            return json.loads(r['receipt'])

    def _receipt(self,db,plan,result):
        db.execute('INSERT INTO requests VALUES (?,?,?,?,?)',(self.scope['profile'],plan['request']['key'],
            digest({'operation':plan['operation'],'request':plan['request']}),canonical(plan).decode(),canonical(result).decode()))

    def apply(self,plan):
        required=('protocol','scope','operation','request','dependencies','plan_sha256')
        c.fields(plan,required,required)
        if plan['protocol']!='ww-operations-plan/v1' or plan['plan_sha256']!=digest({k:v for k,v in plan.items() if k!='plan_sha256'}):
            raise OpError('invalid_plan','Plan content changed or uses an unsupported protocol.')
        if plan['scope']!=self.scope:raise OpError('wrong_scope','Plan belongs to another explicit scope.')
        c.fields(plan['request'],('key','payload'),('key','payload'));c.text(plan['request']['key'])
        fingerprint=digest({'operation':plan['operation'],'request':plan['request']})
        with self.store.connection(write=True) as db:
            self._scope(db,True)
            old=db.execute('SELECT * FROM requests WHERE profile=? AND key=?',(self.scope['profile'],plan['request']['key'])).fetchone()
            if old:
                if old['fingerprint']!=fingerprint:raise OpError('request_conflict','This request key already names different input.')
                return {**json.loads(old['receipt']),'replayed':True}
            current=self._plan(db,plan['operation'],plan['request']['payload'],plan['request']['key'])
            if current!=plan:raise OpError('stale_plan','Referenced operational state changed.')
            result=self._perform(db,plan)
            result={'protocol':'ww-operations-receipt/v1','scope':self.scope,'key':plan['request']['key'],
                    'plan_sha256':plan['plan_sha256'],'replayed':False,**result}
            self._receipt(db,plan,result)
            return result

    def _record(self,db,kind,data,old=None):
        r={'id':old['id'] if old else 'urn:ww:'+self.scope['instance']+':'+str(uuid.uuid4()),'kind':kind,
           'revision':old['revision']+1 if old else 1,'scope':self.scope,'data':data}
        r['sha256']=digest(r)
        db.execute('INSERT OR REPLACE INTO objects VALUES (?,?,?,?)',(r['id'],self.scope['profile'],kind,canonical(r).decode()))
        db.execute('INSERT INTO versions VALUES (?,?,?)',(r['id'],r['revision'],canonical(r).decode()))
        return r

    def _event(self,db,kind,obj,actor,data,*,occurred_at=None,category='observation',producer='ww-operations',source_event=None):
        last=db.execute('SELECT sequence,sha256 FROM events ORDER BY sequence DESC LIMIT 1').fetchone()
        seq=last['sequence']+1 if last else 1
        e={'id':'urn:ww-event:'+str(uuid.uuid4()),'sequence':seq,'scope':self.scope,'type':kind,'object':obj,
           'actor':actor,'occurred_at':c.timestamp(occurred_at or now()),'recorded_at':now(),'category':category,
           'producer':producer,'source_event':source_event,'data':data,'previous_sha256':last['sha256'] if last else None}
        h=digest(e);db.execute('INSERT INTO events VALUES (?,?,?,?)',(seq,self.scope['profile'],canonical(e).decode(),h))
        return {**e,'sha256':h}

    def _perform(self,db,plan):
        op=plan['operation'];p=plan['request']['payload'];records=[];before=[];actor='local-principal:'+str(os.getuid())
        event_data={};event_type=op;occurred_at=None
        if op=='observe':
            fingerprint=digest(p)
            old=db.execute('SELECT * FROM source_events WHERE profile=? AND producer=? AND source_event=?',
                (self.scope['profile'],p['producer'],p['source_event'])).fetchone()
            if old:
                if old['fingerprint']!=fingerprint:raise OpError('source_conflict','Source event identity already names different content.')
                return {'primary':old['event_id'],'records':[],'source_replayed':True}
            e=self._event(db,p['type'],p['object'],p['actor'],p['data'],occurred_at=p['occurred_at'],category=p['category'],producer=p['producer'],source_event=p['source_event'])
            db.execute('INSERT INTO source_events VALUES (?,?,?,?,?)',(self.scope['profile'],p['producer'],p['source_event'],fingerprint,e['id']))
            return {'primary':e['id'],'records':[],'event':e,'source_replayed':False}
        if op=='assign':
            r=self._record(db,'assignment',{**p,'state':'queued','created_at':now()});records=[r]
            event_type='assignment.created';obj=r['id']
        elif op=='start':
            a=self._get(db,p['assignment']['id']);before=[a];actor=p['actor'];ts=now()
            r=self._record(db,'attempt',{'assignment':a['id'],'actor':actor,'provider':p['provider'],'state':'active',
                'started_at':ts,'heartbeat_at':ts,'authority':'local OS principal; actor is attribution'})
            updated=self._record(db,'assignment',{**a['data'],'state':'running'},a)
            records=[r,updated];obj=r['id'];event_type='attempt.started';occurred_at=ts
            event_data={'assignment':a['id'],'attempt':r['id'],'started_at':ts}
        elif op=='heartbeat':
            a=self._get(db,p['attempt']['id']);before=[a];actor=a['data']['actor']
            r=self._record(db,'attempt',{**a['data'],'heartbeat_at':now()},a);records=[r]
            obj=r['id'];event_type='attempt.heartbeat';event_data={'note':p['note']}
        elif op=='finish':
            a=self._get(db,p['attempt']['id']);assignment=self._get(db,a['data']['assignment']);before=[a,assignment]
            actor=a['data']['actor'];ts=now()
            r=self._record(db,'attempt',{**a['data'],'state':p['status'],'ended_at':ts},a)
            returned=self._record(db,'return',{'assignment':assignment['id'],'attempt':r['id'],'outcome':p['status'],
                'summary':p['summary'],'artifacts':p['artifacts'],'usage':p['usage'],'returned_at':ts,
                'review_state':'unreviewed','provenance':'externally-reported; artifact metadata is not independent verification'})
            attempts=[x for x in self._all(db,'attempt') if x['data']['assignment']==assignment['id']]
            state='running' if any(x['data']['state']=='active' for x in attempts) else (
                'cancelled' if assignment['data']['state']=='cancellation-requested' else
                'returned' if any(x['data']['state']=='succeeded' for x in attempts) else 'needs-attention')
            updated=self._record(db,'assignment',{**assignment['data'],'state':state},assignment)
            records=[r,returned,updated];obj=r['id'];event_type='attempt.finished';occurred_at=ts
            event_data={'assignment':assignment['id'],'attempt':r['id'],'started_at':a['data']['started_at'],'ended_at':ts,
                        'status':p['status'],'return':returned['id']}
        elif op=='cancel':
            a=self._get(db,p['assignment']['id']);before=[a]
            active=any(r['data']['assignment']==a['id'] and r['data']['state']=='active' for r in self._all(db,'attempt'))
            r=self._record(db,'assignment',{**a['data'],'state':'cancellation-requested' if active else 'cancelled','cancellation_reason':p['reason']},a)
            records=[r];obj=r['id'];event_type='assignment.cancellation-requested'
        event_data['changes']=[{'before':next((x for x in before if x['id']==r['id']),None),'after':r} for r in records]
        e=self._event(db,event_type,obj,actor,event_data,occurred_at=occurred_at)
        return {'primary':records[0]['id'],'records':records,'event':e}

    def snapshot(self):
        with self.store.connection() as db:
            self._scope(db);all_records=self._all(db)
            return {'protocol':'ww-operations-snapshot/v1','scope':self.scope,
                'assignments':[r for r in all_records if r['kind']=='assignment'],
                'attempts':[r for r in all_records if r['kind']=='attempt'],
                'returns':[r for r in all_records if r['kind']=='return'],
                'cursor':db.execute('SELECT coalesce(max(sequence),0) FROM events').fetchone()[0]}

    def _events(self,db):
        return [{**json.loads(r['document']),'sha256':r['sha256']} for r in db.execute('SELECT document,sha256 FROM events WHERE profile=? ORDER BY sequence',(self.scope['profile'],))]

    def events(self,after=0,limit=100):
        if type(after) is not int or after<0 or type(limit) is not int or not 1<=limit<=1000:raise OpError('invalid_input','Use a nonnegative cursor and limit 1..1000.')
        with self.store.connection() as db:
            self._scope(db);selected=[e for e in self._events(db) if e['sequence']>after];rows=selected[:limit]
            return {'scope':self.scope,'events':rows,'next_cursor':rows[-1]['sequence'] if rows else after,'has_more':len(selected)>limit}

    def lens(self,name,**parameters):
        from .lenses import project
        with self.store.connection() as db:
            self._scope(db);return project(name,self._events(db),self.scope,**parameters)

    def audit(self):
        from .audit import inspect
        with self.store.connection() as db:
            self._scope(db)
            errors = inspect(db)
            return {'ok': not errors, 'errors': errors, 'scope': self.scope,
                    'boundary': 'Local consistency, not a signature or external verification.'}
