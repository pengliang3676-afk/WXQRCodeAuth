# -*- coding: utf-8 -*-
import zipfile, plistlib, os, glob, subprocess

ipa_dir = r'C:\Users\Administrator\Doubao\chats\2026-09-17\new-chat\WXQRCodeAuth\dist\WXQRCodeAuth-unsigned-ipa'
ipa = glob.glob(os.path.join(ipa_dir, '*.ipa'))[0]
print('IPA 文件:', os.path.basename(ipa), '大小:', os.path.getsize(ipa), 'bytes')

extract = os.path.join(ipa_dir, 'unzipped')
with zipfile.ZipFile(ipa) as z:
    z.extractall(extract)

apps = glob.glob(os.path.join(extract, 'Payload', '*.app'))
app = apps[0]
print('\n.app 包:', os.path.basename(app))

# Info.plist
with open(os.path.join(app, 'Info.plist'), 'rb') as f:
    pl = plistlib.load(f)

print('\n=== 基本信息 ===')
for k in ['CFBundleDisplayName', 'CFBundleIdentifier', 'CFBundleExecutable',
          'CFBundleShortVersionString', 'MinimumOSVersion', 'UILaunchStoryboardName']:
    print(f'{k}: {pl.get(k)}')

print('\n=== CFBundleURLTypes（接管的 scheme）===')
for t in pl.get('CFBundleURLTypes', []):
    print('URLName:', t.get('CFBundleURLName'))
    print('Schemes:', t.get('CFBundleURLSchemes'))

print('\n=== LSApplicationQueriesSchemes ===')
print(pl.get('LSApplicationQueriesSchemes'))

print('\n=== ATS ===')
print(pl.get('NSAppTransportSecurity'))

# 二进制架构
exe = os.path.join(app, pl['CFBundleExecutable'])
print('\n=== 二进制 ===')
print('可执行文件:', pl['CFBundleExecutable'], '大小:', os.path.getsize(exe))
try:
    out = subprocess.check_output(['lipo', '-info', exe], stderr=subprocess.STDOUT).decode()
    print(out.strip())
except Exception as e:
    # Windows 无 lipo，读 Mach-O magic
    with open(exe, 'rb') as f:
        magic = f.read(4)
    print('Mach-O magic:', magic.hex(), '(cffaedfe/feedfacf=cigam 64位, cefaedfe=小端64位)')

# 关键字符串检查
with open(exe, 'rb') as f:
    data = f.read()
text = data.decode('latin-1')
print('\n=== 关键逻辑字符串检查 ===')
checks = [
    'app/qrconnect', 'connect/confirm?uuid=', 'l/qrconnect',
    'wx_errcode', 'wx_redirecturl', 'MicroMessenger',
    'snsapi_userinfo', 'oauth?code=', 'CIQRCodeGenerator',
    'handleIncomingURL', 'startShowCode', 'openURL',
]
for c in checks:
    print(f'{"✓" if c in text else "✗ 缺失"} {c}')
