# -*- coding: utf-8 -*-
import glob, os, struct, plistlib

extract = glob.glob(r'C:\Users\Administrator\Doubao\chats\2026-09-17\new-chat\WXQRCodeAuth\dist\WXQRCodeAuth-unsigned-ipa\unzipped\Payload\*.app')[0]

print('=== .app 包内容 ===')
for root, dirs, files in os.walk(extract):
    for fn in sorted(files):
        p = os.path.join(root, fn)
        rel = os.path.relpath(p, extract)
        print(f'  {rel}  ({os.path.getsize(p)} bytes)')

# Mach-O 架构
with open(os.path.join(extract, 'Info.plist'), 'rb') as f:
    pl = plistlib.load(f)
exe = os.path.join(extract, pl['CFBundleExecutable'])
with open(exe, 'rb') as f:
    header = f.read(20)
magic, cputype, cpusubype, filetype, ncmds = struct.unpack('<IiiII', header)
cpu_map = {0x0100000C: 'ARM64 (真机)', 0x01000007: 'x86_64 (模拟器!)', 12: 'ARM(32)'}
ft_map = {2: 'EXECUTE'}
print('\n=== Mach-O Header ===')
print(f'magic: 0x{magic:08x} (MH_MAGIC_64)')
print(f'cputype: 0x{cputype:08x} -> {cpu_map.get(cputype, "未知")}')
print(f'cpusubtype: {cpusubype}')
print(f'filetype: {filetype} ({ft_map.get(filetype,"?")})')
print(f'load commands: {ncmds}')
