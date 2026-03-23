# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_submodules

hiddenimports = ['pandas', 'plushie']
hiddenimports += collect_submodules('plushie')
hiddenimports += collect_submodules('pandas')


a = Analysis(
    ['src/data_explorer/__main__.py'],
    pathex=[],
    binaries=[('/home/devuser/.local/share/plushie/bin/plushie-linux-x86_64', '.')],
    datas=[('sample_data', 'sample_data')],
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='DataExplorer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='DataExplorer',
)
