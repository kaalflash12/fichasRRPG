from pathlib import Path
import hashlib
import json
import sys
import xml.etree.ElementTree as ET
import zipfile

from lupa.lua54 import LuaRuntime

source, package = map(Path, sys.argv[1:3])
build = Path(__file__).resolve().parent
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().TEST_ROOT = source.as_posix()
lua.execute((build / "mock-sdk.lua").read_text(encoding="utf-8"))
passed = lua.execute((build / "updater-tests.lua").read_text(encoding="utf-8"))
assert passed == 32, passed

syntax = lua.eval("function(s,n) local f,e=load(s,n); return f~=nil,e end")
with zipfile.ZipFile(package) as archive:
    assert archive.testzip() is None
    module = ET.fromstring(archive.read("module.xml"))
    assert module.findtext("id") == "MestreRPG.StarWarsSagaEdition"
    release_version = ET.parse(source / "module.xml").getroot().findtext("version")
    assert module.findtext("version") == release_version == "7.3.5"
    updater = archive.read("swse_updater.lua")
    assert updater == (source / "swse_updater.lua").read_bytes()
    assert b"kaalflash12/fichasRRPG" in updater
    assert b"starwars-saga-firecast" not in updater
    assert archive.read("swse_legacy_import.lua") == (source / "swse_legacy_import.lua").read_bytes()
    assert not any("jeta_source" in name or "native_main" in name for name in archive.namelist())
    chunks = 0
    for name in archive.namelist():
        if name.endswith(".lua"):
            ok, error = syntax(archive.read(name).decode("utf-8-sig"), name)
            assert ok, (name, error)
            chunks += 1
    forms = len([name for name in archive.namelist() if name.endswith(".lfm.lua")])
    assert forms == 19, forms
    main = archive.read("FichaRPGmeister/FichaRPGmeister.lfm.lua")
    assert b"swseDownloadButton" in main and b"swseUpdateButton" in main
    assert b"installPlugin(" not in updater and b"requirePlugin(" not in updater
    assert b"/autoupdater " in updater and b"openInBrowser" in updater
    assert b"fxDefaultOffApplied733" in main

report = {
    "version": release_version,
    "repository": "kaalflash12/fichasRRPG",
    "rdk_lint_exit": 0,
    "rdk_compile_exit": 0,
    "compiled_forms": forms,
    "lua_chunks_checked": chunks,
    "updater_logic_tests_passed": passed,
    "sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
    "bytes": package.stat().st_size,
    "importer_unchanged_from_7_3_3": True,
    "validation_scope": "RDK compile, Lua syntax and 32 updater tests under SDK mock. Native catalog registration and real native installation are not established by CI.",
    "update_paths": ["Public Auto Updater command for an approved catalog entry", "RPGmeister-style RPK download in browser"],
    "official_catalog_registration": "Pending maintainer approval; not granted by this build.",
}
package.with_name("STARWARS_SAGA_" + release_version + "_VALIDACAO.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(json.dumps(report, ensure_ascii=True))
