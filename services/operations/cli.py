#!/usr/bin/env python3
"""Structured local operational service, separate from the legacy ambient WW context."""
import argparse
import json
from pathlib import Path
import sys

from ww_ops import Operations,OpError,initialize


def read_json(source):
    if source=='-':raw=sys.stdin.buffer.read(8388609)
    else:
        with Path(source).open('rb') as stream:raw=stream.read(8388609)
    if len(raw)>8388608:raise OpError('invalid_input','Input exceeds 8 MiB.')
    def unique(pairs):
        result={}
        for k,v in pairs:
            if k in result:raise OpError('invalid_input','Duplicate JSON fields are refused.')
            result[k]=v
        return result
    try:return json.loads(raw,object_pairs_hook=unique,parse_constant=lambda _:(_ for _ in ()).throw(ValueError()))
    except (ValueError,UnicodeError) as exc:
        if isinstance(exc,OpError):raise
        raise OpError('invalid_input','Expected strict UTF-8 JSON.') from exc


def main(argv=None):
    parser=argparse.ArgumentParser(description='Workwarrior scoped operations: explicit assignments, events, returns and inventor lenses.')
    parser.add_argument('--store',help='Dedicated private operational data directory; never a source checkout.')
    group=parser.add_mutually_exclusive_group();group.add_argument('--scope-file');group.add_argument('--scope-json')
    subs=parser.add_subparsers(dest='command',required=True)
    subs.add_parser('capabilities',help='Describe the implemented interface without opening a data store.')
    init=subs.add_parser('init',help='Preview initialization; apply the exact hash after inspection.')
    init.add_argument('--organization',required=True);init.add_argument('--apply',action='store_true');init.add_argument('--plan-sha256')
    subs.add_parser('snapshot');subs.add_parser('info');subs.add_parser('audit')
    get=subs.add_parser('get');get.add_argument('identity')
    receipt=subs.add_parser('receipt');receipt.add_argument('key')
    events=subs.add_parser('events');events.add_argument('--after',type=int,default=0);events.add_argument('--limit',type=int,default=100)
    lens=subs.add_parser('lens');lens.add_argument('name');lens.add_argument('--method');lens.add_argument('--start');lens.add_argument('--end');lens.add_argument('--as-of');lens.add_argument('--recorded-before');lens.add_argument('--actor');lens.add_argument('--object',dest='object_id')
    plan=subs.add_parser('plan');plan.add_argument('operation');plan.add_argument('--input',required=True);plan.add_argument('--key',required=True)
    apply=subs.add_parser('apply');apply.add_argument('--input',required=True);apply.add_argument('--plan-sha256',required=True)
    request=subs.add_parser('request',help='One structured API request on stdin, used by configured adapters.');request.add_argument('--input',default='-')
    args=parser.parse_args(argv)
    try:
        if args.command=='capabilities':result=Operations.capabilities()
        elif not args.store:raise OpError('invalid_input','Supply an explicit --store.')
        elif args.command=='init':
            result=initialize(args.store,args.organization)
            if args.apply:
                if result['plan_sha256']!=args.plan_sha256:raise OpError('preview_required','Supply the exact initialization preview hash.')
                result=initialize(args.store,args.organization,apply=True)
        else:
            scope=read_json(args.scope_file) if args.scope_file else json.loads(args.scope_json) if args.scope_json else None
            ops=Operations(args.store,scope)
            if args.command=='request':result=dispatch(ops,read_json(args.input))
            elif args.command=='plan':result=ops.plan(args.operation,read_json(args.input),args.key)
            elif args.command=='apply':
                plan=read_json(args.input)
                if not isinstance(plan,dict) or plan.get('plan_sha256')!=args.plan_sha256:raise OpError('preview_required','Supply the inspected plan hash.')
                result=ops.apply(plan)
            elif args.command=='get':result=ops.get(args.identity)
            elif args.command=='receipt':result=ops.receipt(args.key)
            elif args.command=='events':result=ops.events(args.after,args.limit)
            elif args.command=='lens':result=ops.lens(args.name,**{k:getattr(args,k) for k in ('start','end','as_of','actor','object_id','method','recorded_before') if getattr(args,k) is not None})
            else:result=getattr(ops,args.command)()
        print(json.dumps(result,ensure_ascii=False,sort_keys=True,allow_nan=False));return 0
    except (OpError,OSError,ValueError) as exc:
        error=exc if isinstance(exc,OpError) else OpError('input_io_error','Unable to read valid operational input.')
        print(json.dumps(error.as_dict()));return 2 if error.code in ('storage_error','store_busy') else 1


def dispatch(ops,data):
    from ww_ops.contracts import fields,text
    fields(data,('command','operation','payload','key','plan','parameters','identity'),('command',))
    command=text(data['command'],'command')
    if command=='plan':return ops.plan(data.get('operation'),data.get('payload'),data.get('key'))
    if command=='apply':return ops.apply(data.get('plan'))
    if command=='get':return ops.get(data.get('identity'))
    if command=='receipt':return ops.receipt(data.get('key'))
    if command in ('lens','events'):
        parameters=data.get('parameters',{})
        fields(parameters,('start','end','as_of','actor','object_id','method','recorded_before') if command=='lens' else ('after','limit'))
        if command=='events':return ops.events(**parameters)
        return ops.lens(text(data.get('identity'),'lens'),**parameters)
    if command in ('snapshot','info','audit','capabilities'):return getattr(ops,command)()
    raise OpError('unsupported_operation','Unsupported structured operational read/action.')


if __name__=='__main__':sys.exit(main())
