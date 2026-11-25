# 更新记录

## 1.0.0 — 2026-11-25

- 基于官方 ms-ceintl.vscode-language-pack-zh-hans 1.131 全部译文，补齐 VS Code 1.146 智能体界面文案
- 核心文案覆盖率 98.5%（31,627 / 32,108），未译项仅剩占位符、品牌名与技术标记
- 独立 publisher/name（`xinyi.vscode-language-pack-zh-hans`），不受官方语言包更新覆盖
- 保留官方 1.131 的 95 个内置扩展翻译
- 提供 `install.ps1` / `install.cmd` 一键安装：下载最新 Release、安装、登记 `languagepacks.json`（`hash = md5(扩展id + 版本)`）、补 `argv.json` 的 `locale`、清缓存并可选重启
- `engines.vscode` 为 `^1.90.0`；与官方 zh-hans 包冲突时安装器会自动卸载官方包（可 `-KeepOfficialPack` 跳过）
- 推 `v*` 标签由 GitHub Actions 用 vsce 打包并发版，含 tag 与版本一致性校验
