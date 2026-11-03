#!/usr/bin/env python3
"""Run real gates and package their evidence. Never synthesize build results."""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess, os, signal, types
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]

# Giới hạn từng bước (giây): một bước treo không được ăn hết giờ của cả job.
STAGE_TIMEOUT = {'replay-recording':120,'lan-wire-protocol':120,'assets':600,'portable-regressions':1200,'simulator-build':1800,'screenshots-and-runtime-probes':2400,'ui-gesture-tests':1800,'unsigned-iphone-build':1500}

def run(portable=False):
    out = ROOT/'dist'
    out.mkdir(exist_ok=True)
    started = time.time()
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    logs = ROOT/'build'/'acceptance'/stamp
    logs.mkdir(parents=True)
    sha = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    report = {'source_sha':sha,'created_utc':stamp,'platform':platform.platform(),
              'mode':'portable' if portable else 'native','status':'RUNNING',
              'working_tree_modified':subprocess.check_output(['git','diff','HEAD','--name-only'],cwd=ROOT,text=True).splitlines(),
              'tracked_patch_sha256':hashlib.sha256(subprocess.check_output(['git','diff','HEAD','--binary'],cwd=ROOT)).hexdigest(),
              'physical_device':'NOT_RUN','signing':'UNSIGNED_ONLY','stages':[],'artifacts':[]}
    code = 0
    ipa = None
    try:
        if not portable and (platform.system()!='Darwin' or not shutil.which('xcodebuild')):
            report['status']='BLOCKED';report['blocker']='macOS with Xcode is required';code=2
            return code
        stages = [('assets',[sys.executable,'Tools/prepare_ci_assets.py']),
                  ('portable-regressions',['bash','Run-All-Checks.command'])]
        if not portable:
            stages += [('replay-recording',['bash','Tools/run_replay_checks.sh']),
                       ('lan-wire-protocol',['bash','Tools/run_lan_checks.sh']),
                       ('simulator-build',['bash','Verify-on-Mac.command']),
                       ('screenshots-and-runtime-probes',['bash','Tools/ci_screenshots.sh']),
                       ('ui-gesture-tests',['bash','Tools/run_ui_tests.sh']),
                       ('unsigned-iphone-build',['bash','Build-Unsigned-IPA.command'])]
        for name,command in stages:
            print('RUN',name,flush=True)
            log = logs/(name+'.log')
            limit = STAGE_TIMEOUT.get(name,1200)
            timed_out = False
            with log.open('w') as stream:
                proc = subprocess.Popen(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
                try:
                    returncode = proc.wait(timeout=limit)
                except subprocess.TimeoutExpired:
                    timed_out = True
                    os.killpg(proc.pid,signal.SIGKILL); proc.wait(); returncode = 124
                    stream.write('\nTIMEOUT: stage %s exceeded %d s\n' % (name,limit))
            result = types.SimpleNamespace(returncode=returncode)
            report['stages'].append({'name':name,'exit_code':result.returncode,
                                     'status':'TIMEOUT' if timed_out else ('PASS' if result.returncode==0 else 'FAIL'),
                                     'log':str(log.relative_to(ROOT))})
            if result.returncode:
                report['status']='FAILED';code=1
                print(log.read_text()[-6000:],flush=True)
                return code
        if not portable:
            app = ROOT/'build/DerivedData/Build/Products/Release-iphoneos/ZokerPoolTrainer.app'
            info = plistlib.loads((app/'Info.plist').read_bytes())
            assert info['CFBundleIdentifier']=='com.maiquocviet.BankLabS'
            ipa = out/('ZokerPoolTrainer-'+info['CFBundleShortVersionString']+'-Build'+str(info['CFBundleVersion'])+'.ipa')
            with zipfile.ZipFile(ipa) as archive:
                assert archive.testzip() is None
                prefix = 'Payload/ZokerPoolTrainer.app/'
                assert prefix+'Info.plist' in archive.namelist()
                binary = archive.read(prefix+info['CFBundleExecutable'])
                assert binary[:4] in (b'\xcf\xfa\xed\xfe',b'\xfe\xed\xfa\xcf',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca'), 'Missing Mach-O executable'
                assert not any('/_CodeSignature/' in name or name.endswith('embedded.mobileprovision') for name in archive.namelist()), 'Unexpected signing material'
            digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
            (out/'IPA_SHA256.txt').write_text(digest+'  '+ipa.name+'\n')
            report['artifacts'].append({'file':ipa.name,'sha256':digest,'bytes':ipa.stat().st_size,'version':info['CFBundleShortVersionString'],'build':str(info['CFBundleVersion'])})
        report['status']='PASSED_PORTABLE' if portable else 'PASSED_SIMULATOR_UNSIGNED'
    except Exception as error:
        report['status']='FAILED';report['error']=str(error);code=1
    finally:
        target = out/('ACCEPTANCE-'+sha[:12]+'-'+stamp+'.json')
        target.write_text(json.dumps(report,indent=2)+'\n')
        package = out/('Zoker-Acceptance-'+sha[:12]+'-'+stamp+'.zip')
        with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as archive:
            archive.write(target,target.name)
            for log in sorted(logs.glob('*.log')):archive.write(log,'logs/'+log.name)
            if not portable:
                for path in sorted((ROOT/'build/screenshots').rglob('*')):
                    if path.is_file() and path.stat().st_mtime>=started and path.suffix in ('.png','.json','.txt'):
                        archive.write(path,'screenshots/'+str(path.relative_to(ROOT/'build/screenshots')))
            if ipa is not None and report['status']=='PASSED_SIMULATOR_UNSIGNED':
                archive.write(ipa,ipa.name);archive.write(out/'IPA_SHA256.txt','IPA_SHA256.txt')
        print(json.dumps({'status':report['status'],'report':str(target),'package':str(package)}),flush=True)
    return code

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--portable',action='store_true')
    args=parser.parse_args()
    sys.exit(run(args.portable))
