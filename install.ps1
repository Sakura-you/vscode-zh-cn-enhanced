# 中文（简体）本地增强语言包 · 一键安装
# 作用：下载最新 vsix -> 安装扩展 -> 自动登记 languagepacks.json -> 清缓存 -> 可选直接重启 VS Code
# 用法：右键 install.cmd 以管理员以外的普通身份运行即可；或 powershell -ExecutionPolicy Bypass -File install.ps1

param(
    [string]$Repo = "Sakura-you/vscode-zh-cn-enhanced",
    [string]$CodeCli = "",
    [switch]$NoRestart,
    [switch]$KeepOfficialPack
)

$ErrorActionPreference = "Stop"
function Info($m) { Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }

# ---------- 1. 定位 VS Code CLI ----------
function FindCodeCli() {
    if ($CodeCli -and (Test-Path -LiteralPath $CodeCli)) { return (Resolve-Path -LiteralPath $CodeCli).Path }
    $cmd = Get-Command code -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd",
        "E:\app\Microsoft VS Code\bin\code.cmd",
        "D:\app\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    # 兜底：注册表里找安装路径
    foreach ($k in @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")) {
        $items = Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Visual Studio Code*" }
        foreach ($i in $items) {
            if ($i.InstallLocation) {
                $p = Join-Path $i.InstallLocation "bin\code.cmd"
                if (Test-Path -LiteralPath $p) { return $p }
            }
        }
    }
    return $null
}

$code = FindCodeCli
if (-not $code) { Fail "找不到 VS Code 的 code 命令，请手动指定：-CodeCli 'C:\...\bin\code.cmd'" }
Info "VS Code CLI: $code"

# ---------- 2. 取最新 Release 的 vsix ----------
Info "查询最新版本：$Repo"
$rel = $null
try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "vscode-zh-cn-enhanced" } -TimeoutSec 30
} catch {
    Fail "无法访问 GitHub（网络受限时请手动下载 vsix 再安装）：$($_.Exception.Message)"
}
$asset = $rel.assets | Where-Object { $_.name -like "*.vsix" } | Select-Object -First 1
if (-not $asset) { Fail "该 Release 里没有 vsix 资产" }
Info "版本 $($rel.tag_name)，文件 $($asset.name)（$([math]::Round($asset.size/1kb)) KB）"

$tmp = Join-Path $env:TEMP ("langpack-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$vsix = Join-Path $tmp $asset.name
Info "下载中…"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $vsix -UseBasicParsing -TimeoutSec 300
if ((Get-Item $vsix).Length -ne $asset.size) { Fail "下载不完整，请重试" }

# ---------- 3. 安装扩展 ----------
# code.cmd 偶尔会往 stderr 写 crashpad 噪音，改用独立进程 + 文件重定向，避免 ctrl 中断脚本
function Invoke-Code([string[]]$CodeArgs) {
    $o = Join-Path $env:TEMP ("codewrap-" + [guid]::NewGuid().ToString("N").Substring(0, 6) + ".out")
    $q = @()
    foreach ($a in $CodeArgs) { if ($a -match "\s") { $q += "`"$a`"" } else { $q += $a } }
    Start-Process -FilePath $code -ArgumentList $q -NoNewWindow -Wait -RedirectStandardOutput $o -RedirectStandardError "$o.err" | Out-Null
    $txt = ""
    foreach ($f in @($o, "$o.err")) { if (Test-Path -LiteralPath $f) { $txt += (Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue) } }
    Remove-Item -LiteralPath $o, "$o.err" -Force -ErrorAction SilentlyContinue
    return (($txt -split "`r?`n") | Where-Object { $_ -notmatch "crashpad|TransactNamedPipe|DEP0169|trace-deprecation|DeprecationWarning" }) -join "`n"
}

$extRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
$listOut = Invoke-Code @("--list-extensions")

# 官方中文语言包必须让位：两者都声明 zh-cn，核心译文按 id 合并时后写覆盖，
# 留着官方包会把 98.5% 的补译回退成官方的 62%
$official = ($listOut -split "`r?`n") | Where-Object { $_ -match "^ms-ceintl\.vscode-language-pack-zh-hans" }
if ($official -and -not $KeepOfficialPack) {
    Warn "检测到官方中文语言包（$($official[0])）同时存在，会导致译文互相覆盖，正在卸载（不想要可加 -KeepOfficialPack 跳过）"
    foreach ($e in $official) { Invoke-Code @("--uninstall-extension", $e, "--force") | Out-Null }
    Info "已卸载官方 zh-hans 语言包"
}

if (-not (Test-Path -LiteralPath $extRoot)) {
    Warn "未发现 $extRoot，改为让 VS Code 自行决定扩展目录"
}
# 注意：这里不再「先卸载同名包再装」。实测如果 VS Code 正开着，卸载会把旧目录标进
# .obsolete，紧接着的安装目录可能被窗口的清理流程一起删掉（曾出现过装完目录消失、
# languagepacks.json 被重算成空的情况）。--force 安装会自行替换旧版本。
$installOut = Invoke-Code @("--install-extension", $vsix, "--force")
if ($installOut -notmatch "successfully installed") { Fail "安装失败：$installOut" }
Info "扩展安装完成"

# ---------- 4. 找到刚装的扩展目录（找不到就重试一次，防止窗口清理把它删掉）----------
function FindPackDir() {
    foreach ($root in @($extRoot, (Join-Path $env:USERPROFILE ".vscode-insiders\extensions"))) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "xinyi.vscode-language-pack*" -and (Test-Path -LiteralPath (Join-Path $_.FullName "package.json")) } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

$packDir = FindPackDir
if (-not $packDir) {
    Warn "安装后没找到扩展目录（多半是 VS Code 正在运行的清理流程介入），重试一次…"
    Start-Sleep -Seconds 2
    $installOut = Invoke-Code @("--install-extension", $vsix, "--force")
    Start-Sleep -Seconds 2
    $packDir = FindPackDir
}
if (-not $packDir) {
    Fail "两次安装后仍找不到扩展目录。请关闭全部 VS Code 窗口后重新运行本脚本"
}
Info "语言包目录：$packDir"

# ---------- 5. 自动登记 languagepacks.json ----------
$pkgPath = Join-Path $packDir "package.json"
$pkg = Get-Content -LiteralPath $pkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$loc = $pkg.contributes.localizations[0]
$mainRel = $loc.translations[0].path

$mainPath = Join-Path $packDir ($mainRel -replace "/", "\")
if (-not (Test-Path -LiteralPath $mainPath)) { Fail "译文文件缺失：$mainPath" }

# hash 算法与 VS Code 一致：md5( 每个扩展的 identifier(id 或 uuid) + version )
$extId = "$($pkg.publisher).$($pkg.name)"
$md5 = [System.Security.Cryptography.MD5]::Create()
$bytes = [System.Text.Encoding]::UTF8.GetBytes($extId + $pkg.version)
$hash = ([BitConverter]::ToString($md5.ComputeHash($bytes)) -replace "-", "").ToLower()

$entry = [ordered]@{
    hash         = $hash
    extensions   = @([ordered]@{
            extensionIdentifier = [ordered]@{ id = "$($pkg.publisher).$($pkg.name)" }
            version             = $pkg.version
        })
    translations = @($loc.translations | ForEach-Object {
            [ordered]@{ id = $_.id; path = (Join-Path $packDir ($_.path -replace "/", "\")) }
        })
    label        = $loc.localizedLanguageName
}

$regPath = Join-Path $env:APPDATA "Code\languagepacks.json"
if (-not (Test-Path -LiteralPath (Split-Path $regPath))) { Fail "找不到 VS Code 用户数据目录（%APPDATA%\Code）" }

# 保留用户已有的其它语言，只覆盖 zh-cn
$reg = @{}
if (Test-Path -LiteralPath $regPath) {
    try {
        $raw = Get-Content -LiteralPath $regPath -Raw -Encoding UTF8
        if ($raw.Trim()) {
            $obj = $raw | ConvertFrom-Json
            foreach ($p in $obj.PSObject.Properties) { $reg[$p.Name] = $p.Value }
        }
        Copy-Item -LiteralPath $regPath -Destination "$regPath.bak" -Force
    } catch { Warn "原 languagepacks.json 解析失败，已忽略并重建" }
}
$reg["zh-cn"] = $entry
$json = $reg | ConvertTo-Json -Depth 10
# 无 BOM 写入：VS Code 对带 BOM 的 json 解析不稳
[System.IO.File]::WriteAllText($regPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Info "已登记语言包（zh-cn -> $($pkg.version)，$($entry.translations.Count) 条译文）"

# 校验路径
$miss = $entry.translations | Where-Object { -not (Test-Path -LiteralPath $_.path) }
if ($miss.Count -gt 0) { Warn "$($miss.Count) 条译文路径缺失，可能影响部分扩展文案" } else { Info "译文路径校验通过" }

# ---------- 5.5 确保显示语言指向 zh-cn ----------
# languagepacks.json 只完成「注册」，界面语言还取决于 argv.json 的 locale（英文系统上缺它就会保持英文）
$argvPath = Join-Path $env:APPDATA "Code\argv.json"
if (-not (Test-Path -LiteralPath $argvPath)) {
    [System.IO.File]::WriteAllText($argvPath, "{`n`t// 由 install.ps1 生成：切换界面语言为简体中文`n`t`"locale`": `"zh-cn`"`n}", (New-Object System.Text.UTF8Encoding($false)))
    Info "已创建 argv.json 并设置 locale = zh-cn"
} else {
    $argvRaw = Get-Content -LiteralPath $argvPath -Raw -Encoding UTF8
    if ($argvRaw -match '"locale"\s*:\s*"([^"]*)"') {
        $cur = $Matches[1]
        if ($cur -ne "zh-cn") {
            Copy-Item -LiteralPath $argvPath -Destination "$argvPath.bak" -Force
            $argvRaw = $argvRaw -replace '"locale"\s*:\s*"[^"]*"', '"locale": "zh-cn"'
            [System.IO.File]::WriteAllText($argvPath, $argvRaw, (New-Object System.Text.UTF8Encoding($false)))
            Info "argv.json 的 locale 已从 $cur 改为 zh-cn"
        } else { Info "argv.json 的 locale 已是 zh-cn" }
    } else {
        Copy-Item -LiteralPath $argvPath -Destination "$argvPath.bak" -Force
        $argvRaw = $argvRaw -replace '(?s)^(\s*\{)', "`$1`n`t`"locale`": `"zh-cn`","
        [System.IO.File]::WriteAllText($argvPath, $argvRaw, (New-Object System.Text.UTF8Encoding($false)))
        Info "argv.json 已补充 locale = zh-cn"
    }
}

# ---------- 6. 清翻译缓存 ----------
$clp = Join-Path $env:APPDATA "Code\clp"
if (Test-Path -LiteralPath $clp) {
    Get-ChildItem -LiteralPath $clp -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Info "已清理翻译缓存"
}

# ---------- 7. 重启 ----------
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
if ($NoRestart) {
    Info "完成。请重新加载 VS Code 窗口：Ctrl+Shift+P -> 开发人员: 重新加载窗口"
    exit 0
}
$running = Get-Process -Name "Code" -ErrorAction SilentlyContinue
if ($running) {
    Warn "检测到 VS Code 正在运行，需要重启才能生效。"
    $ans = Read-Host "现在自动重启 VS Code？(Y/n)"
    if ($ans -ne "n" -and $ans -ne "N") {
        $exe = Join-Path (Split-Path (Split-Path $code)) "Code.exe"
        if (Test-Path -LiteralPath $exe) {
            $running | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process -FilePath $exe
            Info "已重启，界面应为中文"
        } else { Warn "找不到 Code.exe，请手动重启" }
    }
} else {
    Info "完成。下次启动 VS Code 即为中文界面"
}
