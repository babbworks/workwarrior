"""Private local SQLite operational journal; no implicit initialization or migration."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import sqlite3
import tempfile
from urllib.parse import quote
import uuid

from .contracts import OpError, canonical, digest, now, text

DATABASE='operations.sqlite3'
APP_ID=0x57574f31
SCHEMA='''
CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE objects(id TEXT PRIMARY KEY,profile TEXT NOT NULL,kind TEXT NOT NULL,document TEXT NOT NULL);
CREATE TABLE versions(id TEXT NOT NULL,revision INTEGER NOT NULL,document TEXT NOT NULL,PRIMARY KEY(id,revision));
CREATE TABLE events(sequence INTEGER PRIMARY KEY,profile TEXT NOT NULL,document TEXT NOT NULL,sha256 TEXT NOT NULL);
CREATE TABLE requests(profile TEXT NOT NULL,key TEXT NOT NULL,fingerprint TEXT NOT NULL,plan TEXT NOT NULL,receipt TEXT NOT NULL,PRIMARY KEY(profile,key));
CREATE TABLE source_events(profile TEXT NOT NULL,producer TEXT NOT NULL,source_event TEXT NOT NULL,fingerprint TEXT NOT NULL,event_id TEXT NOT NULL,PRIMARY KEY(profile,producer,source_event));
'''


def initialize(path,organization,apply=False):
    root=Path(path).expanduser().resolve();text(organization,'organization')
    for p in (root,*root.parents):
        marker=p/'.git'
        if (marker.is_dir() and (marker/'HEAD').is_file()) or (marker.is_file() and marker.read_text().startswith('gitdir:')):
            raise OpError('unsafe_store','Operational data must be outside source repositories.')
    if any((root/n).exists() for n in (DATABASE,'abc123.sqlite3','profiles','registry','creations')):
        raise OpError('store_exists','Use a dedicated new operational data directory.')
    plan={'protocol':'ww-operations-init/v1','root':str(root),'organization':organization}
    plan['plan_sha256']=digest(plan)
    if not apply:return plan
    root.mkdir(parents=True,exist_ok=True,mode=0o700)
    fd,name=tempfile.mkstemp(prefix='.ww-init-',dir=root);os.close(fd)
    temp=Path(name)
    try:
        with sqlite3.connect(temp) as db:
            db.executescript(SCHEMA);db.execute(f'PRAGMA application_id={APP_ID}');db.execute('PRAGMA user_version=1')
            db.execute('PRAGMA synchronous=FULL')
            meta={'instance':str(uuid.uuid4()),'organization':organization,'created_at':now(),'principal_uid':os.getuid()}
            db.executemany('INSERT INTO metadata VALUES (?,?)',[(k,json.dumps(v)) for k,v in meta.items()])
        db.close()
        try:os.link(temp,root/DATABASE)
        except FileExistsError as exc:raise OpError('store_exists','Another writer initialized the store.') from exc
        dfd=os.open(root,os.O_RDONLY|os.O_DIRECTORY)
        try:os.fsync(dfd)
        finally:os.close(dfd)
        return {**meta,'root':str(root),'schema':1}
    finally:temp.unlink(missing_ok=True)


class Store:
    def __init__(self,path):self.root=Path(path).expanduser().resolve();self.path=self.root/DATABASE

    @contextmanager
    def connection(self,write=False):
        if not self.path.is_file() or self.path.is_symlink():raise OpError('store_missing','Initialize a dedicated operational store first.')
        db=None
        try:
            db=sqlite3.connect('file:'+quote(str(self.path),safe='/')+'?mode='+('rw' if write else 'ro'),uri=True,timeout=10,isolation_level=None)
            db.row_factory=sqlite3.Row
            if db.execute('PRAGMA application_id').fetchone()[0]!=APP_ID or db.execute('PRAGMA user_version').fetchone()[0]!=1:
                raise OpError('unsupported_store','Not a supported operational store.')
            if write:db.execute('PRAGMA synchronous=FULL')
            else:db.execute('PRAGMA query_only=ON')
            db.execute('BEGIN IMMEDIATE' if write else 'BEGIN')
            yield db
            if write:db.commit()
        except sqlite3.DatabaseError as exc:
            raise OpError('store_busy' if 'locked' in str(exc).lower() else 'storage_error','Operational storage failed or is busy.') from exc
        finally:
            if db is not None:
                if db.in_transaction:db.rollback()
                db.close()

    @staticmethod
    def info(db):return {r['key']:json.loads(r['value']) for r in db.execute('SELECT * FROM metadata')}
