[English](README.md) | **简体中文**

# Windows Claude Cleanup Toolkit

用于 Windows 平台的 Claude Code 与 Claude Desktop 本地数据**只读审计**、**哈希绑定规划**及**用户明确授权清理**的原生 PowerShell 工具。

---

## 1. 项目简介

本工具用于排查并清理当前 Windows 用户下与 Claude Code 及 Claude Desktop 相关的本地安装、配置、缓存、诊断日志、VS Code 扩展、MSIX 包及浏览器 Native Messaging 注册项。工具将只读审计（`-Audit`）、清单规划（`-Plan`）、预览/确认执行（`-Apply`）与独立核验（`-Verify`）严格分离，不会修改设备标识、代理、遥测、浏览器站点数据或 WSL 发行版。

所有清理与核验操作均通过经过严格测试的原生 PowerShell 核心引擎（[ClaudeCleanup.ps1](ClaudeCleanup.ps1)）执行。工具支持直接使用 CLI 命令行、交互式控制台菜单启动器（[ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd)）或跨代理 Skill（[skills/claude-cleanup/SKILL.md](skills/claude-cleanup/SKILL.md)）调用。

## 2. 当前发布状态

- **开发阶段**：候选发布阶段（Release Candidate，A 至 F 阶段功能已完整实现，并在 Windows PowerShell 5.1 与 PowerShell 7+ 双环境完成验证）。
- **真实清理状态**：开发与测试期间**未授权、也未执行**任何真实 Claude 数据删除。所有实际删除操作均需要用户对清单 SHA-256 哈希与策略进行明确确认。
- **仓库状态**：当前为私有开发仓库（`main` 分支）。

## 3. 功能特性与限制

### 已实现能力
- **只读环境与候选审计（`-Audit`）**：覆盖原生及 npm 全局安装版 Claude Code CLI（通过 `npm`、`.npmrc`、`NPM_CONFIG_PREFIX`、`%APPDATA%\npm` 解析前缀）、Claude Desktop、VS Code / Cursor / Windsurf Claude 扩展、MSIX 包、开始菜单/桌面/启动项 `.lnk` 快捷方式、相关服务/定时任务、环境变量**仅名称**（仅输出 `Scope` 与 `Name`，绝不读取秘密值）、`PATH` 残留项、Credential Manager 目标计数（不读取秘密值）、AppData 角色分类、路径 ACL/所有者/重解析点诊断以及 WSL 只读状态报告。
- **结构化 JSON 输出（`-OutputFormat Json`）**：在 `-Audit`、`-Plan`、`-Verify` 与 `-Apply` 模式下均支持机器可读 JSON 输出（`SchemaVersion = 3`），便于流水线自动化与智能体 Skill 集成。
- **确定性清单生成（`-Plan`）**：输出 `CLEANUP-PLAN.md`，标注 `Ready` / `ReviewOnly` / `Blocked` 决策，并记录 NTFS `VolumeSerialNumber`、`FileIndex` 及子树最大修改时间戳 `MaxLastWriteUtcTicks`。
- **Win32 句柄绑定文件删除**：文件系统目标使用 `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS` 打开句柄，强制核验子树各级当前用户 `OwnerSid`，严格拒绝重解析点（junction/符号链接），通过 `SetFileInformationByHandle` 执行底层删除，**绝不回退到路径版 `Remove-Item`**。
- **受控包卸载器（仅 `FullRemoval`）**：严格限定作用域执行 `npm uninstall -g @anthropic-ai/claude-code`、`code --uninstall-extension anthropic.claude-code` 与 MSIX `Remove-AppxPackage`，并在卸载后执行 fail-closed 存在性核验。
- **跨代理 Skill（`skills/claude-cleanup/`）**：提供规范智能体技能包（[SKILL.md](skills/claude-cleanup/SKILL.md)），兼容 Codex CLI、Antigravity CLI、Gemini CLI 与 Claude Code，强制只读 `-Audit` 默认行为、严格 SHA-256 授权卡点、零重复删除逻辑，并将 REA 严格限定为开发期可选静态分析工具。
- **安全控制台菜单启动器**：提供批处理包装器（[ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd)）与文本菜单脚本（[scripts/ClaudeCleanupLauncher.ps1](scripts/ClaudeCleanupLauncher.ps1)），支持 Audit、Plan、查看本地报告、Verify 与 Help 功能，无 `-ExecutionPolicy Bypass`、无自动 UAC 提权、绝不自动执行 `-Apply`。
- **用户级生命周期管理**：提供专用安装（[scripts/Install-ClaudeCleanup.ps1](scripts/Install-ClaudeCleanup.ps1)）、更新（[scripts/Update-ClaudeCleanup.ps1](scripts/Update-ClaudeCleanup.ps1)）与卸载（[scripts/Uninstall-ClaudeCleanup.ps1](scripts/Uninstall-ClaudeCleanup.ps1)）脚本，严格区分清理工具本身、智能体技能以及 Claude 软件的存在性。
- **发布打包与 CI 矩阵**：提供发布打包脚本（[scripts/New-ReleasePackage.ps1](scripts/New-ReleasePackage.ps1)）与 GitHub Actions 工作流（[.github/workflows/ci.yml](.github/workflows/ci.yml)），在 `windows-latest` 上全自动化测试 Windows PowerShell 5.1 与 PowerShell 7。
- **完备文档体系**：覆盖 [CLI 命令参考](docs/CLI-Reference.md)、[启动器与安装指南](docs/Launcher-and-Install.md)、[智能体技能指南](docs/Agent-Skill-Guide.md)、[卸载指南](docs/Uninstallation-Guide.md)、[故障排查与兼容性](docs/Troubleshooting-and-Compatibility.md)、[样例报告](docs/examples/)、[安全策略](SECURITY.md)、[贡献指南](CONTRIBUTING.md)、[更新日志](CHANGELOG.md)、[开源许可证](LICENSE) 以及 [项目声明](NOTICE)。

### 规划中能力（尚未实现）
- **可选图形界面（GUI）**：已在 [docs/gui-evaluation.md](docs/gui-evaluation.md) 完成可行性评估；为保持极简依赖，GUI 实现延后至后续里程碑（Stage E+）。
- **真实主机环境清理验证（Stage G）**：需用户针对真实数据环境进行独立明确授权。

## 4. 支持的 Windows 版本

- Windows 10（64 位，Build 19041+）
- Windows 11（64 位，Build 22000+）
- 主要面向本地 NTFS 卷（当文件系统不支持所需句柄标识原语时按 fail-closed 拦截）。

## 5. PowerShell 兼容性

- **Windows PowerShell 5.1**（`powershell.exe`，Windows 10/11 内置默认环境）
- **PowerShell 7+**（`pwsh.exe`，跨平台 PowerShell Core）
- 内嵌 C# 5 P/Invoke 层（`ClaudeCleanup.NativeFs`）可在 .NET Framework 4.8 与现代 .NET 下直接编译加载。

## 6. 安装说明

支持便携式使用或用户级标准安装（详见 [启动器与安装指南](docs/Launcher-and-Install.md)）：

### 选项 A：便携式使用（默认）
1. 将本仓库克隆或下载到本地用户目录（例如 `C:\Users\<USERNAME>\Tools\Windows-Claude-Cleanup`）。
2. 运行前先审阅 [ClaudeCleanup.ps1](ClaudeCleanup.ps1) 与 [SECURITY.md](SECURITY.md) 源码。
3. 本工具独立运行，**无需**安装第三方 PowerShell 模块、AI 代理、Git 或 REA 运行时依赖。

### 选项 B：用户级标准安装
运行安装脚本将工具部署至 `%LOCALAPPDATA%\Programs\Windows-Claude-Cleanup`：
```powershell
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1
```
如需同时安装指定 AI 代理的技能包：
```powershell
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -InstallSkill -SkillTarget Codex
```

## 7. 快速开始

### 使用安全控制台启动器（推荐非技术用户）
在命令提示符或 PowerShell 中直接运行：
```cmd
.\ClaudeCleanupLauncher.cmd
```
通过数字菜单即可执行只读审计、生成清理计划、查看本地报告及校验系统状态，无需输入任何复杂参数。

### 直接使用 PowerShell CLI
在本项目根目录的 PowerShell 中运行：
```powershell
.\ClaudeCleanup.ps1 -Help
.\ClaudeCleanup.ps1 -Audit
.\ClaudeCleanup.ps1 -Plan
```
在审阅审计结果以及 `CLEANUP-PLAN.md` 中的每条路径与 SHA-256 哈希之前，不要进行任何执行操作。

## 8. CLI 命令参考

完整参数说明与 JSON 架构规范请参见 [CLI 命令参考](docs/CLI-Reference.md)。

| 命令 | 用途 | 磁盘写入行为 |
| :--- | :--- | :--- |
| `.\ClaudeCleanup.ps1 -Help` | 显示用法与安全边界说明 | 无写入 |
| `.\ClaudeCleanup.ps1 -Audit [-OutputFormat Text\|Json]` | 只读检查系统环境、ACL/AppData 诊断与候选清单 | 无写入 |
| `.\ClaudeCleanup.ps1 -Plan [-OutputFormat Text\|Json]` | 生成 `CLEANUP-PLAN.md`（`SchemaVersion = 3`） | 仅写入 `CLEANUP-PLAN.md` |
| `.\ClaudeCleanup.ps1 -Plan -WhatIf` | 预览规划条目数但不落盘 | 无写入 |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64位哈希> [-OutputFormat Text\|Json] -WhatIf` | 干跑预览获批策略下的执行目标 | 无写入、不消耗哈希 |
| `.\ClaudeCleanup.ps1 -Apply -Policy <Policy> -ApprovedManifestSha256 <64位哈希> [-OutputFormat Text\|Json]` | 经交互确认后执行 `Ready` 目标 | 删除获批目标并更新 `VERIFICATION.md` 台账 |
| `.\ClaudeCleanup.ps1 -Verify [-OutputFormat Text\|Json]` | 只读核验当前状态、清单与执行台账 | 无写入 |

## 9. Audit / Plan / Apply / Verify 工作流

1. **审计（`-Audit`）**：只读收集系统状态与候选决策，不做任何修改。
2. **规划（`-Plan`）**：安全测量各候选并写入包含唯一 `PlanId`（GUID）与 SHA-256 的 `CLEANUP-PLAN.md`。每次重新运行 `-Plan` 都会使旧哈希失效。
3. **预览（`-Apply ... -WhatIf`）**：校验 SHA-256 与目标元数据并输出预览，不删除任何文件，也不会消耗授权哈希。
4. **执行（`-Apply`）**：必须明确指定**单一策略**与 `CLEANUP-PLAN.md` 的**精确 64 位 SHA-256**，并通过 PowerShell `ConfirmImpact = 'High'` 确认。同一清单哈希在真实 `-Apply` 中**最多仅可使用一次**。
5. **核验（`-Verify`）**：独立检验清单目标处于 `Present`、`Absent` 还是 `Unknown` 状态，并展示执行台账记录。

## 10. AccountData 与 FullRemoval 策略对比

| 对比维度 | `AccountData` | `FullRemoval` |
| :--- | :--- | :--- |
| **清理范围** | 可确认的 Claude 凭据文件、账户缓存、应用缓存与诊断日志 | 已确认的用户级 Claude Code 安装、配置、Desktop 数据、VS Code 扩展、MSIX 包与浏览器宿主注册项 |
| **用户创建内容与历史** | 保留（`.claude` 技能/会话、`.claude.json`、Desktop `Local Storage` / `IndexedDB` 均保留） | 若安全且为 `Ready`，将删除 `.claude` / `.claude.json` / Desktop Roaming 与 Local（含技能、插件、MCP、会话及 Cowork 数据） |
| **未核实/共享项** | `buddy-tokens.json` 默认标为 `ReviewOnly` | `Claude-3p`、`pivot.claude.ai`、`.obsolete` 与 MSIX `Packages\Claude_pzs8sxrjxfjjc` 保持 `ReviewOnly` 或 `Blocked` |
| **父目录受阻回退** | 不适用 | 当父目录（如 `.claude`、`%APPDATA%\Claude`）处于 `Blocked` 或 `ReviewOnly` 时，会安全列出无重叠的 `Ready` 子项 |

> **重要提示**：由于 Desktop 混合存储（`Local Storage`、`IndexedDB`）在 `AccountData` 下保留，该策略未必能清除全部本地登录状态；且本地清理**绝不会**改变远端服务器端账号状态。

## 11. 安全与授权机制

完整威胁模型与安全不变式请参见 [SECURITY.md](SECURITY.md)。

- **Win32 句柄绑定删除**：文件系统目标使用 `FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS` 打开句柄（文件独占 `FILE_SHARE_NONE`，目录省略 `FILE_SHARE_DELETE`），在同一句柄上核验 `GetFinalPathNameByHandleW`、`GetFileInformationByHandle` 与 `GetSecurityInfo`（所有者 SID）后，直接调用 `SetFileInformationByHandle`（`FileDispositionInfoEx` / `FileDispositionInfo`）删除，**绝不回退到路径版 `Remove-Item`**。
- **重解析点与混合所有权拦截**：祖先链或子树内任何 junction、符号链接或断链均阻断执行；目录树内**所有子节点**均强制核验当前用户 `OwnerSid`，含非当前用户所有子项的目录会被标为 `Blocked`。
- **受保护路径**：盘符根目录、`WINDIR`、`ProgramFiles`、`ProgramFiles(x86)`、`.codex`、`.agents`、`.gemini`、本项目目录以及精确用户根路径（`USERPROFILE`、`APPDATA`、`LOCALAPPDATA`、`ProgramData`、`PUBLIC`、`TEMP`、`TMP`）均受保护。
- **注册表删除安全**：仅允许精确的 HKCU Chrome/Edge `com.anthropic.claude_browser_extension` 项；删除前逐级检验祖先非 `REG_LINK`、无子键且 `(Default)` 值一致，并在未关闭的已核验句柄上调用 `ntdll!NtDeleteKey`。
- **单次字节校验与原子台账**：`CLEANUP-PLAN.md` 单次 `ReadAllBytes` 核验 SHA-256 并校验唯一 JSON 块（`SchemaVersion = 3`）；`VERIFICATION.md` 台账采用临时文件 + `Flush($true)` + 原子 `File.Replace`/`Move` 写入，截断或损坏台账一律 fail-closed 拒绝，持久化失败时绝不报告成功。
- **不可逆声明**：无自动备份、无回收站/隔离区、无自动回滚；运行 `-Apply` 前请正常退出 Claude 与 VS Code。

## 12. 数据隐私与纯本地处理边界

- 全部检查与操作均在本地完成，不发起网络请求或遥测上报。
- Credential Manager 仅按目标名称统计数量，不读取秘密值，本版本亦不删除其中的条目。
- 浏览器配置文件、站点数据与 WSL 发行版均不被修改。
- `AUDIT.md`、`CLEANUP-PLAN.md` 与 `VERIFICATION.md` 含本机路径、SID 与哈希，已被 `.gitignore` 严格排除，不会进入 Git 历史。
- 脱敏样例报告可参考 [docs/examples/AUDIT.sample.md](docs/examples/AUDIT.sample.md)、[docs/examples/CLEANUP-PLAN.sample.md](docs/examples/CLEANUP-PLAN.sample.md) 以及 [docs/examples/VERIFICATION.sample.md](docs/examples/VERIFICATION.sample.md)。

## 13. 常见问题排查

完整诊断手册请参考 [故障排查与兼容性指南](docs/Troubleshooting-and-Compatibility.md)。

- **`Unsupported manifest schema version (SchemaVersion 3 required)`**：请重新运行 `.\ClaudeCleanup.ps1 -Plan` 生成最新的 `SchemaVersion = 3` 清单并使用新 SHA-256。
- **`Target is not owned by the current user`（`BUILTIN\Administrators`）**：提权安装或运行期间创建的目录/文件可能归属 Administrators。本版本按保守原则将其标为 `Blocked`，不会擅自修改 ACL 或夺取所有权。
- **受限环境 `-Audit` / `-Verify` 显示大量 `Blocked` 或 `Unknown`**：当系统或沙箱限制访问时，工具会显式标为 `Blocked` 或 `Unknown`（绝不误判为 `Absent` 已删除）。
- **PowerShell 执行策略拦截**：请勿盲目长期关闭安全策略；可先用 `Get-ExecutionPolicy -List` 查看策略，并在审阅源码确认安全后针对下载脚本做解除锁定处理。

## 14. 测试与验证

测试夹具**仅**在 `tests/sandbox/` 内创建并在结束时自动清理（测试绝不操作真实 Claude 数据或真实 HKCU 注册表键）：

```powershell
# 核心清理引擎测试
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1

# 跨代理技能包测试
powershell.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
pwsh.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1

# 启动器与安装生命周期测试
powershell.exe -NoProfile -File .\tests\ToolkitInstall.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ToolkitInstall.Tests.ps1

# CI 检查与发布打包测试
powershell.exe -NoProfile -File .\tests\ToolkitCiChecks.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ToolkitCiChecks.Tests.ps1
```

- **权限与授权说明**：在 Windows 上创建符号链接需要管理员权限或开发者模式（`SeCreateSymbolicLinkPrivilege`），非特权会话会将对应符号链接创建用例明确标为 `SKIP`（不计入通过）；若在禁用 `FSCTL_SET_REPARSE_POINT` 的沙箱内运行，junction 创建也会相应跳过；未经单独授权的真实 HKCU 写入、跨 SID 磁盘测试以及真实 `npm` / `code` / `Remove-AppxPackage` 卸载执行均明确标为 `NotExecuted`。
- 全套测试自动化流程已配置于 [.github/workflows/ci.yml](.github/workflows/ci.yml)。

## 15. 已知问题与不支持的操作

- **MSIX 数据 Junction**：`%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc` 中含指向外部卷（例如 `<Drive>:\WpSystem`）的 junction，绝不能直接递归删除；获批的 MSIX 卸载交由 `Remove-AppxPackage` 完成，其可能连带清理包数据与 `CoworkVMService`。
- **Win32 打开句柄前窗口与硬链接**：在 `CreateFileW` 打开顶层根或子句柄前的极短瞬间仍存在用户态路径查找窗口；`SetFileInformationByHandle` 仅解除当前目录项链接，不会移除未知位置的外部 NTFS 硬链接。
- **非文件系统 OS 接口**：`AppxPackage` 卸载受 Windows 应用部署服务托管。
- **WSL 隔离**：WSL 发行版及其内部 `~/.claude` 数据在运行时仅做只读报告，绝不自动修改。
- **明确不支持**：设备标识伪造、反滥用机制绕过、Credential Manager 秘密删除及自动更改 ACL/所有权。

## 16. 跨代理 Skill 集成

规范的 `claude-cleanup` 技能包位于 [skills/claude-cleanup/](skills/claude-cleanup/)：
- **技能规范**：[SKILL.md](skills/claude-cleanup/SKILL.md)
- **权限与风险边界**：[references/permissions-and-risks.md](skills/claude-cleanup/references/permissions-and-risks.md)
- **多代理安装指南**：[references/agent-installation.md](skills/claude-cleanup/references/agent-installation.md)
- **架构与生态指南**：[docs/Agent-Skill-Guide.md](docs/Agent-Skill-Guide.md)

支持的代理平台包括 Codex CLI（`~/.codex/skills/` 或共享 `~/.agents/skills/`）、Antigravity CLI（`~/.gemini/config/skills/`）、Gemini CLI（`~/.gemini/skills/`）与 Claude Code（`~/.claude/skills/`）。该技能仅调用经过验证的 `ClaudeCleanup.ps1` 后端，默认只读审计，严禁自动触发 `-Apply`，且不以 REA 作为运行时依赖。

## 17. Windows 启动器与 GUI 评估

- **控制台菜单启动器**：通过 [ClaudeCleanupLauncher.cmd](ClaudeCleanupLauncher.cmd) 与 [scripts/ClaudeCleanupLauncher.ps1](scripts/ClaudeCleanupLauncher.ps1) 提供面向普通用户的交互式文本菜单（详见 [启动器与安装指南](docs/Launcher-and-Install.md)）。
- **GUI 薄包装可行性评估**：可选 WPF/XAML 界面方案已在 [docs/gui-evaluation.md](docs/gui-evaluation.md) 完成技术评估，为确保轻量与极简依赖，当前阶段暂不引入编译型 GUI 二进制。

## 18. 如何卸载 Claude

本工具在未经您生成清单并明确批准前**不会**自行卸载 Claude。完整卸载方式请参考 [卸载指南](docs/Uninstallation-Guide.md)：
- 当前可审计用户级 `claude.exe`、`.local\share\claude`、Desktop MSIX 及 VS Code 扩展（归属 `BUILTIN\Administrators` 的路径保持 `Blocked`）。
- 对于 MSIX 版 Claude Desktop，您也可通过 Windows **设置 → 应用 → 已安装的应用** 卸载，或在审阅 `FullRemoval` 清单后通过受控流程卸载。
- 删除本清理工具**不会**卸载 Claude 本体。

## 19. 如何卸载本工具与技能

详见 [卸载指南](docs/Uninstallation-Guide.md) 的操作说明：
- **便携式移除**：直接删除本仓库目录即可。
- **已安装工具移除**：运行 `powershell.exe -File .\scripts\Uninstall-ClaudeCleanup.ps1` 清理 `%LOCALAPPDATA%\Programs\Windows-Claude-Cleanup`（默认保留本地报告，如需彻底删除可附加 `-RemoveReports`）。
- **仅移除智能体技能**：运行 `.\scripts\Uninstall-ClaudeCleanup.ps1 -SkillOnly -SkillTarget <Agent>` 即可清理对应代理技能目录，不影响工具本身或 Claude 数据。

## 20. GitHub 开发与贡献流程

开发指南、编码规范与 Pull Request 流程请参见 [CONTRIBUTING.md](CONTRIBUTING.md)。安全漏洞报告方式请参见 [SECURITY.md](SECURITY.md)。版本变更记录维护于 [CHANGELOG.md](CHANGELOG.md)。
- 在 `main` 分支按严格分阶段授权推进：检查 `git status` -> 最小范围修改 -> Windows PowerShell 5.1 与 PowerShell 7 回归验证 -> `git diff` 隐私审计 -> Conventional Commit。
- 严禁将 `AUDIT.md`、`CLEANUP-PLAN.md`、`VERIFICATION.md`、`tests/sandbox/`、`dist/`、凭据、SID 或本地运行日志提交到版本库。

## 21. 许可证与致谢状态

- **开源许可证**：采用 [MIT 许可证](LICENSE) 发布。
- **项目声明与设计参考**：参见 [NOTICE](NOTICE)。概念借鉴自 [suyuan2022/claude-cleanup](https://github.com/suyuan2022/suyuan-skill/tree/main/claude-cleanup)（该上游仅面向 macOS；其自动备份、废纸篓及设备身份轮换逻辑均**未**移植到本 Windows 原生实现）。本项目与 Anthropic PBC 无任何关联。
