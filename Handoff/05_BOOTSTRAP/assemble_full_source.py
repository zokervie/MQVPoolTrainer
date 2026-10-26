#!/usr/bin/env python3
"""Tạo ZIP trọn 100% tracked source từ repo Zoker Pool Trainer private + bộ hồ sơ handoff.
Requires git + network + GitHub credentials. No signing credentials are embedded.
"""
import argparse
import datetime as dt
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import zipfile

REPO = 'https://github.com/zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858.git'
PINNED = 'aba66d0f21e0816973ef0c13281fa98855ca3ff6'
EXPECTED_COUNT = 113

def run(*args, cwd=None):
    cp = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if cp.returncode != 0:
        raise RuntimeError(f"Lệnh lỗi: {' '.join(map(str,args))}\n{cp.stderr[-4000:]}\n"
                           'Nếu clone repo private lỗi: xác minh GitHub credentials bằng git/gh trên máy Agent.')
    return cp.stdout.strip()

def sha256(blob: bytes):
    return hashlib.sha256(blob).hexdigest()

def main():
    here = Path(__file__).resolve().parent
    root = here.parent
    ap = argparse.ArgumentParser(description='Tải source Zoker Pool Trainer theo SHA và đóng gói trọn source + handoff')
    ap.add_argument('--mode', choices=['pinned','latest'], default='pinned', help='pinned dùng SHA audit 24/10; latest dùng origin/main mới nhất')
    ap.add_argument('--output-dir', default=str(root.parent), help='Thư mục output')
    ap.add_argument('--repo-url', default=REPO, help='Chỉ thay cho QA hoặc repo được chủ dự án xác nhận')
    ap.add_argument('--ref', default=PINNED, help='Commit chính xác trong mode pinned')
    args=ap.parse_args()
    if shutil.which('git') is None:
        raise RuntimeError('Thiếu git. Cài Git trên máy rồi chạy lại.')
    out = Path(args.output_dir).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='zoker_full_src_') as tmp:
        t=Path(tmp)
        repo=t/'checked-out-repository'
        print('[1/5] Cloning private source repository: ',args.repo_url)
        run('git','clone','--quiet','--no-checkout',args.repo_url,str(repo))
        run('git','-C',str(repo),'fetch','--quiet','origin','main')
        desired = args.ref if args.mode=='pinned' else 'refs/remotes/origin/main'
        run('git','-C',str(repo),'checkout','--quiet','--detach',desired)
        commit=run('git','-C',str(repo),'rev-parse','HEAD')
        if args.mode=='pinned' and commit.lower()!=args.ref.lower():
            raise RuntimeError(f'Không khớp SHA. Expected {args.ref}, actual {commit}. Ngừng.')
        print('[2/5] Full SHA: ',commit)
        if args.mode=='latest' and commit!=PINNED:
            print('LƯU Ý: main đã mới hơn baseline! Phải audit diff và giữ các thay đổi hợp lệ.')
        archive=t/'repo.tar'
        run('git','-C',str(repo),'archive','--format=tar','-o',str(archive),'HEAD')
        source_files=[]
        # Dùng Git archive thay cho ZIP GitHub để giữ nguyên toàn bộ tracked code,
        # kể cả .github, file .gitignore, xcodeproj, asset descriptions.
        with tarfile.open(archive,'r') as tar:
            for entry in tar.getmembers():
                name=entry.name
                path=Path(name)
                if path.is_absolute() or '..' in path.parts:
                    raise RuntimeError(f'Unsafe path inside repository: {name}')
                if entry.isdir():
                    continue
                if not entry.isfile():
                    raise RuntimeError(f'Unsupported symlink/special file: {name}. Handle explicitly for fidelity.')
                data=tar.extractfile(entry).read()
                source_files.append((name,data,entry.mode))
        print(f'[3/5] Captured {len(source_files)} tracked files')
        if args.mode=='pinned' and args.repo_url==REPO and len(source_files)!=EXPECTED_COUNT:
            raise RuntimeError(f'Expected {EXPECTED_COUNT} files, got {len(source_files)}: baseline mismatch; stop.')
        doc_files=[p for p in root.rglob('*') if p.is_file() and not p.name.endswith('.pyc')]
        doc_files.sort()
        packname=f'ZokerPoolTrainer_FULL_SOURCE_AND_HANDOFF_{commit[:12]}.zip'
        dest=out/packname
        print('[4/5] Creating ',dest)
        all_hashes=[]
        gitfiles={name: {'sha256':sha256(data),'size':len(data)} for name,data,mode in source_files}
        project_manifest={
            'repository':args.repo_url,'branch':'main','snapshot_commit':commit,
            'original_reference_sha':PINNED,'source_mode':args.mode,
            'tracked_source_file_count':len(source_files),
            'source_size_bytes':sum(len(data) for _,data,_ in source_files),
            'source_root':'ProjectSource/',
            'contains_git_history':False,
            'documentation_root':'Handoff/',
            'generated_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
            'files':gitfiles,
            'notes':'Tracked source only. Generated 3D assets may require Tools/prepare_ci_assets.py on Mac CI. Signing secrets/IPA not bundled.'
        }
        with zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=7,allowZip64=True) as z:
            for name,data,mode in source_files:
                target='ProjectSource/'+name
                zi=zipfile.ZipInfo(target)
                zi.compress_type=zipfile.ZIP_DEFLATED
                zi.external_attr=(mode & 0xffff)<<16
                z.writestr(zi,data)
                all_hashes.append(f'{sha256(data)}  {target}')
            for p in doc_files:
                target='Handoff/'+p.relative_to(root).as_posix()
                data=p.read_bytes()
                z.writestr(target,data)
                all_hashes.append(f'{sha256(data)}  {target}')
            z.writestr('SOURCE_MANIFEST.json',json.dumps(project_manifest,ensure_ascii=False,indent=2).encode('utf-8'))
            z.writestr('INTERNAL_SHA256SUMS.txt','\n'.join(all_hashes).encode('utf-8'))
            z.writestr('READ_THIS_FIRST.txt',(
                'FULL SOURCE + HANDOFF CONFIRMED\n'
                f'Source SHA: {commit}\n'
                f'Tracked files: {len(source_files)}\n'
                'ProjectSource/ contains all git-tracked files from the exact commit.\n'
                'Handoff/ contains requirements, audits, lesson PDFs and Agent prompts.\n'
                'No IPA, signing keys or nontracked/generated assets are supplied.\n'
            ).encode('utf-8'))
        print('[5/5] Validating ZIP and SHA-256')
        with zipfile.ZipFile(dest,'r') as z:
            bad=z.testzip()
            if bad: raise RuntimeError('Bad CRC: '+bad)
            present=[p for p in z.namelist() if p.startswith('ProjectSource/') and not p.endswith('/')]
            if len(present)!=len(source_files):raise RuntimeError('ZIP count mismatch')
        digest=hashlib.sha256(dest.read_bytes()).hexdigest()
        (out/(packname+'.sha256')).write_text(f'{digest}  {packname}\n',encoding='utf-8')
        print('OK ZIP:',dest)
        print('SHA256:',digest)
        print('UNSIGNED IPA? No. Build output? No. Source snapshot only.')

if __name__=='__main__':
    try: main()
    except Exception as e:
        print('FAILED:',e,file=sys.stderr)
        sys.exit(1)
