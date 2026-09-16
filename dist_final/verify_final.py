# -*- coding: utf-8 -*-
import zipfile, plistlib, os, glob, struct

base = r'C:\Users\Administrator\Doubao\chats\2026-09-17\new-chat\WXQRCodeAuth\dist_final\WXQRCodeAuth-unsigned-ipa'
ipa = glob.glob(os.path.join(base, '*.ipa'))[0]
print('IPA:', os.path.basename(ipa), '|', os.path.getsize(ipa), 'bytes')
extract = os.path.join(base, 'unzipped')
import shutil
if os.path.exists(extract): shutil.rmtree(extract)
with zipfile.ZipFile(ipa) as z: z.extractall(extract)
app = glob.glob(os.path.join(extract, 'Payload', '*.app'))[0]
with open(os.path.join(app, 'Info.plist'), 'rb') as f: pl = plistlib.load(f)

print('\n--- 基本 ---')
for k in ['CFBundleDisplayName','CFBundleIdentifier','CFBundleShortVersionString','MinimumOSVersion']:
    print(f'{k} = {pl.get(k)}')
schemes = []
for t in pl.get('CFBundleURLTypes', []): schemes += t.get('CFBundleURLSchemes', [])
print('接管 schemes =', schemes)
need_schemes = {'weixin','weixinULAPI','weixinURLParamsAPI','wechat','weixinapp','wexinVideoAPI'}
print('scheme 齐全:', need_schemes.issubset(set(schemes)))

exe = os.path.join(app, pl['CFBundleExecutable'])
with open(exe,'rb') as f: hdr = f.read(20); raw = f.read()
magic, cputype = struct.unpack('<Ii', hdr[:8])
print('\n--- 架构 ---')
print(f'Mach-O magic=0x{magic:08x} cputype=0x{cputype:08x} ->', 'ARM64 真机' if cputype==0x0100000c else '非ARM64!')

text = raw.decode('latin-1')
print('\n--- 关键逻辑字符串 ---')
for c in ['app/qrconnect','connect/confirm?uuid=','l/qrconnect','wx_errcode','wx_redirecturl',
          'MicroMessenger','snsapi_userinfo','oauth?code=','CIQRCodeGenerator',
          'handleIncomingURL','startShowCode','auth_nickname','uuid:']:
    print(('  OK ' if c in text else '  缺失! ')+c)

print('\n--- 资源 ---')
for root,_,files in os.walk(app):
    for fn in files:
        print('  ', os.path.relpath(os.path.join(root,fn), app))
