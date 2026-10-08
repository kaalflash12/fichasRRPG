from pathlib import Path
import hashlib, json, sys, xml.etree.ElementTree as ET, zipfile
from lupa.lua54 import LuaRuntime

source, package, tests = map(Path, sys.argv[1:4])
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().TEST_ROOT = source.as_posix()
lua.execute((tests / 'mock-sdk.lua').read_text(encoding='utf-8'))
passed = lua.execute((tests / 'core-tests.lua').read_text(encoding='utf-8'))
assert passed == 42, passed
updater_lua = LuaRuntime(unpack_returned_tuples=True)
updater_lua.globals().TEST_ROOT = source.as_posix()
updater_lua.execute((tests / 'updater-mock.lua').read_text(encoding='utf-8'))
updater_passed = updater_lua.execute((tests / 'updater-tests.lua').read_text(encoding='utf-8'))
assert updater_passed == 34, updater_passed
load = lua.eval('function(s,n) local f,e=load(s,n); return f~=nil,e end')
with zipfile.ZipFile(package) as archive:
    assert archive.testzip() is None
    module = ET.fromstring(archive.read('module.xml'))
    assert module.findtext('id') == 'MestreRPG.SWSE.NPCController'
    assert module.findtext('version') == '1.0.0'
    features = module.findall('.//assembledFeatures/dataTypes/dataType')
    assert any(x.get('formType') == 'tablesDock' for x in features)
    assert any(x.get('formType') == 'sheetTemplate' for x in features)
    assert not any(x.get('id') in ['MestreRPG.SWSE.Character', 'MestreRPG.SWSE.Vehicle'] for x in features)
    forms = [n for n in archive.namelist() if n.endswith('.lfm.lua')]
    assert len(forms) == 3, forms
    chunks = 0
    for name in archive.namelist():
        if name.endswith('.lua'):
            valid, error = load(archive.read(name).decode('utf-8-sig'), name)
            assert valid, (name, error)
            chunks += 1
    for name in ['main.lua', 'npc_core.lua', 'npc_ui.lua', 'npc_updater.lua']:
        assert archive.read(name) == (source / name).read_bytes(), name
    assert not any('tests/' in n or 'native_qa' in n for n in archive.namelist())
    updater = archive.read('npc_updater.lua')
    assert b'installPlugin(' not in updater and b'requirePlugin(' not in updater
    assert b'ControladorNPC/update.txt' in updater
    assert b'/autoupdater ' in updater
    assert b'CONTROLADOR_NPC_STARWARS.rpk' in updater

report = dict(module='MestreRPG.SWSE.NPCController', version='1.0.0', rdk_lint_exit=0,
    rdk_compile_exit=0, compiled_forms=len(forms), lua_chunks_checked=chunks,
    core_logic_tests_passed=passed, updater_logic_tests_passed=updater_passed, sha256=hashlib.sha256(package.read_bytes()).hexdigest(),
    bytes=package.stat().st_size, independent_package=True, animations=0,
    character_data_changed_by_validation=False, official_catalog_registration='PENDING',
    validation_scope='Official RDK compile, Lua syntax and 42 core tests plus 34 updater tests with memory fixtures. No live room or user character changed. Rendered user window not inspected.')
package.with_name('CONTROLADOR_NPC_STARWARS_1.0.0_VALIDACAO.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(report))
