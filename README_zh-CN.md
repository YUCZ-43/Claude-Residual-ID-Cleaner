[English](README.md) | **简体中文**

# Windows Claude Cleanup Toolkit

用于 Windows 平台的 Claude Code 与 Claude Desktop 本地数据**只读审计**、**哈希绑定规划**及**用户明确授权清理**的原生 PowerShell 工具。

---

## 1. 项目简介

本工具用于排查并清理当前 Windows 用户下与 Claude Code 及 Claude Desktop 相关的本地安装、配置、缓存、诊断日志、VS Code 扩展、MSIX 包及浏览器 Native Messaging 注册项。工具将只读审计（`-Audit`）、清单规划（`-Plan`）、预览/确认执行（`-Apply`）与独立核验（`-Verify`）严格分离，不会修改设备标识、代理、遥测、浏览器站点数据或 WSL 发行版。

## 2. 当前发布状态

- **开发阶段**：预发布 / 主动开发阶段（已完成 P0 删除安全加固与 Windows 清理覆盖扩展，正处于验收审查阶段）。
- **真实清理状态**：开发与测试期间**未授权、也未执行**任何真实 Claude 数据删除。
- **仓库状态**：当前为私有开发仓库（`main` 分支）。

## 3. 功能特性与限制

### 已实现能力
- 只读环境与候选审计（`-Audit`）：覆盖原生及 npm 全局安装版 Claude Code CLI（通过 `npm`、`.npmrc`、`NPM_CONFIG_PREFIX`、`%APPDATA%\npm` 解析前缀）、Claude Desktop、VS Code / Cursor / Windsurf Claude 扩展、MSIX 包、开始菜单/桌面/启动项 `.lnk` 快捷方式、相关服务/定时任务、环境变量**仅名称**（仅输出 `Scope` 与 `Name`，绝不读取秘密值）、`PATH` 残留项、Credential Manager 目标计数（不读取秘密值）、AppData 角色分类、路径 ACL/所有者/重解析点诊断以及 WSL 只读状态报告。
- 结构化 JSON 输出（`-OutputFormat Json`）：在 `-Audit`、`-Plan`、`-Verify` 与 `-Apply` 模式下均支持机器可读 JSON 输出，便于自动化与后续 Skill 集成。
- 确定性 `SchemaVersion = 3` 清单生成（`-Plan`）：输出 `CLEANUP-PLAN.md`，标注 `Ready` / `ReviewOnly` / `Blocked` 决策，并记录 NTFS `VolumeSerialNumber`、`FileIndex` 及子树最大修改时间戳 `MaxLastWriteUtcTicks`。
- Win32 句柄绑定文件删除（`SetFileInformationByHandle`）：严格拒绝重解析点、校验子树所有者 SID、单次字节读取校验 SHA-256，并通过原子执行台账防止授权重放。
- 受控包卸载器（仅 `FullRemoval`）：严格限定作用域执行 `npm uninstall -g @anthropic-ai/claude-code`、`code --uninstall-extension anthropic.claude-code` 与 MSIX `Remove-AppxPackage`，并在卸载后执行 fail-closed 存在性核验。
- 结构化状态与失败报告：明确区分 `Removed`、`AlreadyAbsent`、`Skipped`、`Blocked`、`Failed`、`NotExecuted`、`PartialRemoval` 以及三态存在性 `PresenceState`（`Present` / `Absent` / `Unknown`）。

### 规划中能力（尚未实现）
- 跨代理 Skill（`claude-cleanup`，兼容 Codex CLI、Antigravity CLI、Gemini CLI 与 Claude Code）。
- 面向普通用户的轻量 Windows 启动器、用户级安装/卸载脚本、CI 流水线及可选 GUI 评估。

## 4. 支持的 Windows 版本

- Windows 10（64 位）
- Windows 11（64 位）
- 主要面向本地 NTFS 卷（当文件系统不支持所需句柄标识原语时按 fail-closed 拦截）。

## 5. PowerShell 兼容性

- **Windows PowerShell 5.1**（`powershell.exe`，已在 5.1.26100.x 验证）
- **PowerShell 7+**（`pwsh.exe`，已在 7.6.x 验证）
- 内嵌 C# 5 P/Invoke 层（`ClaudeCleanup.NativeFs`）可在 .NET Framework 4.x 与现代 .NET 下直接编译加载。

## 6. 安装说明

1. 将本仓库克隆或下载到本地目录（例如 `C:\Users\<USERNAME>\Tools\Windows-Claude-Cleanup`）。
2. 运行前先审阅 [ClaudeCleanup.ps1](ClaudeCleanup.ps1) 源码。
3. 本工具独立运行，**无需**安装第三方 PowerShell 模块、AI 代理、Git 或 REA。
4. *（规划中）* 后续阶段将提供专用的用户级 `Install-ClaudeCleanup.ps1`。

## 7. 快速开始

在本项目根目录的 PowerShell 中运行：

```powershell
.\ClaudeCleanup.ps1 -Help
.\ClaudeCleanup.ps1 -Audit
.\ClaudeCleanup.ps1 -Plan
```

在审阅审计结果以及 `CLEANUP-PLAN.md` 中的每条路径与 SHA-256 哈希之前，不要进行任何执行操作。

## 8. CLI 命令参考

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

## 13. 常见问题排查

- **`Unsupported manifest schema version (SchemaVersion 3 required)`**：请重新运行 `.\ClaudeCleanup.ps1 -Plan` 生成最新的 `SchemaVersion = 3` 清单并使用新 SHA-256。
- **`Target is not owned by the current user`（`BUILTIN\Administrators`）**：提权安装或运行期间创建的目录/文件可能归属 Administrators。本版本按保守原则将其标为 `Blocked`，不会擅自修改 ACL 或夺取所有权。
- **受限环境 `-Audit` / `-Verify` 显示大量 `Blocked` 或 `Unknown`**：当系统或沙箱限制访问时，工具会显式标为 `Blocked` 或 `Unknown`（绝不误判为 `Absent` 已删除）。
- **PowerShell 执行策略拦截**：请勿盲目长期关闭安全策略；可先用 `Get-ExecutionPolicy -List` 查看策略，并在审阅源码确认安全后针对下载脚本做解除锁定处理。

## 14. 测试与验证

测试夹具**仅**在 `tests/sandbox/` 内创建并在结束时自动清理（测试绝不操作真实 Claude 数据或真实 HKCU 注册表键）：

```powershell
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
```

- 覆盖路径边界（ADS / 尾随空格与点 / 精确根保护）、无 `Remove-Item` / `-CheckOwner $false` / `RegDeleteKeyW` 代码不变量、三态存在性（`Present` / `Absent` / `Unknown`）、junction、断链、父路径替换、条件符号链接测试、子树同长度篡改（`MaxLastWriteUtcTicks`）、`FileIndex` 替换、清单篡改与防重放、台账截断与持久化失败阻断、Mock 注册表验证、部分失败与事后核验、npm 前缀/包检测与限定 `@anthropic-ai/claude-code` 卸载保护、Mock `AppxPackage` 与 VS Code `anthropic.claude-code` 卸载状态流转、`Get-PathAclDiagnostics` / `Get-AppDataClassification`，以及 `-OutputFormat Json` 结构与隐私检查（不含环境变量值）。
- **权限与授权说明**：在 Windows 上创建符号链接需要管理员权限或开发者模式（`SeCreateSymbolicLinkPrivilege`），非特权会话会将对应符号链接创建用例明确标为 `SKIP`（不计入通过）；若在禁用 `FSCTL_SET_REPARSE_POINT` 的沙箱内运行，junction 创建也会相应跳过；未经单独授权的真实 HKCU 写入、跨 SID 磁盘测试以及真实 `npm` / `code` / `Remove-AppxPackage` 卸载执行均明确标为 `NotExecuted`。

## 15. 已知问题与不支持的操作

- **MSIX 数据 Junction**：`%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc` 中含指向外部卷（例如 `<Drive>:\WpSystem`）的 junction，绝不能直接递归删除；获批的 MSIX 卸载交由 `Remove-AppxPackage` 完成，其可能连带清理包数据与 `CoworkVMService`。
- **Win32 打开句柄前窗口与硬链接**：在 `CreateFileW` 打开顶层根或子句柄前的极短瞬间仍存在用户态路径查找窗口；`SetFileInformationByHandle` 仅解除当前目录项链接，不会移除未知位置的外部 NTFS 硬链接。
- **非文件系统 OS 接口**：`AppxPackage` 卸载受 Windows 应用部署服务托管。
- **WSL 隔离**：WSL 发行版及其内部 `~/.claude` 数据在运行时仅做只读报告，绝不自动修改。
- **明确不支持**：设备标识伪造、反滥用机制绕过、Credential Manager 秘密删除及自动更改 ACL/所有权。

## 16. 规划中的 Agent Skills 集成 *（Planned）*

后续阶段将在 Windows 清理覆盖完善后提供名为 `claude-cleanup` 的规范 Skill（兼容 Codex CLI、Antigravity CLI、Gemini CLI 与 Claude Code）。该 Skill 仅调用经过验证的 `ClaudeCleanup.ps1` 后端，默认只读审计，严禁自动触发 `-Apply`，且不以 REA 作为运行时依赖。

## 17. 规划中的 Windows 启动器与 GUI *（Planned）*

后续阶段将评估并实现面向普通用户的轻量启动器（提供 Audit / Plan / 查看报告 / Verify / Help / Exit 菜单，不绕过执行策略、不自动提权）以及可选图形界面评估。当前版本尚未包含上述组件。

## 18. 如何卸载 Claude

本工具在未经您生成清单并明确批准前**不会**自行卸载 Claude：
- 当前可审计用户级 `claude.exe`、`.local\share\claude`、Desktop MSIX 及 VS Code 扩展（归属 `BUILTIN\Administrators` 的路径保持 `Blocked`）。
- 对于 MSIX 版 Claude Desktop，您也可通过 Windows **设置 → 应用 → 已安装的应用** 卸载，或在审阅 `FullRemoval` 清单后通过受控流程卸载。
- 删除本清理工具**不会**卸载 Claude 本体。

## 19. 如何卸载本工具

- 当前为便携单仓库形式：直接删除本仓库目录（例如 `Windows-Claude-Cleanup`）即可移除，不会修改任何系统全局配置。
- *（规划中）* 后续阶段将提供独立的用户级 `Uninstall-ClaudeCleanup.ps1`，严格区分卸载工具、卸载 Agent Skill 与清理 Claude 本体/数据。

## 20. GitHub 开发与贡献流程

- 在 `main` 分支按严格分阶段授权推进：检查 `git status` → 最小范围修改 → Windows PowerShell 5.1 与 PowerShell 7 回归验证 → `git diff` 隐私审计 → Conventional Commit 本地提交与审查后推送。
- 严禁将 `AUDIT.md`、`CLEANUP-PLAN.md`、`VERIFICATION.md`、`tests/sandbox/`、凭据、SID 或本地运行日志提交到版本库。

## 21. 许可证与致谢状态

- **许可证**：将在公开准备里程碑最终确定（推荐使用 MIT 许可证；当前仓库尚未最终确认并提交 `LICENSE` 文件）。
- **设计参考**：概念借鉴自 [suyuan2022/claude-cleanup](https://github.com/suyuan2022/suyuan-skill/tree/main/claude-cleanup)（该上游仅面向 macOS；其自动备份、废纸篓及设备身份轮换逻辑均**未**移植到本 Windows 工具）。
