#!/usr/bin/env python3
"""Turns a RustDesk source checkout into Fox Zdalny.

Run from the RustDesk source root:
    FOX_HOST=zdalny.example.com FOX_KEY=<server pubkey> python3 fox/client/apply_branding.py

What it does:
  1. copies client/branding/overlay/* (icons, logos) over the source tree
  2. writes src/fox_custom.json (app name, YOUR server + key, locked security settings)
  3. patches src/common.rs so that JSON is compiled into the binary and loaded at
     start-up through RustDesk's own "custom client" mechanism (no signature needed)
Every patch asserts the exact upstream text, so a RustDesk upgrade that moves the
code fails loudly here instead of silently producing a stock RustDesk.
"""
import json, os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.getcwd()

with open(os.path.join(HERE, "branding.json")) as fh:
    BR = json.load(fh)

host = os.environ.get("FOX_HOST", "").strip()
key = os.environ.get("FOX_KEY", "").strip()
if not host or not key:
    sys.exit("FOX_HOST and FOX_KEY must be set (GitHub: Settings > Secrets and variables > Actions)")
if not os.path.isfile(os.path.join(ROOT, "src/common.rs")):
    sys.exit("run this from the RustDesk source root")

# 1. overlay
overlay = os.path.join(HERE, "branding", "overlay")
for dirpath, _, files in os.walk(overlay):
    for f in files:
        src = os.path.join(dirpath, f)
        rel = os.path.relpath(src, overlay)
        dst = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        print("overlay:", rel)

# 2. embedded custom-client config
settings = {
    "custom-rendezvous-server": host,
    "relay-server": host,
    "api-server": "",
    "key": key,
}
settings.update(BR.get("override_settings", {}))
custom = {"app-name": BR["app_name"], "override-settings": settings}
custom.update(BR.get("hard_settings", {}))
with open(os.path.join(ROOT, "src/fox_custom.json"), "w") as fh:
    json.dump(custom, fh, indent=2)
print("wrote src/fox_custom.json")

# 3. patch src/common.rs
path = os.path.join(ROOT, "src/common.rs")
src = open(path, encoding="utf-8").read()

old_load = "pub fn load_custom_client() {\n"
assert src.count(old_load) == 1, "load_custom_client() not found - RustDesk changed, update apply_branding.py"
src = src.replace(
    old_load,
    "#[allow(unreachable_code)]\n" + old_load +
    "    // Fox Zdalny: built-in config, see fox/client/apply_branding.py\n"
    "    read_custom_client(include_str!(\"fox_custom.json\"));\n"
    "    return;\n",
)

pat = re.compile(
    r"(pub fn read_custom_client\(config: &str\) \{\n)"
    r"    let Ok\(data\) = decode64\(config\) else \{.*?"
    r"    let Ok\(data\) = sign::verify\(&data, &pk\) else \{\n.*?\n    \};\n",
    re.S,
)
assert len(pat.findall(src)) == 1, "read_custom_client() signature check not found - update apply_branding.py"
src = pat.sub(r"\1    let data = config.as_bytes().to_vec();\n", src)

old_name = '    if let Some(app_name) = data.remove("app-name") {\n'
assert src.count(old_name) == 1, "app-name handling not found - update apply_branding.py"
# Linux packages hard-code the 'rustdesk' binary/service name, so keep the internal name there.
src = src.replace(
    old_name,
    '    #[cfg(target_os = "linux")]\n    data.remove("app-name");\n' + old_name,
)

open(path, "w", encoding="utf-8").write(src)
print("patched src/common.rs")
