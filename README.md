简体中文 | [English](README.en.md)

# claude-cleanup (`Claude 账号残余 ID 清理工具 / Claude Residual ID Cleaner`)

**claude-cleanup**（桌面应用：**Claude 账号残余 ID 清理工具 / Claude Residual ID Cleaner**）是一套面向 Windows 用户的非破坏性独立桌面软件（`Claude-Residual-ID-Cleaner.exe`）与原生 PowerShell 清理工具集，专为扫描并安全清理 Claude 封号后残留在本地设备中的账号/设备 ID、认证 Token 与会话缓存而设计，**绝不改动 Windows 操作系统本身**。

---

## 1. 核心定位与安全边界

- **精准解决痛点**：针对 Claude 账号被封禁后在 Windows 本机遗留的多处配置、本地缓存、认证凭据、客户端扩展状态、快捷方式及环境变量残留，提供集中审计、可视化勾选、预览规划与安全核验能力。
- **默认 100% 只读体检**：启动桌面端、控制台启动器或执行默认审计（`-Audit`）均**不修改任何磁盘文件或注册表项**。
- **严格不改动 Windows 系统**：绝不触碰 `C:\Windows`、Program Files、Windows 注册表系统分支、系统硬件/设备 ID（MachineGuid）、WSL 发行版、浏览器个人配置文件（Edge/Chrome Profiles）或其他与 Claude 无关的软件。
- **单核双入口架构**：核心发现、路径校对、Win32 句柄绑定删除与核验台账逻辑**全部集中**在单一脚本引擎 [ClaudeCleanup.ps1](ClaudeCleanup.ps1) 中；独立 `.exe` 桌面应用、脚本版 GUI、控制台启动器与跨代理 Skill 均只通过参数委派调用该引擎，绝不复制任何破坏性删除代码。
- **无隐式回退、无自动备份/提权**：拒绝使用路径版 `Remove-Item` 或 `RegDeleteKeyW`；不自动提权（UAC）；无自动回收站或回滚机制——每次实际清理（`-Apply`）前必须由用户审阅确定性方案 `CLEANUP-PLAN.md` 的 64 位 SHA-256 哈希并明确确认。

> **状态声明**：当前处于候选发布状态（Stages A–I 已完成并在 Windows PowerShell 5.1 与 PowerShell 7+ 双环境通过自动化测试验证）。所有开发测试均在隔离沙箱 `tests/sandbox/` 内完成，未对真实主机 Claude 数据执行未经授权的清理；本地清理亦**不会**更改远端服务器侧的账号状态。

---

## 2. 功能模块与清理范围

### 2.1 目标扫描与白名单清理范围

| 功能类别 | 扫描与评估范围 | 默认策略 / 状态行为 |
| :--- | :--- | :--- |
| **Claude Code CLI 配置与账号/设备 ID** | `%USERPROFILE%\.claude`、`%USERPROFILE%\.claude.json`、`%USERPROFILE%\.local\bin\claude.exe`、`%USERPROFILE%\.local\share\claude`、npm 全局包（`@anthropic-ai/claude-code`） | `AccountData` 仅清理明确缓存/日志并保留自建技能与配置；`FullRemoval` 在全树所有权与链接校验通过后移除用户级残留（`buddy-tokens.json` 默认标为 `ReviewOnly`） |
| **Claude Desktop 客户端数据与 MSIX 包** | `%APPDATA%\Claude`、`%LOCALAPPDATA%\Claude`、MSIX 包 `Claude_pzs8sxrjxfjjc`（`Remove-AppxPackage` 仅限 `FullRemoval`） | `AccountData` 清除应用缓存与诊断日志并保留 `Local Storage` / `IndexedDB`；MSIX 外部 junction 数据目录标为 `Blocked` 或 `ReviewOnly` |
| **IDE 扩展与浏览器宿主注册项** | VS Code / Cursor / Windsurf 扩展 `anthropic.claude-code` 及其 `globalStorage` / `workspaceStorage` 残余；`HKCU` 下 Chrome/Edge Native Messaging Host（仅限 `com.anthropic.claude_browser_extension`） | 仅在 `FullRemoval` 且安全检验通过时处理；非当前用户所有者或含子键项自动拦截为 `Blocked` |
| **Windows 凭据管理器（Credential Manager）** | 检索与 Claude / Anthropic 相关的 Windows 凭据目标数量 | **严格只读审计**：仅统计匹配数量，**绝不读取或删除秘密值** |
| **用户环境变量与 PATH** | 检查 `ANTHROPIC_*` / `CLAUDE_*` 环境变量及用户 `PATH` 中的 `.local\bin` 残留 | **仅枚举变量名称**：绝不读取或打印 API Key 等变量值 |
| **快捷方式、ACL 与 WSL 只读报告** | 开始菜单/桌面/启动项 `.lnk` 快捷方式、文件所有者（`OwnerSid`）、重解析点（Junction/Symlink）及 WSL 发行版状态 | 所有权不符（如 `BUILTIN\Administrators`）标为 `Blocked`；WSL 内部仅只读报告，绝不写入 |

### 2.2 `AccountData` 与 `FullRemoval` 策略对比

| 对比维度 | `AccountData`（保留用户配置） | `FullRemoval`（彻底移除用户级 Claude 残留） |
| :--- | :--- | :--- |
| **适用场景** | 清除已确认的账号缓存、凭据缓存文件与诊断日志，保留个人脚本与对话目录 | 彻底清理用户目录下所有可确认的 Claude CLI、Desktop、扩展与浏览器宿主注册项 |
| **用户创建内容与历史** | 保留 `.claude` 技能/会话、`.claude.json` 及 Desktop `Local Storage` / `IndexedDB` | 经审计标为 `Ready` 的项目将被安全移除（`Claude-3p`、`pivot.claude.ai`、`.obsolete` 保持保护） |
| **受阻父目录安全回退** | 不适用 | 当父目录被标为 `Blocked` / `ReviewOnly` 时，自动拆分并仅列出互不重叠的 `Ready` 子项 |

### 2.3 三态分类与可执行判定

- **存在性三态**：`Present`（确认存在）、`Absent`（确认不存在）、`Unknown`（访问被拒/I/O 错误/权限受限，**绝不**误判为已清除）。
- **决策分级**：仅当目标路径通过白名单、非受保护路径、无重解析点且当前用户拥有全树所有权时，才会标记为 `Ready`；否则保持 `ReviewOnly` 或 `Blocked`。

---

## 3. 独立桌面软件（`.exe`）与命令行使用方式

### 3.1 环境要求

- **操作系统**：Windows 10（64 位，Build 19041+）或 Windows 11（64 位，Build 22000+），使用本地 NTFS 卷。
- **PowerShell**：原生兼容 **Windows PowerShell 5.1**（`powershell.exe`，系统内置）与 **PowerShell 7+**（`pwsh.exe`）。
- **独立运行**：零第三方 PowerShell 模块、零外部二进制依赖，无需 Git 或 REA 运行时依赖。

### 3.2 方式一：独立 Windows 桌面应用（`Claude-Residual-ID-Cleaner.exe`，无控制台黑框）

源码位于 [src/Gui/](src/Gui/)，直接利用 Windows 10/11 内置 `.NET Framework 4.x` 编译器（`csc.exe`）离线生成单文件纯 GUI 可执行程序（`IMAGE_SUBSYSTEM_WINDOWS_GUI`）：

```powershell
# 1. 本地离线编译生成单文件桌面应用
.\scripts\Build-DesktopApp.ps1

# 2. 启动独立桌面软件
.\dist\Claude-Residual-ID-Cleaner.exe
```

桌面界面工作流（严格遵循四步只读优先防误删设计）：
1. **选择扫描范围与策略**：勾选 5 类扫描目标，选择 `AccountData` 或 `FullRemoval`。
2. **`1. 立即扫描体检`**：只读调用 `ClaudeCleanup.ps1 -Audit -OutputFormat Json`，在表格中展示发现的每项路径、状态与决策说明。
3. **`2. 预览清理方案`**：生成确定性 `CLEANUP-PLAN.md` 并计算 64 位 SHA-256 哈希；在生成有效 `Ready` 项前，`3. 一键安全清理` 按钮保持锁定禁用。
4. **`3. 一键安全清理` & `4. 清理结果核验`**：点击清理会先弹出完整目标路径、策略与 SHA-256 最终确认弹窗（不可撤销提示），确认后方可通过 `ClaudeCleanup.ps1 -Apply` 执行，并可点击核验查看 `VERIFICATION.md` 执行台账；内置“打开报告目录”与“导出诊断摘要 (`AUDIT.md`)”。

> 如需免编译直接运行图形界面，也可双击根目录的 [ClaudeCleanupGUI.cmd](ClaudeCleanupGUI.cmd)（基于 [scripts/ClaudeCleanupGUI.ps1](scripts/ClaudeCleanupGUI.ps1) 原生 WinForms 界面）。

### 3.3 方式二：交互式安全控制台启动器

直接运行根目录批处理入口，按数字菜单完成体检、生成方案、切换语言（`[L]`）、拉起桌面 GUI（`[6]`）及查看报告：

```cmd
.\ClaudeCleanupLauncher.cmd
```

启动器强制不启用 `-ExecutionPolicy Bypass`、不请求 UAC 管理员权限，且绝不直接从菜单自动执行真实 `-Apply`。详见 [启动器与安装指南](docs/Launcher-and-Install.md)。

### 3.4 方式三：PowerShell CLI 完整命令与工作流

完整参数定义、返回码与 JSON 契约见 [CLI 命令参考](docs/CLI-Reference.md)。

| 命令示例 | 作用 | 磁盘写入行为 |
| :--- | :--- | :--- |
| `.\ClaudeCleanup.ps1 -Help [-Language Auto\|zh-CN\|en-US]` | 显示帮助说明与安全边界 | 无写入 |
| `.\ClaudeCleanup.ps1 -Audit [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json] [-SaveAuditReport]` | 只读扫描系统环境、ACL/AppData 分类与候选清单 | 默认无写入（仅加 `-SaveAuditReport` 时写入 `AUDIT.md`） |
| `.\ClaudeCleanup.ps1 -Plan [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json]` | 生成包含唯一 GUID (`PlanId`) 与 SHA-256 的 `CLEANUP-PLAN.md` | 仅写入 `CLEANUP-PLAN.md` |
| `.\ClaudeCleanup.ps1 -Plan -WhatIf` | 预览规划目标数量而不写盘 | 无写入 |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64位哈希> -WhatIf` | 干跑校验清单与待清理列表，不消耗授权哈希 | 无写入 |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64位哈希> [-OutputFormat Text\|Json]` | 经 `ConfirmImpact = 'High'` 二次确认后删除 `Ready` 目标 | 删除获批目标并原子更新 `VERIFICATION.md` |
| `.\ClaudeCleanup.ps1 -Verify [-Language Auto\|zh-CN\|en-US] [-OutputFormat Text\|Json]` | 独立核验清单目标当前三态及单次使用台账 | 无写入 |

### 3.5 方式四：用户级安装/升级/卸载与跨代理 Skill

- **用户级生命周期部署**（默认部署至 `%LOCALAPPDATA%\Programs\claude-cleanup`，通过 SHA-256 清单管理，不改动系统 `PATH`、开始菜单或注册表）：
  ```powershell
  powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1
  powershell.exe -NoProfile -File .\scripts\Update-ClaudeCleanup.ps1
  powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1
  ```
- **跨代理 Agent Skill（[skills/claude-cleanup/](skills/claude-cleanup/)）**：支持 Codex CLI（`~/.codex/skills/` / `~/.agents/skills/`）、Antigravity CLI（`~/.gemini/config/skills/`）、Gemini CLI（`~/.gemini/skills/`）与 Claude Code（`~/.claude/skills/`）。详见 [技能规范](skills/claude-cleanup/SKILL.md)、[多代理安装指南](skills/claude-cleanup/references/agent-installation.md) 与 [技能生态系统指南](docs/Agent-Skill-Guide.md)。

---

## 4. 双语实时切换

本仓库全栈实现 **简体中文（`zh-CN`）** 与 **English（`en-US`）** 双语支持：

- **独立 WPF 桌面应用（`Claude-Residual-ID-Cleaner.exe`）与 WinForms GUI**：启动时依据 Windows 系统区域自动默认界面语言（中文 Windows 自动显示简体中文），点击右上角 **`中文 / English`** 按钮即可零重启实时切换全界面文案、表格表头、确认弹窗与安全提示。
- **CLI 与启动器运行时切换**：通过 `-Language Auto|zh-CN|en-US` 参数指定或切换语言；`Auto` 模式根据当前系统 UI 语言自动选择中文或英文，并在 Windows PowerShell 5.1 / 7+ 中自动设置 UTF-8 控制台编码避免中文乱码。
- **报告本地化与 Schema 不变性**：`AUDIT.md`、`CLEANUP-PLAN.md` 与 `VERIFICATION.md` 支持本地化标题与说明文本，同时 `-OutputFormat Json`（`SchemaVersion = 3`）的所有 JSON 字段名在任何语言下保持严格一致，确保自动化脚本与桌面 UI 稳定解析。

---

## 5. 安全机制、测试与开源许可

### 5.1 纵深防御安全机制

完整威胁模型请查阅 [安全策略 (SECURITY.md)](SECURITY.md)：

1. **Win32 句柄绑定文件系统删除**：核心 C# 5 层（`ClaudeCleanup.NativeFs`）使用 `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS` 打开句柄，在同一句柄上核验 `GetFinalPathNameByHandleW`、`GetFileInformationByHandle`（`VolumeSerialNumber` 与 `FileIndex`）及 `GetSecurityInfo`（全树节点均须归属当前用户 `OwnerSid`）后，调用 `SetFileInformationByHandle`（`FileDispositionInfoEx` / `FileDispositionInfo`）执行删除，**绝不回退 `Remove-Item`**。
2. **重解析点与路径保护拦截**：祖先链或目标子树内出现任意 Junction、符号链接（Symlink）或断链立即阻断；盘符根目录、`WINDIR`、`ProgramFiles`、`.codex`、`.agents`、`.gemini`、本仓库自身目录以及精确用户根路径一律禁止触碰。
3. **句柄绑定注册表删除**：针对允许清单内无子键的 HKCU 项，逐级校验祖先非 `REG_LINK` 且 `(Default)` 值匹配后，在未关闭的已核验句柄上调用 `ntdll!NtDeleteKey`。
4. **单次字节缓冲校验与防重放台账**：`CLEANUP-PLAN.md` 单次 `ReadAllBytes` 同时完成 SHA-256 校验与唯一 `SchemaVersion = 3` JSON 块解析；`VERIFICATION.md` 采用临时文件 + `FileStream.Flush($true)` + 原子 `File.Replace`/`Move` 写入，每个清单 SHA-256 哈希仅能生效一次，损坏或截断的台账一律 fail-closed 拒绝。
5. **脱敏样例与零隐私外泄**：脱敏报告示例见 [AUDIT.sample.md](docs/examples/AUDIT.sample.md)、[CLEANUP-PLAN.sample.md](docs/examples/CLEANUP-PLAN.sample.md) 与 [VERIFICATION.sample.md](docs/examples/VERIFICATION.sample.md)；实机产生的报告与日志均被 [.gitignore](.gitignore) 与打包脚本 [New-ReleasePackage.ps1](scripts/New-ReleasePackage.ps1) 严格排除。

### 5.2 自动化测试验证

全部测试仅在隔离目录 `tests/sandbox/` 内构造临时夹具并于结束时清理（从不修改真实 Claude 数据或真实 HKCU 键）。请依次在 **Windows PowerShell 5.1** 与 **PowerShell 7+** 下顺序执行（全套自动化流程见 [.github/workflows/ci.yml](.github/workflows/ci.yml)）：

```powershell
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
powershell.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
powershell.exe -NoProfile -File .\tests\ToolkitInstall.Tests.ps1
powershell.exe -NoProfile -File .\tests\ToolkitCiChecks.Tests.ps1
powershell.exe -NoProfile -File .\tests\BilingualAndGui.Tests.ps1
powershell.exe -NoProfile -File .\tests\DesktopApp.Tests.ps1
```

> 说明：当当前会话不具备创建符号链接权限（`SeCreateSymbolicLinkPrivilege`）或处于受限沙箱时，对应符号链接/Junction 用例会显式标记为 `SKIP`；未单独授权的真实 HKCU 写入、跨 SID 所有权测试与真实 `npm`/`code`/`Remove-AppxPackage` 执行会显式标记为 `NotExecuted`，**绝不**将跳过或未执行项计入通过数。

### 5.3 故障排查、卸载与贡献指南

- **常见排查**：见 [故障排查与兼容性指南](docs/Troubleshooting-and-Compatibility.md)（含执行策略检查、管理员归属目录阻断说明等）。
- **卸载方法**：删除本清理工具本身或 Claude 残留的完整步骤见 [卸载指南](docs/Uninstallation-Guide.md)（删除本工具不会影响 Claude 软件本身）。
- **开发贡献与变更记录**：开发约定见 [CONTRIBUTING.md](CONTRIBUTING.md)，版本历史见 [CHANGELOG.md](CHANGELOG.md)，GUI 架构记录见 [docs/gui-evaluation.md](docs/gui-evaluation.md)。

### 5.4 开源许可与致谢声明

- **开源协议**：本项目基于 [MIT 许可证](LICENSE) 开源。
- **版权与致谢**：见 [NOTICE](NOTICE)。概念启发自面向 macOS 的 Shell 脚本项目 [suyuan2022/claude-cleanup](https://github.com/suyuan2022/suyuan-skill/tree/main/claude-cleanup)；本 Windows 项目为从零编写的独立洁净室（clean-room）实现，有意**未**移植上游自动备份、废纸篓及设备身份轮换功能。本项目与 Anthropic PBC 无任何隶属或授权关系。
