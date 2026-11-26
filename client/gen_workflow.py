#!/usr/bin/env python3
"""Generates .github/workflows/build-fox-zdalny.yml from RustDesk's own CI.

Upstream build jobs are reused step-for-step (so toolchains, patches and vcpkg
pins stay exactly as RustDesk ships them); this script only:
  * checks out rustdesk/rustdesk@<tag> + this repo (into ./fox) and applies branding,
  * keeps Windows x64, macOS arm64 + x86_64 and Linux x86_64,
  * drops signing / tests / MSI templates / upstream release publishing,
  * renames outputs to FoxZdalny-* and collects them into a DRAFT release.

Upgrade RustDesk:  git clone --depth 1 -b <tag> --recurse-submodules https://github.com/rustdesk/rustdesk /tmp/rd
                   python3 client/gen_workflow.py /tmp/rd <tag>
"""
import copy, io, os, sys
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import LiteralScalarString as L

if len(sys.argv) != 3:
    sys.exit(__doc__)
RD, TAG = sys.argv[1], sys.argv[2]
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, ".github/workflows/build-fox-zdalny.yml")

yaml = YAML()
yaml.preserve_quotes = True
yaml.width = 4096
load = lambda f: yaml.load(open(os.path.join(RD, ".github/workflows", f)))
fb, br, tm = load("flutter-build.yml"), load("bridge.yml"), load("third-party-RustDeskTempTopMostWindow.yml")

CHECKOUT = "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
UPLOAD = "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
DOWNLOAD = "actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c"
RELEASE = "softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844"


def checkout_steps(branding=True):
    steps = [
        {"name": "Checkout RustDesk source", "uses": CHECKOUT,
         "with": {"repository": "rustdesk/rustdesk", "ref": TAG, "submodules": "recursive",
                  "persist-credentials": False}},
    ]
    if branding:
        steps += [
            {"name": "Checkout Fox Zdalny branding", "uses": CHECKOUT,
             "with": {"path": "fox", "persist-credentials": False}},
            {"name": "Apply Fox Zdalny branding", "shell": "bash",
             "env": {"FOX_HOST": "${{ secrets.FOX_HOST }}", "FOX_KEY": "${{ secrets.FOX_KEY }}"},
             "run": "python3 fox/client/apply_branding.py"},
        ]
    return steps


def rework(job, drop, branding=True, matrix_keep=None):
    job = copy.deepcopy(job)
    out = []
    for s in job["steps"]:
        n = s.get("name", "")
        if n == "Checkout source code":
            out += checkout_steps(branding)
        elif n in drop:
            continue
        else:
            out.append(s)
    job["steps"] = out
    if matrix_keep is not None:
        jobs = job["strategy"]["matrix"]["job"]
        job["strategy"]["matrix"]["job"] = [j for j in jobs if matrix_keep(j)]
    return job


def find(steps, name):
    return next(i for i, s in enumerate(steps) if s.get("name") == name)


jobs = {}

# --- fail fast when the server address/key secrets are missing --------------
jobs["check-config"] = {
    "runs-on": "ubuntu-22.04",
    "steps": [{"name": "Check FOX_HOST / FOX_KEY secrets", "shell": "bash",
               "env": {"FOX_HOST": "${{ secrets.FOX_HOST }}", "FOX_KEY": "${{ secrets.FOX_KEY }}"},
               "run": L('if [ -z "$FOX_HOST" ] || [ -z "$FOX_KEY" ]; then\n'
                        '  echo "::error::Set repo secrets FOX_HOST and FOX_KEY (Settings > Secrets and variables > Actions)"\n'
                        '  exit 1\n'
                        'fi\n'
                        'echo "Server: $FOX_HOST"\n')}],
}

# --- flutter_rust_bridge (unbranded, generated code only) -----------------
bridge = rework(br["jobs"]["generate_bridge"], set(), branding=False)
bridge["env"] = dict(br["env"])
bridge["needs"] = ["check-config"]
jobs["generate-bridge"] = bridge

# --- Windows helper DLL (privacy mode) ------------------------------------
t = copy.deepcopy(tm["jobs"]["build-RustDeskTempTopMostWindow"])
t["runs-on"] = "windows-2022"
t["env"] = {"project_path": tm["env"]["project_path"],
            "build_output_dir": "RustDeskTempTopMostWindow/WindowInjection/x64/Release"}
for s in t["steps"]:
    if "run" in s:
        s["run"] = L(str(s["run"]).replace("${{ inputs.configuration }}", "Release")
                     .replace("${{ inputs.platform }}", "x64")
                     .replace("${{ inputs.target_version }}", "Windows10"))
    if s.get("if") == "${{ inputs.upload-artifact }}":
        del s["if"]
    if "with" in s and "name" in s["with"]:
        s["with"]["name"] = "topmostwindow-artifacts-x64"
t["needs"] = ["check-config"]
jobs["build-topmostwindow"] = t

# --- Windows x64 -------------------------------------------------------------
win = rework(fb["jobs"]["build-for-windows-flutter"], {
    "Run the Rust tests", "Upload unsigned", "Sign rustdesk files", "Verify Windows Flutter version",
    "Verify template payload signatures", "Build template packer", "Upload unsigned template packer",
    "Add MSBuild to PATH", "Build msi", "Build pre-built MSI template", "Upload unsigned msi template",
    "Sign rustdesk self-extracted file", "Upload signed Windows Flutter EXE",
    "Upload signed Windows Flutter MSI", "Publish Release",
}, matrix_keep=lambda j: j["arch"] == "x86_64")
win["needs"] = ["build-topmostwindow", "generate-bridge"]
i = find(win["steps"], "Build self-extracted executable")
win["steps"][i]["run"] = L(str(win["steps"][i]["run"]).replace(
    "./SignOutput/rustdesk-${{ env.VERSION }}-${{ matrix.job.arch }}.exe",
    "./SignOutput/FoxZdalny-${{ env.VERSION }}-${{ matrix.job.arch }}.exe"))
assert "FoxZdalny-" in win["steps"][i]["run"]
win["steps"] += [
    # Same binary, packed together with the Fox Pomoc config (see apply_branding.py).
    {"name": "Build Fox Pomoc (support) executable", "shell": "bash", "run": L(
        "rm -rf ./rustdesk-pomoc && cp -r ./rustdesk ./rustdesk-pomoc\n"
        "cp ./fox_variants/fox-pomoc.json ./rustdesk-pomoc/fox_custom.json\n"
        "pushd ./libs/portable\n"
        "python3 ./generate.py -f ../../rustdesk-pomoc/ -o . -e ../../rustdesk-pomoc/rustdesk.exe\n"
        "popd\n"
        "mv ./target/release/rustdesk-portable-packer.exe ./SignOutput/FoxPomoc-${{ env.VERSION }}-${{ matrix.job.arch }}.exe\n"
        "ls -l ./SignOutput\n")},
    {"name": "Upload Fox Zdalny (Windows)", "uses": UPLOAD,
     "with": {"name": "fox-windows-${{ matrix.job.arch }}",
              "path": "./SignOutput/Fox*.exe", "if-no-files-found": "error"}},
]
jobs["build-windows"] = win

# --- macOS arm64 + x86_64 ----------------------------------------------------
mac = rework(fb["jobs"]["build-for-macOS"], {
    "Import the codesign cert", "Check sign and import sign key", "Import notarize key",
    "Install rcodesign tool", "Run the Dart tests", "Test verified updates", "Run the Rust tests",
    "create unsigned dmg", "Upload unsigned macOS app", "Codesign app and create signed dmg",
    "Rename rustdesk", "Upload signed macOS DMG", "Publish DMG package",
})
REL = "./flutter/build/macos/Build/Products/Release"
DMG = ("create-dmg --volname \"{disp}\" --icon \"{app}.app\" 200 190 --hide-extension \"{app}.app\" "
       "--window-size 800 400 --app-drop-link 600 185 "
       "{app}-${{{{ env.VERSION }}}}-${{{{ matrix.job.arch }}}}.dmg {dir}/{app}.app\n")
mac["steps"] += [
    {"name": "Rebrand app bundles", "shell": "bash", "run": L(
        "mkdir -p ./pomoc && ditto %s/RustDesk.app ./pomoc/RustDesk.app\n"
        "bash fox/client/macos_rebrand.sh fox/client/variants/fox-pomoc.json ./pomoc ./fox_variants/fox-pomoc.json\n"
        "bash fox/client/macos_rebrand.sh fox/client/variants/fox-zdalny.json %s\n" % (REL, REL))},
    {"name": "Create dmg", "shell": "bash", "run": L(
        'CREATE_DMG="$(readlink -f "$(command -v create-dmg)")"\n'
        "sed -i -e 's/MAXIMUM_UNMOUNTING_ATTEMPTS=3/MAXIMUM_UNMOUNTING_ATTEMPTS=7/' \"$CREATE_DMG\"\n"
        + DMG.format(disp="Fox Zdalny", app="FoxZdalny", dir=REL)
        + DMG.format(disp="Fox Pomoc", app="FoxPomoc", dir="./pomoc"))},
    {"name": "Upload Fox Zdalny (macOS)", "uses": UPLOAD,
     "with": {"name": "fox-macos-${{ matrix.job.arch }}",
              "path": "Fox*-${{ env.VERSION }}-${{ matrix.job.arch }}.dmg", "if-no-files-found": "error"}},
]
jobs["build-macos"] = mac

# --- Linux x86_64 ------------------------------------------------------------
lin = rework(fb["jobs"]["build-rustdesk-linux"], {
    "Publish debian/rpm package", "Upload deb", "Patch archlinux PKGBUILD",
    "Build archlinux package", "Publish archlinux package",
}, matrix_keep=lambda j: j["arch"] == "x86_64")
lin["steps"] = [s for s in lin["steps"] if s.get("name") != "Install CMake for vcpkg on Linux ARM64"]
lin["steps"] += [
    {"name": "Rename packages", "shell": "bash", "run": L(
        "sudo chown -R $(id -u):$(id -g) . || true\n"
        "mkdir -p out\n"
        "mv rustdesk-${{ env.VERSION }}-${{ matrix.job.arch }}.deb out/FoxZdalny-${{ env.VERSION }}-${{ matrix.job.arch }}.deb\n"
        "for f in rustdesk-*.rpm; do case \"$f\" in *suse*) ;; *) mv \"$f\" out/FoxZdalny-${{ env.VERSION }}-${{ matrix.job.arch }}.rpm ;; esac; done\n"
        "ls -l out\n")},
    {"name": "Upload Fox Zdalny (Linux)", "uses": UPLOAD,
     "with": {"name": "fox-linux-${{ matrix.job.arch }}", "path": "out/*", "if-no-files-found": "error"}},
]
# run-on-arch caches its build container in GHCR with the job token
lin["permissions"] = {"contents": "read", "packages": "write"}
jobs["build-linux"] = lin

# --- collect into a draft release (drafts are visible only to repo owners) ---
jobs["release"] = {
    "needs": ["build-windows", "build-macos", "build-linux"],
    "runs-on": "ubuntu-22.04",
    "permissions": {"contents": "write"},
    "steps": [
        {"uses": DOWNLOAD, "with": {"pattern": "fox-*", "path": "dist", "merge-multiple": True}},
        {"run": "ls -l dist"},
        {"name": "Draft release", "uses": RELEASE, "with": {
            "draft": True,
            "tag_name": "fox-zdalny-${{ env.VERSION }}-${{ github.run_number }}",
            "name": "Fox Zdalny ${{ env.VERSION }} (build ${{ github.run_number }})",
            "files": "dist/*"}},
        # Fox Pomoc goes to a PUBLIC release with fixed file names, so the download links never change:
        #   https://github.com/<owner>/<repo>/releases/download/pomoc/FoxPomoc-Windows.exe
        {"name": "Publish Fox Pomoc download links", "shell": "bash",
         "env": {"GH_TOKEN": "${{ github.token }}", "GH_REPO": "${{ github.repository }}"},
         "run": L(
             "mkdir -p pomoc\n"
             "cp dist/FoxPomoc-*-x86_64.exe pomoc/FoxPomoc-Windows.exe\n"
             "cp dist/FoxPomoc-*-aarch64.dmg pomoc/FoxPomoc-Mac-Apple.dmg\n"
             "cp dist/FoxPomoc-*-x86_64.dmg pomoc/FoxPomoc-Mac-Intel.dmg\n"
             "gh release delete pomoc --cleanup-tag --yes || true\n"
             "gh release create pomoc pomoc/* --target \"$GITHUB_SHA\" --latest=false "
             "--title \"Fox Pomoc\" --notes \"Pobierz, uruchom i podaj ID oraz haslo osobie, ktora Ci pomaga.\"\n")},
    ],
}

env = dict(fb["env"])
for k in ("ANDROID_SIGNING_KEY", "MACOS_P12_BASE64", "SIGN_BASE_URL"):
    env.pop(k, None)
env.update({"TAG_NAME": "fox-zdalny", "UPLOAD_ARTIFACT": "true", "PUBLISH_UPDATE_METADATA": "false",
            "SIGN_BASE_URL": "-2"})
assert str(env["VERSION"]) == TAG, "VERSION in upstream workflow (%s) != tag %s" % (env["VERSION"], TAG)

wf = {
    "name": "Build Fox Zdalny",
    "on": {
        "workflow_dispatch": None,
        "push": {"paths": ["client/**", ".github/workflows/build-fox-zdalny.yml"]},
    },
    "concurrency": {"group": "fox-zdalny-${{ github.ref }}", "cancel-in-progress": True},
    "permissions": {"contents": "read"},
    "env": env,
    "jobs": jobs,
}

buf = io.StringIO()
yaml.dump(wf, buf)
text = buf.getvalue()
text = (text.replace("${{ inputs.upload-artifact }}", "true")
        .replace("inputs.upload-artifact", "true")
        .replace("inputs.publish-update-metadata", "false"))
assert "inputs." not in text, [l for l in text.splitlines() if "inputs." in l]
header = ("# GENERATED by client/gen_workflow.py from rustdesk/rustdesk@%s CI - do not edit by hand.\n"
          "# Needs repo secrets FOX_HOST (server address) and FOX_KEY (server public key).\n" % TAG)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w").write(header + text)
print("wrote", OUT)
