# 中文（简体）本地增强语言包

一个**独立的 VS Code 中文语言包**，用于把 VS Code 1.146 新增的「智能体界面」（会话窗口 / 聊天 / 自动化 / 自定义项 / 画布 / 收件箱 / 工作树清理 / Autopilot / 语音模式）补齐成中文。

微软官方 `ms-ceintl.vscode-language-pack-zh-hans`（1.131）只覆盖了约 62% 的核心文案，1.146 新增的智能体界面几乎全是英文。本项目在官方译文基础上，把剩余部分人工补译，并打包成独立标识（`xinyi.vscode-language-pack-zh-hans`），因此**不会被官方语言包更新覆盖**。

## 安装

### 方式一：一键安装（推荐，自动应用）

到 [Releases](https://github.com/Sakura-you/vscode-zh-cn-enhanced/releases) 下载 **`install.cmd`**，双击运行即可（脚本会自动拉取同版本的 `install.ps1`，只需这一个文件）。脚本会自动完成全部步骤：

1. 找到本机的 VS Code 安装位置
2. 从最新 Release 下载 vsix 并安装
3. **自动登记语言包**（写 `languagepacks.json`），不需要手动去「配置显示语言」
4. 清翻译缓存，并询问是否立刻重启 VS Code

重启后界面即为中文。参数：

```powershell
# dry run（只安装与登记，不重启）
powershell -ExecutionPolicy Bypass -File install.ps1 -NoRestart
# 指定 code 命令位置
powershell -ExecutionPolicy Bypass -File install.ps1 -CodeCli "D:\app\Microsoft VS Code\bin\code.cmd"
```

> 之所以需要脚本补这一步：VS Code 扩展没有「安装后钩子」，语言包装完必须写一次 `languagepacks.json` 再重启才会生效，扩展本身做不到。

### 方式二：VSIX 手动安装（会弹窗提示，点一下即可）

1. 到 [Releases](https://github.com/Sakura-you/vscode-zh-cn-enhanced/releases) 下载 `vscode-zh-cn-enhanced-v1.0.0.vsix`
2. VS Code 扩展面板右上角 `...` → **从 VSIX 安装**
3. 右下角会提示「是否将显示语言更改为 中文(简体) 并重启？」，点 **更改语言并重启** 即可

第 3 步是 VS Code 自带逻辑：只要扩展声明了 `contributes.localizations`，且语言与当前界面不同，安装事件由窗口内的扩展面板触发时就会弹出该提示，点击后自动写入 `argv.json` 的 `locale` 并重启。

> 如果没弹提示（扩展被判定为「已安装同版本」），先在面板里卸载、重启窗口，再重新走第 2 步。

### 方式三：命令行（不弹窗，需要手动切语言）

下载 vsix 后执行：

```powershell
code --install-extension vscode-zh-cn-enhanced-v1.0.0.vsix --force
```

> 注意：`code --install-extension` 直接接 Release 的 URL 在部分版本会解析失败，请先下载再安装。

用命令行安装时，窗口收不到「安装完成」事件，所以不会弹切换语言的提示，需要手动 `Ctrl+Shift+P` → `配置显示语言` → 选「中文(简体)」→ 重启。

## 工作原理

- VS Code 启动时由 shared process 扫描所有已安装扩展的 `package.json`，把含 `contributes.localizations` 的扩展自动写进 `%APPDATA%\Code\languagepacks.json`，其中 `hash = md5(扩展id + 版本)`、`translations` 指向各扩展目录内的 `.i18n.json`
- 界面语言由 `argv.json` 的 `locale` 决定，两者配合才会生效；改完必须重启
- 因此本语言包装上后不需要额外配置「扩展设置」，只是需要一次重启

## 说明

- `engines` 声明为 `^1.90.0`：在 1.90 以上都能装（缺少的键会回退英文，不会出错）；1.146 新增的智能体界面文案要有 1.146 的界面才看得到
- 保留官方 1.131 的全部译文（含 95 个内置扩展翻译），共 3.4 万条核心文案
- `Agent`、`Copilot Fusion`、`Claude`、`Codex` 等**产品名与智能体名**按惯例保留英文，不做翻译
- **与官方中文语言包同时安装会互相覆盖**（两者都声明 `zh-cn`，核心译文按 id 合并、后写者生效）。`install.ps1` 会自动卸载官方包；要保留官方包可加 `-KeepOfficialPack`，但此时不保证补译还能生效

## 自己构建

需要本机已安装一份官方 `ms-ceintl.vscode-language-pack-zh-hans` 作为译文基础。

```powershell
python tools/build_pack.py                       # 自动查找官方包，按现有 package.json 重建 translations/
python tools/build_pack.py --src "D:\pack\ms-ceintl...1.131" --version 1.0.3
python tools/build_vsix.py                       # 离线打包到 dist/
```

正式发版不需要手工打包：推 `v*` 标签，Actions 会用 vsce 打包并附到 Release，且会校验 tag 与 `package.json` 版本一致。

## 许可

本项目基于 Microsoft [vscode-loc](https://github.com/microsoft/vscode-loc) 的简体中文译文（MIT），新增译文同样以 MIT 发布，详见 [LICENSE](LICENSE)。

VS Code、GitHub Copilot 及相关商标归其各自所有者。
