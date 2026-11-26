#!/usr/bin/env python3
"""Turns a RustDesk source checkout into Fox Zdalny (+ the Fox Pomoc support variant).

Run from the RustDesk source root:
    FOX_HOST=zdalny.example.com FOX_KEY=<server pubkey> python3 fox/client/apply_branding.py

What it does:
  1. copies client/branding/overlay/* (icons, logos) over the source tree
  2. writes src/fox_custom.json from variants/fox-zdalny.json - compiled into the
     binary as the default config (app name, YOUR server + key, locked settings)
  3. writes fox_variants/<id>.json for every variant; the packaging steps drop it
     next to the executable (macOS: Contents/Resources) as fox_custom.json, which
     then overrides the built-in default - one build, several apps
  4. patches src/common.rs to load that config through RustDesk's own
     "custom client" mechanism (no signature needed)
Every patch asserts the exact upstream text, so a RustDesk upgrade that moves the
code fails loudly here instead of silently producing a stock RustDesk.
"""
import glob, json, os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.getcwd()
DEFAULT_VARIANT = "fox-zdalny"

host = os.environ.get("FOX_HOST", "").strip()
key = os.environ.get("FOX_KEY", "").strip()
if not host or not key:
    sys.exit("FOX_HOST and FOX_KEY must be set (GitHub: Settings > Secrets and variables > Actions)")
if not re.fullmatch(r"[A-Za-z0-9+/]{43}=", key):
    sys.exit("FOX_KEY is not a valid server key: expected 44 characters ending with '=' "
             "(contents of id_ed25519.pub), got %d characters ending with %r" % (len(key), key[-2:]))
if not re.fullmatch(r"[A-Za-z0-9.-]+(:[0-9]+)?", host):
    sys.exit("FOX_HOST must be a bare host name or IP (e.g. zdalny.example.com), got %r" % host)
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


# 2 + 3. custom-client configs
def custom_config(v):
    settings = {"custom-rendezvous-server": host, "relay-server": host, "api-server": "", "key": key}
    settings.update(v.get("override_settings", {}))
    cfg = {"app-name": v["app_name"], "override-settings": settings}
    cfg.update(v.get("hard_settings", {}))
    return cfg


os.makedirs(os.path.join(ROOT, "fox_variants"), exist_ok=True)
for path in sorted(glob.glob(os.path.join(HERE, "variants", "*.json"))):
    v = json.load(open(path))
    cfg = json.dumps(custom_config(v), indent=2)
    with open(os.path.join(ROOT, "fox_variants", v["id"] + ".json"), "w") as fh:
        fh.write(cfg)
    if v["id"] == DEFAULT_VARIANT:
        with open(os.path.join(ROOT, "src/fox_custom.json"), "w") as fh:
            fh.write(cfg)
    print("variant:", v["id"], "->", v["app_name"])
assert os.path.isfile(os.path.join(ROOT, "src/fox_custom.json")), "variants/%s.json missing" % DEFAULT_VARIANT

# 4. patch src/common.rs
path = os.path.join(ROOT, "src/common.rs")
src = open(path, encoding="utf-8").read()

old_load = "pub fn load_custom_client() {\n"
assert src.count(old_load) == 1, "load_custom_client() not found - RustDesk changed, update apply_branding.py"
src = src.replace(
    old_load,
    "#[allow(unreachable_code)]\n" + old_load +
    "    // Fox Zdalny, see fox/client/apply_branding.py:\n"
    "    // a variant config next to the executable wins over the built-in default.\n"
    "    if let Some(dir) = std::env::current_exe().ok().and_then(|x| x.parent().map(|p| p.to_path_buf())) {\n"
    "        #[cfg(target_os = \"macos\")]\n"
    "        let dir = dir.join(\"../Resources\");\n"
    "        if let Ok(data) = std::fs::read_to_string(dir.join(\"fox_custom.json\")) {\n"
    "            read_custom_client(data.trim());\n"
    "            return;\n"
    "        }\n"
    "    }\n"
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
