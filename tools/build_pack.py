"""从微软官方中文语言包派生本仓库的扩展目录（可移植版本）。

用法:
    python tools/build_pack.py                  # 自动查找已安装的官方 zh-hans 语言包，输出到仓库根
    python tools/build_pack.py --src "D:\\packs\\ms-ceintl.vscode-language-pack-zh-hans-1.131" --out .
    python tools/build_pack.py --version 1.0.3

行为:
    - 只复制 translations/ 与 languagepack.png
    - package.json 以本仓库现有的为准（publisher/name/displayName/version/engines 都保留），
      只把 contributes.localizations 的条目按实际复制的文件重建，避免版本号/显示名被脚本覆盖
"""
import argparse
import glob
import json
import os
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def find_official_pack():
    cands = []
    home = os.path.expanduser("~")
    patterns = [
        os.path.join(home, ".vscode", "extensions", "ms-ceintl.vscode-language-pack-zh-hans*"),
        os.path.join(home, ".vscode-insiders", "extensions", "ms-ceintl.vscode-language-pack-zh-hans*"),
    ]
    for p in patterns:
        cands += [d for d in glob.glob(p) if os.path.isdir(d)]
    return sorted(cands, key=os.path.getmtime)[-1] if cands else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.environ.get("VSCODE_ZH_PACK"))
    ap.add_argument("--out", default=REPO)
    ap.add_argument("--version")
    a = ap.parse_args()

    src = a.src or find_official_pack()
    if not src or not os.path.isdir(src):
        sys.exit("找不到官方中文语言包目录，请用 --src 指定（内含 translations/main.i18n.json）")
    main_src = os.path.join(src, "translations", "main.i18n.json")
    if not os.path.exists(main_src):
        sys.exit(f"{src} 不是有效的语言包目录：缺少 translations/main.i18n.json")

    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)

    # 以仓库现有 package.json 为模板
    pkg_path = os.path.join(out, "package.json")
    if os.path.exists(pkg_path):
        pkg = json.load(open(pkg_path, encoding="utf-8"))
    else:
        pkg = json.load(open(os.path.join(src, "package.json"), encoding="utf-8"))
        pkg.update({"publisher": "xinyi", "name": "vscode-language-pack-zh-hans",
                    "displayName": "Chinese (Simplified) 本地增强"})
        pkg.pop("repository", None)
        pkg.pop("license", None)
    pkg.pop("scripts", None)
    pkg.pop("__metadata", None)
    if a.version:
        pkg["version"] = a.version

    # 复制译文
    dst_tr = os.path.join(out, "translations")
    if os.path.isdir(dst_tr):
        shutil.rmtree(dst_tr)
    os.makedirs(os.path.join(dst_tr, "extensions"))
    shutil.copyfile(main_src, os.path.join(dst_tr, "main.i18n.json"))

    copied = []
    ext_src = os.path.join(src, "translations", "extensions")
    if os.path.isdir(ext_src):
        for f in sorted(os.listdir(ext_src)):
            if f.endswith(".i18n.json"):
                shutil.copyfile(os.path.join(ext_src, f), os.path.join(dst_tr, "extensions", f))
                copied.append(f[: -len(".i18n.json")])

    png_src = os.path.join(src, "languagepack.png")
    if os.path.exists(png_src):
        shutil.copyfile(png_src, os.path.join(out, "languagepack.png"))
        pkg["icon"] = "languagepack.png"
    else:
        pkg.pop("icon", None)

    # 按实际文件重建 localizations
    loc = pkg.setdefault("contributes", {}).setdefault("localizations", [{}])[0]
    loc["languageId"] = "zh-cn"
    loc["languageName"] = "Chinese Simplified"
    loc["localizedLanguageName"] = "中文(简体)"
    loc["translations"] = [{"id": "vscode", "path": "./translations/main.i18n.json"}]
    for name in copied:
        loc["translations"].append({"id": name, "path": f"./translations/extensions/{name}.i18n.json"})

    json.dump(pkg, open(pkg_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

    # 校验
    bad = []
    for t in loc["translations"]:
        p = os.path.join(out, t["path"].replace("./", ""))
        if not os.path.exists(p):
            bad.append(t["path"])
            continue
        try:
            json.load(open(p, encoding="utf-8"))
        except Exception as e:
            bad.append(f"{t['path']} {e}")
    core = json.load(open(os.path.join(dst_tr, "main.i18n.json"), encoding="utf-8"))

    print(f"src: {src}")
    print(f"out: {out}")
    print(f"version: {pkg['version']} | translations: {len(loc['translations'])} | 扩展译文: {len(copied)}")
    print(f"core entries: {sum(len(v) for v in core['contents'].values())}")
    print(f"bad: {bad}")
    size = sum(os.path.getsize(os.path.join(dp, f)) for dp, dn, fn in os.walk(out) for f in fn)
    print(f"size: {round(size / 1048576, 2)} MB")
    if bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
