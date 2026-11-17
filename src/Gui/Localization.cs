using System;
using System.Collections.Generic;
using System.Globalization;

namespace ClaudeResidualIdCleaner
{
    internal static class Localization
    {
        public static string DetectDefaultLanguage()
        {
            try
            {
                string name = CultureInfo.CurrentUICulture.Name;
                if (!string.IsNullOrEmpty(name) &&
                    name.StartsWith("zh", StringComparison.OrdinalIgnoreCase))
                {
                    return "zh-CN";
                }
            }
            catch
            {
            }
            return "en-US";
        }

        public static Dictionary<string, string> GetStrings(string lang)
        {
            bool zh = string.Equals(lang, "zh-CN", StringComparison.OrdinalIgnoreCase);
            var d = new Dictionary<string, string>(StringComparer.Ordinal);
            if (zh)
            {
                d["AppTitle"] = "Claude 账号残余 ID 清理工具 (Claude Residual ID Cleaner) v1.0";
                d["BrandName"] = "claude-cleanup";
                d["HeaderTitle"] = "Claude 账号残余 ID 清理工具";
                d["VersionBadge"] = "v1.0 · 原生 WPF Studio";
                d["SafetyPill"] = "仅清理 Claude 封号残余 · 绝不改动 Windows 系统";
                d["Positioning"] = "专为清理 Claude 封号后残留在设备中的账号/设备 ID、认证 Token 与会话缓存而设计，绝不改动 Windows 系统本身。";
                d["LangButton"] = "简体中文 / English";
                d["AboutButton"] = "安全边界";
                d["AboutTitle"] = "关于与安全边界承诺";
                d["AboutBody"] =
                    "claude-cleanup — Claude 账号残余 ID 清理工具 (Claude Residual ID Cleaner)\r\n\r\n" +
                    "项目仓库：https://github.com/YUCZ-43/claude-cleanup\r\n" +
                    "定位：专为清理 Claude 封号后残留在设备中的账号/设备 ID、认证 Token 与会话缓存而设计，绝不改动 Windows 系统本身。\r\n\r\n" +
                    "核心安全铁律：\r\n" +
                    "1. 启动零改动、默认 100% 只读扫描；\r\n" +
                    "2. 所有清理严格通过 ClaudeCleanup.ps1 白名单与 Win32 句柄安全引擎执行；\r\n" +
                    "3. 不修改 Windows 系统文件、WSL、浏览器个人配置、系统硬件 ID 或远端账号状态；\r\n" +
                    "4. Credential Manager 与环境变量仅作只读数量/名称核查，绝不窃取或外传秘密值。";
                d["SidebarSectionTitle"] = "工作区导航";
                d["NavScan"] = "1. 残余扫描体检";
                d["NavPlan"] = "2. 清理方案预览";
                d["NavClean"] = "3. 安全清理执行";
                d["NavVerify"] = "4. 核验与报告";
                d["NavAbout"] = "5. 关于与安全边界";
                d["SidebarGuardTitle"] = "引擎安全护栏";
                d["SidebarGuardBody"] = "独立委托 ClaudeCleanup.ps1 执行\r\n默认只读 · 句柄校验 · 绝不改动 Windows 系统";
                d["PolicyPillPrefix"] = "策略: ";
                d["PolicyAccountShort"] = "AccountData";
                d["PolicyFullShort"] = "FullRemoval";
                d["MetricScannedTitle"] = "已扫描目标";
                d["MetricScannedSub"] = "白名单引擎检测项目数";
                d["MetricFoundTitle"] = "发现残余项";
                d["MetricFoundSub"] = "含可清理及只读核查项";
                d["MetricSizeTitle"] = "预计释放空间";
                d["MetricSizeSub"] = "基于树状快照字节统计";
                d["MetricSafetyTitle"] = "OS 安全状态";
                d["MetricSafetyValue"] = "已受保护";
                d["MetricSafetySub"] = "绝不改动 Windows 系统";
                d["AccountIdCardTitle"] = "已识别残余账号 ID (非敏感 UUID 元数据)";
                d["AccountIdCardSub"] = "仅提取 accountUuid / organizationUuid / userId / deviceId 供网页端核对；严禁读取 Token 或秘密凭据";
                d["AccountIdEmpty"] = "尚未扫描或未检测到本地账号 / 组织 / 设备 UUID";
                d["BtnCopyAccountId"] = "复制 ID";
                d["CopiedAccountIdMsg"] = "已将已识别的残余账号 ID 信息复制到剪贴板。";
                d["ScopeHeader"] = "扫描与清理目标范围 (基于核心引擎严格白名单)";
                d["ChkCli"] = "1. Claude Code CLI 配置与设备/账号 ID (~/.claude, .claude.json, npm/global)";
                d["ChkDesktop"] = "2. Claude Desktop 客户端会话与本地存储 (%APPDATA%\\Claude, %LOCALAPPDATA%\\Claude)";
                d["ChkVsCode"] = "3. VS Code / Cursor 扩展与浏览器 Host (extensions / NativeMessagingHosts)";
                d["ChkCred"] = "4. Windows 凭据管理器 Claude 凭据 (Credential Manager · 只读计数)";
                d["ChkEnv"] = "5. Claude 相关用户环境变量 (ANTHROPIC_* / CLAUDE_* · 仅报名称)";
                d["PolicyHeader"] = "清理策略";
                d["PolicyAccount"] = "AccountData (清除登录/设备缓存与日志，保留 .claude 自建配置)";
                d["PolicyFull"] = "FullRemoval (彻底移除用户级 Claude 客户端、扩展、配置与注册项)";
                d["BtnScan"] = "1. 立即扫描体检";
                d["BtnPlan"] = "2. 预览清理方案";
                d["BtnClean"] = "3. 一键安全清理";
                d["BtnVerify"] = "4. 清理结果核验";
                d["BtnOpenFolder"] = "打开报告目录";
                d["BtnExportSummary"] = "导出 AUDIT.md";
                d["BtnToggleLogs"] = "日志抽屉";
                d["PresetLabel"] = "快速预设:";
                d["PresetAccountBtn"] = "仅账号残余 (推荐)";
                d["PresetFullBtn"] = "完整卸载清理";
                d["LogDrawerTitle"] = "实时执行日志 · ClaudeCleanup.ps1 独立进程输出 (可拖拽上方分隔线调整高度)";
                d["GridEmptyHint"] = "尚未执行扫描 — 请点击“1. 立即扫描体检”进行只读检测。";
                d["DemoBanner"] = "演示审计模式 (--demo-audit)：当前展示脱敏模拟封号残余与模拟 Account UUID，未读取本机真实隐私数据，亦未改动系统。";
                d["NavBannerScan"] = "步骤 1 · 残余扫描体检：勾选要检测的 Claude 残余范围，点击“1. 立即扫描体检”识别账号 UUID 与残余文件。";
                d["NavBannerPlan"] = "步骤 2 · 清理方案预览：对比清理策略并生成带唯一 64 位 SHA-256 指纹的确定性方案 (CLEANUP-PLAN.md)。";
                d["NavBannerClean"] = "步骤 3 · 安全清理执行：清理按钮默认锁定，仅在生成包含 Ready 项的 SHA-256 方案后解锁，并强制 -WhatIf 与路径确认。";
                d["NavBannerVerify"] = "步骤 4 · 核验与报告：核对清理后残留三态、VERIFICATION.md 执行台账，或使用系统对话框另存为审计报告。";
                d["NavBannerAbout"] = "步骤 5 · 关于与安全边界：查看 claude-cleanup 单一后端架构、Win32 句柄安全引擎与版本元数据。";
                d["PlanViewTitle"] = "清理方案规划与策略对照 (SchemaVersion = 3)";
                d["PlanViewSub"] = "选择清理策略并生成确定性清单。每次重新生成方案都会作废旧 SHA-256 哈希；此步骤仅写入本地 CLEANUP-PLAN.md，不会删除任何文件。";
                d["PlanShaLabel"] = "当前方案 SHA-256 指纹:";
                d["PlanShaNone"] = "尚未生成 CLEANUP-PLAN.md (请点击“2. 预览清理方案”)";
                d["CleanViewTitle"] = "高影响安全清理执行闸门 (Fail-Closed)";
                d["CleanViewSub"] = "真实删除无自动备份或回收站，请先正常退出正在运行的 Claude 与 VS Code。仅限下方列表已通过句柄/所有者校验且匹配当前策略的项目。";
                d["CleanGateLocked"] = "闸门状态：已锁定 — 请先完成“1. 立即扫描体检”与“2. 预览清理方案”。";
                d["CleanGateReady"] = "闸门状态：已就绪 — Ready={0} 项 | 策略={1} | 清单={2}...";
                d["VerifyViewTitle"] = "独立核验、执行台账与报告导出";
                d["VerifyViewSub"] = "调用 ClaudeCleanup.ps1 -Verify 检验目标三态 (Present / Absent / Unknown) 与单次消耗账本，支持自定义路径另存为 Markdown 审计报告。";
                d["VerifySummaryNone"] = "尚未运行核验 — 点击“4. 清理结果核验”核对最新磁盘与注册表状态。";
                d["SafetyViewTitle"] = "安全架构与边界承诺";
                d["SafetyViewSubtitle"] = "本桌面端仅作为展示与编排界面，所有检测与清理均严格委托给唯一后端引擎 ClaudeCleanup.ps1。";
                d["SafetyCard1Title"] = "1. 默认 100% 只读与双阶段确认锁";
                d["SafetyCard1Body"] = "程序启动零改动。清理按钮默认禁用，必须先完成只读扫描并生成包含 Ready 项的 SHA-256 方案后才会解锁，且执行前强制执行 -WhatIf 预览并弹出明确路径清单确认。";
                d["SafetyCard2Title"] = "2. 单一后端委托与 Win32 句柄删除";
                d["SafetyCard2Body"] = "界面层不内置任何文件或注册表删除代码，所有动作以独立进程调用 ClaudeCleanup.ps1，启用重解析点拒绝、当前用户 SID 校验与 HKCU 精确白名单。";
                d["SafetyCard3Title"] = "3. 隐私边界与只读 UUID/凭据核查";
                d["SafetyCard3Body"] = "账号 ID 卡片仅读取非敏感 UUID 元数据；Windows 凭据管理器仅报告 Claude* 目标计数，环境变量仅报告变量名称，绝不读取 OAuth Token 或密钥原文。";
                d["SafetyCard4Title"] = "4. 版本与开源项目信息";
                d["SafetyCard4Body"] = "产品名称：claude-cleanup (Claude Residual ID Cleaner) v1.0.0.0\r\n运行架构：.NET Framework 4.x 原生 WPF 零控制台桌面端 (IMAGE_SUBSYSTEM_WINDOWS_GUI)\r\n项目仓库：https://github.com/YUCZ-43/claude-cleanup\r\n核心定位：仅清理 Claude 封号残余数据 · 绝不改动 Windows 系统本身";
                d["PrivilegeStandard"] = "标准权限";
                d["PrivilegeAdmin"] = "管理员权限";
                d["BtnRestartAdmin"] = "以管理员身份重启";
                d["RestartAdminTitle"] = "按需管理员提权确认";
                d["RestartAdminPrompt"] = "当前用户目录下的 Claude 残余清理无需管理员权限。\r\n\r\n仅当需要清理机器级注册表、系统级安装或权限受限项时才需要管理员权限。\r\n确定要触发 Windows UAC 并以管理员身份重启本程序吗？";
                d["RestartAdminFailed"] = "未完成管理员提权重启（已取消或被系统拦截）：{0}";
                d["ElevationHintFullRemoval"] = "提示：当前为标准权限，个人目录清理无需提权；若需处理系统级受保护残余，可按需点击右上角“以管理员身份重启”。";
                d["BtnBackToWorkspace"] = "返回扫描工作台";
                d["FooterBoundary"] = "安全边界：仅限白名单 Claude 残余 · 绝不改动 Windows 系统";
                d["DemoPlanNotice"] = "当前处于 --demo-audit 演示模式，仅展示只读模拟清单，不会写入真实 CLEANUP-PLAN.md 或执行删除。";
                d["ColSelect"] = "全选";
                d["ColCategory"] = "类别";
                d["ColPath"] = "残余项目 / 路径";
                d["ColStatus"] = "状态";
                d["ColDetails"] = "详情与决策说明";
                d["StatusIdle"] = "就绪：当前尚未对本机做任何改动。请先点击“1. 立即扫描体检”进行只读检测。";
                d["StatusScanning"] = "正在执行只读扫描 (ClaudeCleanup.ps1 -Audit)...";
                d["StatusScanned"] = "扫描完成：共检测 {0} 项候选项（发现 {1} 项有效项，只读安全未改动系统）。";
                d["StatusPlanning"] = "正在生成确定性清理方案 (CLEANUP-PLAN.md)...";
                d["StatusPlanned"] = "清理方案已生成：可执行 Ready={0} 项，SHA256={1}...";
                d["StatusApplying"] = "正在执行安全清理（已验证 SHA-256 与用户确认）...";
                d["StatusVerifying"] = "正在复核清理后残余与 VERIFICATION.md 台账...";
                d["StatusVerified"] = "核验完成：已复查 {0} 项清单目标，当前残留项 {1} 条。";
                d["StatusExported"] = "已导出脱敏只读审计报告: {0}";
                d["SaveDialogTitle"] = "导出只读审计报告 (AUDIT.md)";
                d["SaveDialogFilter"] = "Markdown 文档 (*.md)|*.md|所有文件 (*.*)|*.*";
                d["ExportSuccessTitle"] = "导出完成";
                d["ExportSuccessAskOpen"] = "审计报告已保存至：\r\n{0}\r\n\r\n是否立即打开查看？";
                d["BackendMissing"] = "未找到核心引擎 ClaudeCleanup.ps1。请将本程序放在工具根目录或 dist\\ 下运行。";
                d["NoReadyTitle"] = "无可清理目标";
                d["NoReadyBody"] = "在当前策略与所选范围下没有可安全自动删除的 Ready 项（凭据管理器与环境变量仅作只读核查，ReviewOnly/Blocked 项已受保护）。";
                d["ConfirmTitle"] = "执行安全清理最终确认（不可撤销）";
                d["ConfirmBody"] =
                    "ClaudeCleanup.ps1 将根据您勾选的项目与下列已校验清单，安全清除以下 {0} 项 Claude 封号残余数据\r\n" +
                    "（承诺：绝不改动 Windows 操作系统文件、WSL 或无关软件，无自动备份/回收站）：\r\n\r\n" +
                    "清理策略: {1}\r\n" +
                    "清单 SHA-256: {2}\r\n\r\n" +
                    "待清理路径/包清单：\r\n{3}\r\n\r\n" +
                    "确认立即执行吗？";
                d["DryRunTitle"] = "预览模式阻止执行";
                d["DryRunBody"] = "当前处于安全预览模式 (--dry-run)，已展示 -WhatIf 预览清单并阻止真实删除。";
                d["ClaudeRunningTitle"] = "检测到 Claude 仍在运行";
                d["ClaudeRunningBody"] = "检测到 Claude 客户端或后台进程仍在运行，为防止文件占用与数据损坏已暂停清理。请先在系统托盘彻底退出 Claude 后，点击确定重试。";
                d["VsCodeRunningTitle"] = "检测到 VS Code 仍在运行";
                d["VsCodeRunningBody"] = "检测到 VS Code 仍在运行，为避免扩展残留删除失败，请先彻底关闭所有 VS Code 窗口后重试。";
                d["FoundLabel"] = "已发现";
                d["ExcludedLabel"] = "当前方案未包含";
                d["CleanLabel"] = "无残留";
                d["ProtectedLabel"] = "安全红线受保护";
                d["ReadOnlyLabel"] = "只读核查";
            }
            else
            {
                d["AppTitle"] = "Claude Residual ID Cleaner (Claude 账号残余 ID 清理工具) v1.0";
                d["BrandName"] = "claude-cleanup";
                d["HeaderTitle"] = "Claude Residual ID Cleaner";
                d["VersionBadge"] = "v1.0 · Native WPF Studio";
                d["SafetyPill"] = "Cleans Claude Banned-Account Residuals Only · Never Alters Windows OS";
                d["Positioning"] = "Purpose-built to clean residual account/device IDs, auth tokens, and session caches left behind after a Claude ban — strictly without altering Windows OS itself.";
                d["LangButton"] = "简体中文 / English";
                d["AboutButton"] = "Safety & About";
                d["AboutTitle"] = "About & Safety Boundaries";
                d["AboutBody"] =
                    "claude-cleanup — Claude Residual ID Cleaner\r\n\r\n" +
                    "Repository: https://github.com/YUCZ-43/claude-cleanup\r\n" +
                    "Positioning: Purpose-built to clean residual local account/device IDs, auth tokens, and session caches left behind after a Claude account ban — strictly without altering Windows OS itself.\r\n\r\n" +
                    "Security Guarantees:\r\n" +
                    "1. Zero changes on startup; scanning is 100% read-only;\r\n" +
                    "2. Cleanup delegates exclusively to ClaudeCleanup.ps1 allowlists and Win32 handle-bound deletion;\r\n" +
                    "3. Never alters Windows OS files, WSL, browser profiles, OS hardware IDs, or remote server state;\r\n" +
                    "4. Credential Manager and env vars report counts/names only — secret values are never read.";
                d["SidebarSectionTitle"] = "WORKSPACE";
                d["NavScan"] = "1. Residual Scan";
                d["NavPlan"] = "2. Plan Preview";
                d["NavClean"] = "3. Safe Cleanup";
                d["NavVerify"] = "4. Verify & Reports";
                d["NavAbout"] = "5. Safety & About";
                d["SidebarGuardTitle"] = "Engine Guardrail";
                d["SidebarGuardBody"] = "Delegates to ClaudeCleanup.ps1\r\nRead-only default · Handle-bound · Never Alters Windows OS";
                d["PolicyPillPrefix"] = "Policy: ";
                d["PolicyAccountShort"] = "AccountData";
                d["PolicyFullShort"] = "FullRemoval";
                d["MetricScannedTitle"] = "Scanned Targets";
                d["MetricScannedSub"] = "Allowlisted engine probes";
                d["MetricFoundTitle"] = "Found Residuals";
                d["MetricFoundSub"] = "Active & read-only audit items";
                d["MetricSizeTitle"] = "Estimated Reclaimable";
                d["MetricSizeSub"] = "Computed from tree snapshot";
                d["MetricSafetyTitle"] = "OS Safety Status";
                d["MetricSafetyValue"] = "Protected";
                d["MetricSafetySub"] = "Never Alters Windows OS";
                d["AccountIdCardTitle"] = "Detected Residual Account IDs (Non-Secret Metadata)";
                d["AccountIdCardSub"] = "accountUuid / organizationUuid / deviceId only · Tokens & secrets never read";
                d["AccountIdEmpty"] = "Not scanned yet, or no local account / org / device UUIDs detected";
                d["BtnCopyAccountId"] = "Copy ID";
                d["CopiedAccountIdMsg"] = "Copied detected residual Account ID summary to clipboard.";
                d["ScopeHeader"] = "Scan & Cleanup Target Scope (Guarded by ClaudeCleanup.ps1 Allowlist)";
                d["ChkCli"] = "1. Claude Code CLI Configs & Account/Device IDs (~/.claude, .claude.json, npm/global)";
                d["ChkDesktop"] = "2. Claude Desktop Session & Local Storage (%APPDATA%\\Claude, %LOCALAPPDATA%\\Claude)";
                d["ChkVsCode"] = "3. VS Code / Cursor Extensions & Browser Hosts (extensions / NativeMessagingHosts)";
                d["ChkCred"] = "4. Windows Credential Manager Claude Logins (Credential Manager · Read-only count)";
                d["ChkEnv"] = "5. Claude User Environment Variables (ANTHROPIC_* / CLAUDE_* · Names only)";
                d["PolicyHeader"] = "Cleanup Policy";
                d["PolicyAccount"] = "AccountData (Clears auth tokens, device caches & logs; keeps .claude files)";
                d["PolicyFull"] = "FullRemoval (Removes user-level Claude apps, extensions, configs & host keys)";
                d["BtnScan"] = "1. Scan Residuals";
                d["BtnPlan"] = "2. Preview Plan";
                d["BtnClean"] = "3. Clean Selected";
                d["BtnVerify"] = "4. Verify Clean";
                d["BtnOpenFolder"] = "Open Reports Folder";
                d["BtnExportSummary"] = "Export AUDIT.md";
                d["BtnToggleLogs"] = "Logs";
                d["PresetLabel"] = "Presets:";
                d["PresetAccountBtn"] = "Account Data Only";
                d["PresetFullBtn"] = "Full Removal";
                d["LogDrawerTitle"] = "Live Execution Log · ClaudeCleanup.ps1 Output (Drag splitter above to resize)";
                d["GridEmptyHint"] = "No scan run yet — click '1. Scan Residuals' to perform a read-only audit.";
                d["DemoBanner"] = "Demo Audit Mode (--demo-audit): Displaying sanitized mock residuals & Account UUIDs; zero host disk reads or mutations.";
                d["NavBannerScan"] = "Step 1 · Residual Scan: Select target categories and click '1. Scan Residuals' to detect Account UUIDs and local leftovers.";
                d["NavBannerPlan"] = "Step 2 · Plan Preview: Compare cleanup policies and generate CLEANUP-PLAN.md with a deterministic 64-hex SHA-256 hash.";
                d["NavBannerClean"] = "Step 3 · Safe Cleanup: Clean button remains locked until a Ready plan exists; mandates -WhatIf preview and explicit confirmation.";
                d["NavBannerVerify"] = "Step 4 · Verify & Reports: Inspect post-cleanup three-state status, VERIFICATION.md ledger, or export AUDIT.md via Save As.";
                d["NavBannerAbout"] = "Step 5 · Safety & About: Review single-backend architecture, Win32 handle-bound safeguards, and build metadata.";
                d["PlanViewTitle"] = "Cleanup Plan & Policy Comparison (SchemaVersion = 3)";
                d["PlanViewSub"] = "Select a cleanup policy and generate a deterministic plan. Re-running Plan invalidates prior SHA-256 hashes and writes only CLEANUP-PLAN.md.";
                d["PlanShaLabel"] = "Active Manifest SHA-256:";
                d["PlanShaNone"] = "No CLEANUP-PLAN.md generated yet (click '2. Preview Plan')";
                d["CleanViewTitle"] = "High-Impact Safe Cleanup Gate (Fail-Closed)";
                d["CleanViewSub"] = "Deletions are permanent (no automatic backup/Recycle Bin). Close running Claude and VS Code processes first. Only allowlisted Ready items matching policy execute.";
                d["CleanGateLocked"] = "Gate Status: Locked — complete '1. Scan Residuals' and '2. Preview Plan' first.";
                d["CleanGateReady"] = "Gate Status: Armed — Ready={0} item(s) | Policy={1} | Manifest={2}...";
                d["VerifyViewTitle"] = "Independent Verification, Execution Ledger & Report Export";
                d["VerifyViewSub"] = "Runs ClaudeCleanup.ps1 -Verify for Present/Absent/Unknown checks and single-use replay ledger, or exports sanitized AUDIT.md to a chosen path.";
                d["VerifySummaryNone"] = "No verification run yet — click '4. Verify Clean' to inspect disk and registry state.";
                d["SafetyViewTitle"] = "Security Architecture & Safety Boundaries";
                d["SafetyViewSubtitle"] = "This desktop app is a pure presentation shell; all discovery and cleanup run out-of-process inside ClaudeCleanup.ps1.";
                d["SafetyCard1Title"] = "1. Read-Only Default & Two-Stage Lock";
                d["SafetyCard1Body"] = "Zero changes on startup. Clean button stays disabled until read-only audit + Ready SHA-256 plan exist, followed by -WhatIf preview and explicit path confirmation.";
                d["SafetyCard2Title"] = "2. Single Backend & Win32 Handle Deletion";
                d["SafetyCard2Body"] = "Zero deletion APIs in GUI code. Out-of-process execution delegates to ClaudeCleanup.ps1 with reparse-point blocks, OwnerSid checks, and HKCU allowlists.";
                d["SafetyCard3Title"] = "3. Privacy Boundary & Non-Secret UUID Inspection";
                d["SafetyCard3Body"] = "Account ID card reads non-secret UUID metadata only; Credential Manager reports counts only, env vars emit names only — OAuth tokens and secrets are never read.";
                d["SafetyCard4Title"] = "4. Version & Repository Information";
                d["SafetyCard4Body"] = "Product: claude-cleanup (Claude Residual ID Cleaner) v1.0.0.0\r\nRuntime: Native .NET Framework 4.x WPF Zero-Console App (IMAGE_SUBSYSTEM_WINDOWS_GUI)\r\nRepository: https://github.com/YUCZ-43/claude-cleanup\r\nPositioning: Cleans Claude Banned-Account Residuals Only · Never Alters Windows OS";
                d["PrivilegeStandard"] = "Standard User";
                d["PrivilegeAdmin"] = "Administrator";
                d["BtnRestartAdmin"] = "Restart as Admin";
                d["RestartAdminTitle"] = "On-Demand Administrator Elevation";
                d["RestartAdminPrompt"] = "Standard user-profile Claude residual cleanup works without Administrator privileges.\r\n\r\nOnly machine-wide items or ACL-protected residuals require elevation.\r\nTrigger Windows UAC and restart this app as Administrator now?";
                d["RestartAdminFailed"] = "Administrator restart did not complete (cancelled or blocked): {0}";
                d["ElevationHintFullRemoval"] = "Tip: Running as Standard User. User-profile cleanup needs no elevation; click 'Restart as Admin' only if machine-level residuals require it.";
                d["BtnBackToWorkspace"] = "Back to Scan Workspace";
                d["FooterBoundary"] = "Boundary: Allowlisted Claude residuals only · Never Alters Windows OS";
                d["DemoPlanNotice"] = "Demo audit mode (--demo-audit) active: simulates read-only discovery only; no real CLEANUP-PLAN.md write or deletion.";
                d["ColSelect"] = "Select All";
                d["ColCategory"] = "Category";
                d["ColPath"] = "Residual Item / Path";
                d["ColStatus"] = "Status";
                d["ColDetails"] = "Details & Decision";
                d["StatusIdle"] = "Ready: Zero changes performed. Click '1. Scan Residuals' to run a read-only audit.";
                d["StatusScanning"] = "Running read-only residual scan (ClaudeCleanup.ps1 -Audit)...";
                d["StatusScanned"] = "Scan complete: inspected {0} item(s) ({1} active; read-only, Windows OS untouched).";
                d["StatusPlanning"] = "Generating deterministic plan (CLEANUP-PLAN.md)...";
                d["StatusPlanned"] = "Plan ready: Ready={0} item(s), SHA256={1}...";
                d["StatusApplying"] = "Running allowlisted cleanup (SHA-256 verified & user confirmed)...";
                d["StatusVerifying"] = "Verifying residual state & VERIFICATION.md ledger...";
                d["StatusVerified"] = "Verification complete: {0} plan record(s) checked, {1} current inventory item(s).";
                d["StatusExported"] = "Exported sanitized audit report: {0}";
                d["SaveDialogTitle"] = "Save Sanitized Audit Report (AUDIT.md)";
                d["SaveDialogFilter"] = "Markdown (*.md)|*.md|All Files (*.*)|*.*";
                d["ExportSuccessTitle"] = "Export Complete";
                d["ExportSuccessAskOpen"] = "Audit report saved cleanly to:\r\n{0}\r\n\r\nOpen the exported file now?";
                d["BackendMissing"] = "ClaudeCleanup.ps1 backend was not found. Place this executable in the toolkit root or dist\\ directory.";
                d["NoReadyTitle"] = "No Eligible Cleanup Targets";
                d["NoReadyBody"] = "No Ready cleanup targets match the current policy and checked scopes (Credential Manager / Env Vars are read-only audit items; ReviewOnly/Blocked items remain protected).";
                d["ConfirmTitle"] = "Final Safe Cleanup Confirmation (Irreversible)";
                d["ConfirmBody"] =
                    "ClaudeCleanup.ps1 will permanently remove the following {0} allowlisted Claude banned-account residual item(s)\r\n" +
                    "(Guarantee: Windows OS files, WSL, and unrelated apps remain untouched; no automatic backup/recycle bin):\r\n\r\n" +
                    "Policy: {1}\r\n" +
                    "Manifest SHA-256: {2}\r\n\r\n" +
                    "Targets:\r\n{3}\r\n\r\n" +
                    "Proceed with safe cleanup?";
                d["DryRunTitle"] = "Dry-Run Mode Active";
                d["DryRunBody"] = "Running in safe --dry-run mode: -WhatIf preview was evaluated and real deletion was blocked.";
                d["ClaudeRunningTitle"] = "Claude Is Still Running";
                d["ClaudeRunningBody"] = "Claude Desktop or background Claude processes are currently running. Cleanup has been paused to prevent file locks. Please quit Claude completely from the system tray and retry.";
                d["VsCodeRunningTitle"] = "VS Code Is Still Running";
                d["VsCodeRunningBody"] = "VS Code is currently running. Please close all VS Code windows completely before removing its Claude extension and retry.";
                d["FoundLabel"] = "Found";
                d["ExcludedLabel"] = "Scope Excluded";
                d["CleanLabel"] = "Clean";
                d["ProtectedLabel"] = "Protected";
                d["ReadOnlyLabel"] = "Read-Only Audit";
            }
            return d;
        }
    }
}
