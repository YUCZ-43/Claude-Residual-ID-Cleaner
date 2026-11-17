简体中文 | [English](Skills-Usage-Guide.en.md)

# claude-cleanup — 跨代理 Agent Skill 实战使用指南

**所属项目：** `YUCZ-43/claude-cleanup`（`Claude 账号残余 ID 清理工具 / Claude Residual ID Cleaner`）  
**规范技能包：** [skills/claude-cleanup/SKILL.md](../skills/claude-cleanup/SKILL.md)  
**相关文档：** [中文主 README](../README.md) | [English README](../README.en.md) | [CLI 命令参考](./CLI-Reference.md) | [Skill 安全规范](./Agent-Skill-Guide.md)

本指南面向希望在 **Antigravity（`agy` CLI 与 Desktop）**、**Codex CLI**、**Claude Code** 和 **Gemini CLI** 中安全部署并调用 `claude-cleanup` 技能的 Windows 用户与工程团队，提供从安装部署、生态激活、即复制即用的自然语言提示词到生命周期维护与故障排查的完整实战说明。

## 桌面端配套界面预览（非破坏性演示审计）

如果您更偏好图形界面审阅扫描结果或执行最终确认清理，可直接运行发布压缩包或 `dist\` 目录中的独立桌面端 `Claude-Residual-ID-Cleaner.exe`（与 Agent Skill 共用同一后端 `ClaudeCleanup.ps1`）：

![Claude 账号残余 ID 清理工具桌面端初始界面（简体中文）](images/ui-main-zh.png)

![Claude 账号残余 ID 清理工具演示扫描结果视图（简体中文）](images/ui-scan-results-zh.png)

---

## 1. 架构设计与不可逾越的安全保障

`claude-cleanup` 的全部 Agent Skill 均建立在**单一后端、只读优先、人机强确认**三项核心安全原则之上：

1. **单一后端引擎（零重复删除代码）**
   - 规范技能包 [skills/claude-cleanup/](../skills/claude-cleanup/SKILL.md) 仅包含提示词指令与安全引用文档，**绝不包含任何文件删除或注册表写入脚本**。
   - 所有 AI 代理必须直接调用仓库根目录下的单一 PowerShell 引擎 `ClaudeCleanup.ps1`（Windows PowerShell 5.1 使用 `powershell.exe -NoProfile -File ...`，PowerShell 7+ 使用 `pwsh.exe -NoProfile -File ...`）。
   - 严禁代理自行改用 `Remove-Item`、`rd`、`del`、`reg delete`、`Remove-AppxPackage`、`npm uninstall` 或 `code --uninstall-extension` 等替代命令绕过后端的 Win32 句柄绑定校验（`FILE_FLAG_OPEN_REPARSE_POINT`、`GetFinalPathNameByHandleW`、`GetSecurityInfo`、`SetFileInformationByHandle` 及 `ntdll!NtDeleteKey`）。

2. **默认 100% 只读审计，绝不改动 Windows 操作系统**
   - 技能默认入口严格限定为只读模式 `-Audit`（或独立后验 `-Verify`），在不传入 `-SaveAuditReport` 时甚至不向磁盘写入 `AUDIT.md`。
   - 工具仅针对白名单内的 Claude 残余项目工作：**绝不触碰** `C:\Windows`、`Program Files`、操作系统注册表分支、系统硬件或设备 ID（如 `MachineGuid`）、WSL 发行版内部文件、浏览器个人配置或无关软件；对 Windows 凭据管理器仅统计匹配目标数量而不读取秘密值，对环境变量仅输出作用域与变量名而不打印 API Key 值。
   - 本地清理**不会**更改远端 Anthropic 服务器侧的账号封禁状态或配额。

3. **64 位 SHA-256 哈希绑定与人工确认门禁**
   - 任何实际清理（`-Apply`）前，代理必须先引导或经用户明确要求执行 `-Plan` 生成确定性 `SchemaVersion = 3` 清单 `CLEANUP-PLAN.md`（含唯一 GUID `PlanId` 与文件级 SHA-256 哈希）。
   - 执行 `-Apply` 时必须同时具备：明确选定的 `-Policy`（`AccountData` 或 `FullRemoval`）、完全匹配的 64 位十六进制 `-ApprovedManifestSha256`、逐项列出 `Ready` 目标供人工核对，以及 PowerShell `ConfirmImpact = 'High'` 的交互式确认。
   - 每次真实的 `-Apply` 会通过临时文件 + `Flush($true)` + 原子替换写入 `VERIFICATION.md` 防重放台账，同一份清单哈希仅允许生效一次（`-WhatIf` 预演不消耗授权）。

4. **严禁策略绕过与越权操作**
   - 严禁使用或推荐 `-ExecutionPolicy Bypass`、`-ExecutionPolicy Unrestricted` 或未获对特定哈希明确授权的自动 `-Apply`。
   - 不自动请求 UAC 管理员提权，不修改 Windows ACL 或强行夺取所有权（`takeown` / `icacls`），不篡改设备标识、代理配置或遥测开关。
   - REA（Reverse Engineer Anything）仅为可选的开发期静态分析工具，运行时完全不需要。

> 完整的策略差异、Win32 句柄机制与威胁边界请查阅 [permissions-and-risks.md](../skills/claude-cleanup/references/permissions-and-risks.md) 与 [Agent-Skill-Guide.md](./Agent-Skill-Guide.md)。

---

## 2. 四大 AI 代理生态的安装与发现路径

规范技能目录 `skills/claude-cleanup/` 包含以下文件：

```text
skills/claude-cleanup/
├── SKILL.md
└── references/
    ├── permissions-and-risks.md
    └── agent-installation.md
```

### 2.1 发现路径总览（项目级 vs 用户级）

| AI 代理生态 | `-SkillTarget` 参数值 | 项目级路径（相对当前工作区） | 用户级路径（全局发现目录） |
| :--- | :--- | :--- | :--- |
| **Antigravity（`agy` CLI 与 Desktop）** | `Antigravity` | `.agents\skills\claude-cleanup\` | `%USERPROFILE%\.gemini\config\skills\claude-cleanup\` |
| **Codex CLI** | `Codex` 或 `Agents` | `.agents\skills\claude-cleanup\` | `%USERPROFILE%\.codex\skills\claude-cleanup\`（`Codex`）或 `%USERPROFILE%\.agents\skills\claude-cleanup\`（`Agents`） |
| **Claude Code** | `Claude` | `.claude\skills\claude-cleanup\` | `%USERPROFILE%\.claude\skills\claude-cleanup\` |
| **Gemini CLI** | `Gemini` | `.gemini\skills\claude-cleanup\`（或 `.agents\skills\claude-cleanup\`） | `%USERPROFILE%\.gemini\skills\claude-cleanup\` |

> **关键隔离提示：** 安装或卸载 Skill 仅在代理技能目录中增删上述 Markdown 文档及 `.claude-cleanup-skill-install.json` 清单，**不会**安装/卸载 `claude-cleanup` 工具本体，也**不会**修改 Claude Code 或 Claude Desktop。请勿将 `ClaudeCleanup.ps1` 复制到 `.codex`、`.agents`、`.gemini` 或 `.claude` 目录中（这些目录本身受到路径保护机制禁止被清理目标命中）。

### 2.2 自动化脚本安装（推荐）

在本地 `claude-cleanup` 仓库根目录打开 PowerShell，使用 [scripts/Install-ClaudeCleanup.ps1](../scripts/Install-ClaudeCleanup.ps1) 进行安全安装（内置路径规范化与重解析点预检，支持 `-WhatIf` 先行预演）：

```powershell
# 场景 A：同时安装工具本体（至 %LOCALAPPDATA%\Programs\claude-cleanup）与指定代理的 Skill
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -InstallSkill -SkillTarget Antigravity

# 场景 B：仅安装 Skill（-SkillOnly），适合已有仓库克隆、只需部署代理技能的场景
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Codex
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Antigravity
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Claude
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Gemini

# 场景 C：同时部署到全部支持的目标（Codex、Antigravity、Gemini、Claude、Agents）
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget All

# 场景 D：先使用 -WhatIf 预览，或指定中文输出提示（-Language zh-CN）
powershell.exe -NoProfile -File .\scripts\Install-ClaudeCleanup.ps1 -SkillOnly -SkillTarget All -Language zh-CN -WhatIf
```

> 若目标技能目录已存在内容，脚本会默认安全拦截；如需覆盖更新，请使用 `Update-ClaudeCleanup.ps1`，或在确认后显式追加 `-Force`。安装器参数详情见 [Launcher-and-Install.md](./Launcher-and-Install.md) 与 [agent-installation.md](../skills/claude-cleanup/references/agent-installation.md)。

### 2.3 手动安装与免全局项目级使用

#### 方式一：免全局安装（项目级直接使用）

如果您直接在本仓库目录内启动任意 AI 代理，或将 `skills\claude-cleanup\` 复制到某个特定项目的项目级目录（例如 `.agents\skills\claude-cleanup\`、`.claude\skills\claude-cleanup\` 或 `.gemini\skills\claude-cleanup\`），该技能仅在当前工作区生效，不会写入 `%USERPROFILE%` 全局目录。

#### 方式二：手动复制到用户级目录

在仓库根目录执行对应目标的复制命令：

```powershell
# 1. Antigravity（agy CLI & Desktop）
$target = Join-Path $HOME '.gemini\config\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force

# 2. Codex CLI（专有目录 .codex 或共享目录 .agents）
$target = Join-Path $HOME '.codex\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force

# 3. Claude Code
$target = Join-Path $HOME '.claude\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force

# 4. Gemini CLI
$target = Join-Path $HOME '.gemini\skills\claude-cleanup'
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath '.\skills\claude-cleanup' -Destination $target -Recurse -Force
```

> 提示：若使用手动 `Copy-Item` 安装，后续卸载时请采用第 4.2 节的手动删除方式（因为没有生成自动化安装清单 `.claude-cleanup-skill-install.json`）。

### 2.4 各生态激活机制与实战技巧

1. **Antigravity（`agy` CLI 与 Desktop）**
   - **发现路径**：用户级 `~/.gemini/config/skills/claude-cleanup`，项目级 `.agents/skills/claude-cleanup`。
   - **语义自动触发**：Antigravity 会依据 `SKILL.md` 的 YAML frontmatter（`name: claude-cleanup` 与 `description` 中的审计、清理计划、残余核验等语义描述）在对话涉及本地 Claude 残留审计或清理时自动加载该技能。
   - **`/skills` 管理**：可在对话或界面中使用 `/skills` 面板确认 `claude-cleanup` 已处于已加载/可用状态。
   - **显式调用技巧**：若当前工作区不在 `claude-cleanup` 仓库内，请在提示词中直接点名使用 `claude-cleanup` 技能并附上 `ClaudeCleanup.ps1` 的本地绝对路径（例如 `C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1`）。

2. **Codex CLI**
   - **发现路径**：用户级 `~/.codex/skills/claude-cleanup`（`-SkillTarget Codex`）与共享目录 `~/.agents/skills/claude-cleanup`（`-SkillTarget Agents`），项目级 `.agents/skills/claude-cleanup`。
   - **显式触发**：在 Codex CLI 中可使用 `$claude-cleanup` 显式指定技能，例如：`$claude-cleanup 请使用只读模式审计当前设备的 Claude 残余项。`
   - **提示词技巧**：明确要求 Codex 仅通过 `ClaudeCleanup.ps1 -Audit -OutputFormat Json` 读取结构化结果，并在进入 `-Plan` 或 `-Apply` 前暂停等待确认。

3. **Claude Code**
   - **发现路径**：用户级 `~/.claude/skills/claude-cleanup`，项目级 `.claude/skills/claude-cleanup`。
   - **调用方式**：当问题涉及 Windows 本机 Claude 残余诊断、清理计划生成或核验时自动发现，也可在提示词中明确说明“使用 `claude-cleanup` 技能，严格通过 `ClaudeCleanup.ps1` 执行只读体检”。
   - **注意事项**：若计划执行 `FullRemoval`（会涉及 `~/.claude` 本身或停用 Claude Code），务必先确保已退出正在运行的 `claude` 与 `Code` 进程，并在生成方案后改用独立桌面端或普通 PowerShell 终端完成最终删除，避免进程文件句柄占用。

4. **Gemini CLI**
   - **发现路径**：用户级 `~/.gemini/skills/claude-cleanup`，项目级 `.gemini/skills/claude-cleanup`（或 `.agents/skills/claude-cleanup`）。
   - **调用方式**：在 Gemini CLI 会话中通过自然语言触发或直接指定 `claude-cleanup` 技能，并附带 `ClaudeCleanup.ps1` 所在路径与 `-Language zh-CN` / `-OutputFormat Json` 要求。

### 2.5 安装后静态自检

在仓库根目录运行自动化技能包测试（该测试仅在隔离沙箱 `tests\sandbox\skill\` 中校验元数据、内部相对链接、安全铁律与模拟发现路径，绝不触碰真实全局目录）：

```powershell
powershell.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
pwsh.exe -NoProfile -File .\tests\SkillPackage.Tests.ps1
```

---

## 3. 即复制即用的自然语言提示词手册（Prompt Playbook）

以下 4 组提示词按标准安全工作流顺序设计。若您**在 `claude-cleanup` 仓库目录外**启动代理，请将命令提示中的 `.\ClaudeCleanup.ps1` 替换为您的实际路径（例如 `C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1`）。

### Prompt 1：只读封号残余审计（`-Audit -OutputFormat Json`）

适用于首次排查本机遗留的 Claude 账号/设备元数据、授权缓存、扩展状态、快捷方式及环境变量名。**对磁盘零写入。**

```text
请使用 claude-cleanup 技能，调用本地 ClaudeCleanup.ps1 执行严格只读审计（如果当前目录不是工具仓库，请先让我确认或使用路径 C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1）。
要求：
1. 仅执行：.\ClaudeCleanup.ps1 -Audit -OutputFormat Json -Language zh-CN
2. 不要运行 -Plan，也绝对不要运行 -Apply，更不要使用 -ExecutionPolicy Bypass。
3. 解析 JSON 输出后，按 AccountData 与 FullRemoval 两种策略分类汇总：
   - 发现的 Claude Code CLI、Claude Desktop、VS Code/Cursor 扩展与浏览器 Native Messaging 注册表项；
   - 每个候选项的 Decision（Ready / ReviewOnly / Blocked）及原因/所有者诊断；
   - 凭据管理器匹配计数、环境变量名称（严禁输出或猜测变量值）及 WSL 只读状态。
```

> 若需要把脱敏报告落盘以便留档查看，可改为要求附加 `-SaveAuditReport` 参数生成 `AUDIT.md`。

### Prompt 2：生成确定性清理方案并对比 `AccountData` 与 `FullRemoval`（`-Plan`）

在只读体检后，显式授权代理生成 `SchemaVersion = 3` 的确定性清单 `CLEANUP-PLAN.md`（注意：每次运行 `-Plan` 都会使之前生成清单的 SHA-256 哈希失效）。

```text
我已阅读只读审计结果。现在请使用 claude-cleanup 技能运行：
.\ClaudeCleanup.ps1 -Plan -OutputFormat Json -Language zh-CN
要求：
1. 生成 CLEANUP-PLAN.md 后停止，不要执行 -Apply。
2. 向我汇报生成的文件路径、PlanId、完整的 64 位 SHA-256 哈希，以及 Ready / ReviewOnly / Blocked 各有多少项。
3. 使用表格清晰对比当前清单在 AccountData（保留 .claude 自建技能、.claude.json 与 Desktop 混合存储）与 FullRemoval（彻底移除用户级 Claude 残留与扩展）下各自会纳入清理和会跳过/保留的具体条目。
```

> 如仅想先统计预估项数而不写入 `CLEANUP-PLAN.md`，可让代理先运行 `.\ClaudeCleanup.ps1 -Plan -WhatIf`。

### Prompt 3：非破坏性干跑预览（`-Apply -WhatIf`）

在确认策略前，先通过 `-WhatIf` 干跑校验清单哈希与最终将受影响的 `Ready` 目标列表。**`-WhatIf` 不会修改磁盘，也不会消耗清单 SHA-256 的单次使用授权。**

```text
请使用 claude-cleanup 技能，针对刚刚生成的清单哈希 <64-HEX-SHA256>，以 AccountData 策略（或改为 FullRemoval）执行非破坏性干跑预览：
.\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-HEX-SHA256> -WhatIf -Language zh-CN
要求：
1. 逐项列出本次预览中将被删除的所有 Ready 条目（ID、类别、类型、完整路径或包名），以及将被跳过的 ReviewOnly / Blocked 条目。
2. 明确提示我当前尚未删除任何内容，且本次 -WhatIf 未消耗该 SHA-256 的单次授权。
3. 等待我回复确认“策略 + 64 位 SHA-256 + 清单无误”后再进行下一步。
```

### Prompt 4：显式授权清理与独立后验核验（`-Apply` -> `-Verify`）

仅在您已确认所有 `claude` 与 `Code` 相关进程已关闭、已逐行核对完待删列表且明确知晓**无自动备份或回收站回滚**后使用。执行完成后立即通过 `-Verify` 独立复查三态结果。

```text
我已关闭相关 Claude / VS Code 进程，并明确授权使用以下参数执行本地清理（我已知晓删除不可撤销，且不会改动 Windows 系统本身或远端账号状态）：
- 策略：AccountData（或 FullRemoval）
- 批准的清单 SHA-256：<64-HEX-SHA256>
请使用 claude-cleanup 技能：
1. 严格调用 .\ClaudeCleanup.ps1 -Apply -Policy <AccountData|FullRemoval> -ApprovedManifestSha256 <64-HEX-SHA256> -OutputFormat Json -Language zh-CN 执行清理（如需交互确认请按标准高风险确认流程提示我）。
2. 清理结束后，立即独立运行 .\ClaudeCleanup.ps1 -Verify -OutputFormat Json -Language zh-CN。
3. 如实向我报告 VERIFICATION.md 的台账记录以及每一项的三态结果（Present / Absent / Unknown），严禁将 Unknown 汇报为已清除（Absent）。
```

---

## 4. 生命周期维护、故障排查与安全护栏速查表

### 4.1 Skill 升级与纯技能卸载

使用配套生命周期脚本管理已安装的用户级 Skill，操作完全与 `claude-cleanup` 工具本体及 Claude 应用本身隔离：

```powershell
# 1. 仅更新已安装的 Agent Skill（保留工具本体与报告不变）
powershell.exe -NoProfile -File .\scripts\Update-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Antigravity
powershell.exe -NoProfile -File .\scripts\Update-ClaudeCleanup.ps1 -SkillOnly -SkillTarget All

# 若同时安装了工具本体与 Skill，可合并更新
powershell.exe -NoProfile -File .\scripts\Update-ClaudeCleanup.ps1 -UpdateSkill -SkillTarget Codex

# 2. 仅卸载已安装的 Agent Skill（不删除工具本体、其他技能或 Claude 安装）
powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1 -SkillOnly -SkillTarget Antigravity
powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1 -SkillOnly -SkillTarget All

# 若需同时卸载工具本体与 Skill（默认保留 AUDIT.md / CLEANUP-PLAN.md / VERIFICATION.md；追加 -RemoveReports 可一并清理报告）
powershell.exe -NoProfile -File .\scripts\Uninstall-ClaudeCleanup.ps1 -UninstallSkill -SkillTarget All
```

如果是第 2.3 节手动复制安装的 Skill（未通过 `Install-ClaudeCleanup.ps1` 安装，缺少 `.claude-cleanup-skill-install.json`），可仅删除对应的 `claude-cleanup` 子目录（保留该代理目录下的其他技能）：

```powershell
$paths = @(
    (Join-Path $HOME '.agents\skills\claude-cleanup'),
    (Join-Path $HOME '.codex\skills\claude-cleanup'),
    (Join-Path $HOME '.gemini\config\skills\claude-cleanup'),
    (Join-Path $HOME '.gemini\skills\claude-cleanup'),
    (Join-Path $HOME '.claude\skills\claude-cleanup')
)
foreach ($p in $paths) {
    if (Test-Path -LiteralPath $p) {
        [IO.Directory]::Delete($p, $true)
    }
}
```

### 4.2 常见问题排查

| 问题现象 | 原因说明 | 推荐处理方式 |
| :--- | :--- | :--- |
| **PowerShell 提示脚本执行被策略阻止** | Windows 默认执行策略为 `Restricted`，或文件带 Internet Zone 标记 | 运行 `Get-ExecutionPolicy -List` 查看策略，审阅 `ClaudeCleanup.ps1` 后执行 `Unblock-File -LiteralPath .\ClaudeCleanup.ps1` 或将当前用户策略设为 `RemoteSigned`。**切勿使用 `-ExecutionPolicy Bypass`。** |
| **在仓库目录外调用 Skill 找不到 `ClaudeCleanup.ps1`** | 全局用户目录中的 `SKILL.md` 不包含工具脚本副本 | 在提示词中直接给出本地仓库或安装目录的完整路径，例如 `C:\Users\<USERNAME>\Tools\claude-cleanup\ClaudeCleanup.ps1`（或 `%LOCALAPPDATA%\Programs\claude-cleanup\ClaudeCleanup.ps1`）。**切勿把 `ClaudeCleanup.ps1` 复制进 `.codex` / `.agents` / `.gemini` / `.claude` 目录。** |
| **执行 `-Apply` 时报 SHA-256 校验失败或提示已消费** | 重新运行 `-Plan` 会刷新 `PlanId` 与哈希；且同一哈希在 `VERIFICATION.md` 中仅能消费一次 | 重新运行 `.\ClaudeCleanup.ps1 -Plan`，读取最新 `CLEANUP-PLAN.md` 的 64 位 SHA-256 并重新确认后再预览和执行。 |
| **部分条目始终显示 `Blocked` 或 `ReviewOnly`** | 目录包含 Junction/Symlink（`ReparseBlocked`）、所有者为 `BUILTIN\Administrators`、或属于需人工复核目录（如 `buddy-tokens.json`、`Claude-3p`、`pivot.claude.ai`） | 工具刻意拒绝越权改 ACL 或穿越重解析点。请查阅 `CLEANUP-PLAN.md` 中的原因说明，必要时在审阅后通过官方卸载命令或管理员终端手动处理，详见 [Troubleshooting-and-Compatibility.md](./Troubleshooting-and-Compatibility.md)。 |
| **终端中文输出出现乱码** | 旧版控制台编码未切换 UTF-8 | 直接通过 `ClaudeCleanup.ps1` 的 `-Language zh-CN` 运行（脚本内置初始化 UTF-8 无 BOM 控制台编码），或改用 PowerShell 7（`pwsh.exe`）/ Windows Terminal。 |

### 4.3 安全护栏速查表

| 护栏维度 | 允许的安全行为 | 底层强制约束机制 | 绝对禁止代理执行的行为 |
| :--- | :--- | :--- | :--- |
| **默认行为** | 只读 `-Audit` 与独立 `-Verify` | `SKILL.md` 默认只读工作流；未传 `-SaveAuditReport` 时 `-Audit` 不写盘 | 未经请求擅自运行 `-Plan`（覆写旧计划哈希）或自动执行 `-Apply` |
| **删除引擎** | 仅通过 `ClaudeCleanup.ps1` 委托执行 | `ClaudeCleanup.NativeFs` 句柄绑定校验 + `ntdll!NtDeleteKey` | 自行拼接 `Remove-Item`、`rd`、`del`、`reg delete`、`Remove-AppxPackage` |
| **执行策略** | `Unblock-File`（审阅后）或用户级 `RemoteSigned` | CI 与安全规范严格审计 | 建议或附加 `-ExecutionPolicy Bypass` / `-ExecutionPolicy Unrestricted` |
| **授权验证** | 展示 `-WhatIf` 列表、策略及 64 位 SHA-256 | 单次字节读取校验 + `ConfirmImpact = 'High'` + `VERIFICATION.md` 原子防重放台账 | 绕过确认、猜测哈希或重复使用已消费的清单哈希 |
| **系统与权限** | 标准非提权当前用户身份运行 | 路径白名单、保护路径黑名单、全树 `OwnerSid` 与无重解析点检验 | 自动 UAC 提权、`takeown`/`icacls` 改权限、修改 Windows 系统或 WSL |
| **隐私与远端** | 仅输出环境变量名与凭据目标计数 | JSON/Report 字段白名单脱敏与发布隐私扫描 | 读取或打印 API Key / 凭据秘密值、篡改设备 ID / 代理 / 遥测 |

---

## 5. 延伸阅读

- [项目主页 (README.md)](../README.md) / [English Home (README.en.md)](../README.en.md)
- [规范技能定义 (skills/claude-cleanup/SKILL.md)](../skills/claude-cleanup/SKILL.md)
- [多代理安装与卸载细节 (agent-installation.md)](../skills/claude-cleanup/references/agent-installation.md)
- [权限模型与风险边界 (permissions-and-risks.md)](../skills/claude-cleanup/references/permissions-and-risks.md)
- [CLI 完整参数与 JSON 契约 (CLI-Reference.md)](./CLI-Reference.md)
- [启动器与安装部署指南 (Launcher-and-Install.md)](./Launcher-and-Install.md)
- [卸载指南 (Uninstallation-Guide.md)](./Uninstallation-Guide.md)
- [故障排查与兼容性指南 (Troubleshooting-and-Compatibility.md)](./Troubleshooting-and-Compatibility.md)
