"""手工组装 vsix（不依赖 vsce），可移植版本。

用法:
    python tools/build_vsix.py                 # 打包仓库根为 dist/<name>-<version>.vsix
    python tools/build_vsix.py --out dist      # 指定输出目录
    python tools/build_vsix.py --pack "<语言包目录>"

说明:
    正式发版走 GitHub Actions 的 vsce 流程；这个脚本只用于离线/自检打包。
"""
import argparse
import json
import os
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", default=REPO)
    ap.add_argument("--out", default=os.path.join(REPO, "dist"))
    a = ap.parse_args()

    pack = os.path.abspath(a.pack)
    pkg_path = os.path.join(pack, "package.json")
    if not os.path.exists(pkg_path):
        raise SystemExit(f"{pack} 缺少 package.json")
    pkg = json.load(open(pkg_path, encoding="utf-8"))
    ver, pub, name = pkg["version"], pkg["publisher"], pkg["name"]

    os.makedirs(a.out, exist_ok=True)
    out = os.path.join(a.out, f"{name}-{ver}.vsix")

    manifest = f"""<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="{name}" Version="{ver}" Publisher="{pub}" />
    <DisplayName>{pkg['displayName']}</DisplayName>
    <Description xml:space="preserve">{pkg['description']}</Description>
    <Tags>language-pack,localization,chinese,zh-cn,简体中文</Tags>
    <Categories>Language Packs</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{pkg['engines']['vscode']}" />
      <Property Id="Microsoft.VisualStudio.Code.PreRelease" Value="false" />
    </Properties>
    <Icon>extension/languagepack.png</Icon>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code" />
  </Installation>
  <Dependencies />
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" />
    <Asset Type="Microsoft.VisualStudio.Services.Content.Details" Path="extension/README.md" Addressable="true" />
    <Asset Type="Microsoft.VisualStudio.Services.Icons.Default" Path="extension/languagepack.png" Addressable="true" />
  </Assets>
</PackageManifest>
"""

    content_types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension=".json" ContentType="application/json" />
  <Default Extension=".md" ContentType="text/markdown" />
  <Default Extension=".png" ContentType="image/png" />
  <Default Extension=".vsixmanifest" ContentType="text/xml" />
</Types>
"""

    skip_names = {".gitignore", ".vscodeignore", "install.ps1", "install.cmd"}
    skip_dirs = {".git", ".github", "tools", "dist"}

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("extension.vsixmanifest", manifest)
        z.writestr("[Content_Types].xml", content_types)
        for dp, dn, fn in os.walk(pack):
            dn[:] = [d for d in dn if d not in skip_dirs]
            for f in fn:
                if f in skip_names or f.endswith(".vsix"):
                    continue
                full = os.path.join(dp, f)
                rel = os.path.relpath(full, pack).replace(os.sep, "/")
                z.write(full, "extension/" + rel)

    size = os.path.getsize(out)
    print(f"built: {out} {round(size / 1048576, 2)} MB")
    print("entries:", len(zipfile.ZipFile(out).namelist()))


if __name__ == "__main__":
    main()
