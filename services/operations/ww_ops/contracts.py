"""Versioned operational input contracts. Actor strings are attribution only."""
import hashlib
import json
import math
import re
from datetime import datetime, timezone


class OpError(ValueError):
    def __init__(self,code,message):super().__init__(message);self.code=code
    def as_dict(self):return {'error':{'code':self.code,'message':str(self)}}


def canonical(data):
    try:return json.dumps(data,sort_keys=True,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode()
    except (ValueError,TypeError,UnicodeError) as exc:raise OpError('invalid_input','Use finite UTF-8 JSON data.') from exc


def digest(data):return hashlib.sha256(canonical(data)).hexdigest()
def now():return datetime.now(timezone.utc).isoformat(timespec='microseconds')


def fields(data,allowed,required=()):
    if not isinstance(data,dict) or set(data)-set(allowed) or set(required)-set(data):
        raise OpError('invalid_input','Missing or unknown input fields.')


def text(value,name='text'):
    if not isinstance(value,str) or not value.strip() or len(value)>1048576:
        raise OpError('invalid_input',f'{name} requires bounded nonblank text.')
    return value


def timestamp(value):
    text(value,'timestamp')
    try:
        dt=datetime.fromisoformat(value.replace('Z','+00:00'))
        if dt.tzinfo is None:raise ValueError()
        return dt.astimezone(timezone.utc).isoformat(timespec='microseconds')
    except ValueError as exc:raise OpError('invalid_input','Use an ISO timestamp with an explicit timezone.') from exc


def texts(value):
    if not isinstance(value,list):raise OpError('invalid_input','Expected a text array.')
    return [text(x) for x in value]


def scope(value):
    fields(value,('organization','instance','profile'),('organization','instance','profile'))
    result={k:text(value[k],k) for k in ('organization','instance','profile')}
    if not re.fullmatch(r'[A-Za-z0-9_.-]{1,100}',result['profile']):
        raise OpError('invalid_input','Profile is an explicit short identifier.')
    return result


def sha(value):
    if not isinstance(value,str) or not re.fullmatch('[a-f0-9]{64}',value):
        raise OpError('invalid_input','Expected a lowercase SHA-256 digest.')
    return value


def pin(value):
    fields(value,('id','revision','sha256'),('id','revision','sha256'))
    if type(value['revision']) is not int or value['revision']<1:raise OpError('invalid_input','A positive revision is required.')
    return {'id':text(value['id']),'revision':value['revision'],'sha256':sha(value['sha256'])}


def bindings(value):
    if not isinstance(value,list):raise OpError('invalid_input','Bindings must be an array.')
    result=[]
    for b in value:
        fields(b,('provider','id','revision','sha256','role'),('provider','id'))
        item={'provider':text(b['provider']),'id':text(b['id'])}
        if 'revision' in b:
            if not isinstance(b['revision'],(int,str)) or isinstance(b['revision'],bool):raise OpError('invalid_input','Invalid native revision.')
            item['revision']=b['revision']
        if 'sha256' in b:item['sha256']=sha(b['sha256'])
        if 'role' in b:item['role']=text(b['role'])
        result.append(item)
    if len({digest(b) for b in result})!=len(result):raise OpError('invalid_input','Duplicate native binding.')
    return result


def artifacts(value):
    if not isinstance(value,list):raise OpError('invalid_input','Artifacts must be an array.')
    result=[]
    for a in value:
        fields(a,('name','uri','sha256','bytes'),('name','uri','sha256','bytes'))
        if type(a['bytes']) is not int or a['bytes']<0:raise OpError('invalid_input','Artifact byte size must be nonnegative.')
        result.append({'name':text(a['name']),'uri':text(a['uri']),'sha256':sha(a['sha256']),'bytes':a['bytes']})
    if len({a['name'] for a in result})!=len(result):raise OpError('invalid_input','Artifact names must be unique.')
    return result


UNITS={'seconds':'duration','bytes':'data','tokens_in':'tokens','tokens_out':'tokens','search_queries':'count','pages':'count','USD':'currency'}


def usage(value):
    if not isinstance(value,list):raise OpError('invalid_input','Usage must be an array.')
    result=[]
    for item in value:
        fields(item,('unit','quantity','basis','source','registered_unit'),('unit','quantity','basis','source'))
        n=item['quantity']
        if type(n) not in (int,float) or not math.isfinite(n) or n<0:raise OpError('invalid_input','Usage requires a finite nonnegative quantity.')
        if item['basis'] not in ('measured','reported','estimated'):raise OpError('invalid_input','Identify the observation basis.')
        if 'registered_unit' in item and item['registered_unit']!=(item['unit'] in UNITS):raise OpError('invalid_input','Unit-registration label disagrees with this registry.')
        result.append({**item,'unit':text(item['unit']),'source':text(item['source']),
                       'registered_unit':item['unit'] in UNITS})
    return result
