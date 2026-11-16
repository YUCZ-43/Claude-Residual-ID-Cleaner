# Windows Claude Cleanup

用于当前 Windows 用户的 Claude Code 与 Claude Desktop 本地数据审计、删除计划和获批后的清理。适用于 Windows PowerShell 5.1 与 PowerShell 7。项目不会修改设备标识、代理、遥测、浏览器站点数据或 WSL，也不会改变远端账号状态。

## 使用顺序

在本目录的 PowerShell 中运行：

```powershell
.\ClaudeCleanup.ps1 -Help
.\ClaudeCleanup.ps1 -Audit
.\ClaudeCleanup.ps1 -Plan
.\ClaudeCleanup.ps1 -Verify
```

`-Audit` 和 `-Verify` 只读取系统；`-Plan` 仅在本项目目录写入 `CLEANUP-PLAN.md`。计划同时列出 `AccountData` 和 `FullRemoval` 两种策略。`Ready` 是工具能够安全定位的候选，**不是删除授权**；`ReviewOnly` 与 `Blocked` 不会执行。每次重新运行 `-Plan` 都会覆盖旧清单并生成新的 SHA-256，旧批准随之失效。

在用户明确批准**某一策略、完整清单及其 SHA-256** 后，先预览：

```powershell
.\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64位SHA256> -WhatIf
```

只有在另行获得真实删除批准后，才去掉 `-WhatIf`。真实 `-Apply` 会再次检查清单哈希、当前用户、目标归属、链接、进程、权限，以及目标的大小、条目数和修改时间；任何变化都要求重新生成计划并重新批准。通过 PowerShell 确认提示后才执行。完成或部分失败后独立运行 `-Verify`。不要把批准创建工具或运行测试视为删除批准。

## 两种策略

- `AccountData`：只处理清单中可确认的 Claude 凭据文件、账户缓存、应用缓存和诊断目录。`.claude.json`、Desktop 的 `Local Storage`、`IndexedDB` 等混合数据保留，因此该策略可能无法清除全部登录状态。`buddy-tokens.json` 的用途未充分核实，默认 `ReviewOnly`。
- `FullRemoval`：计划移除已确认的用户级 Claude Code 安装、配置、Desktop 应用数据、MSIX 包和 Claude 专属集成。整目录 `.claude` 会删除 skills、plugins、MCP 配置、历史和其他用户创建内容；Desktop 目录可能包含本地会话、文件、扩展及 Cowork 虚拟机数据。含链接或用户备份的目录默认阻断或待决定，因此一次完整策略执行也可能仍有残留。

Credential Manager 只审计目标元数据，不读取秘密；本版本**不删除其中的条目**。浏览器配置文件、站点数据及 WSL 发行版只报告，不自动处理。MSIX 的用户数据目录可能含指向其他磁盘 `WpSystem` 目录（例如 `<Drive>:\WpSystem`）的 junction，工具不会直接递归删除该目录；获批的包卸载交由 Windows `Remove-AppxPackage` 完成。它可能连带处理包管理的数据和服务，须在审批时一并考虑。

## 安全与限制

仅接受已知 Claude 候选的精确路径或包标识。文件删除前逐层拒绝 reparse point；不递归穿过符号链接或 junction。保护 Windows、Program Files、Codex 和本项目目录。脚本不自动备份、不移到隔离区、不提升管理员权限、不结束进程。删除失败立即停止并在 `VERIFICATION.md` 记录部分结果。

删除为不可逆操作。重装程序不能保证找回本地会话或配置；没有自动回滚。Claude 或 VS Code 正在运行时，应先正常退出。若路径或归属发生变化，重新审计并生成新清单。

## 测试

测试仅在获批的 `tests/sandbox/` 内创建和移除模拟数据：

```powershell
powershell.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
pwsh.exe -NoProfile -File .\tests\ClaudeCleanup.Tests.ps1
```

测试覆盖路径越界、受保护目录、junction、链接、授权哈希、`-WhatIf`、缺失目标、锁定文件和幂等性。Windows 未授予符号链接创建权限时，对应测试会明确 `SKIP`；junction 拒绝仍应通过。测试通过不证明真实删除、MSIX 卸载或 WSL 清理已成功。

设计参考：[suyuan2022/claude-cleanup](https://github.com/suyuan2022/suyuan-skill/tree/main/claude-cleanup)。上游本地清理仅支持 macOS，包含备份、废纸篓和身份轮换；这些行为没有移植到本工具。
