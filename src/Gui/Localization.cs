using System;
using System.Collections.Generic;

namespace ClaudeResidualIdCleaner
{
    internal static class Localization
    {
        public static string DetectDefaultLanguage()
        {
            return "zh-CN";
        }

        public static Dictionary<string, string> GetStrings(string lang)
        {
            bool zh = string.Equals(lang, "zh-CN", StringComparison.OrdinalIgnoreCase);
            var d = new Dictionary<string, string>(StringComparer.Ordinal);
            if (zh)
            {
                d["AppTitle"] = "Claude 账号残余 ID 清理工具 (Claude Residual ID Cleaner) v0.1.0";
                d["BrandName"] = "Claude Residual ID Cleaner";
                d["HeaderTitle"] = "Claude 账号残余 ID 清理工具";
                d["VersionBadge"] = "v0.1.0 · 原生 WPF Studio";
                d["SafetyPill"] = "仅清理 Claude 封号残余 · 绝不改动 Windows 系统";
                d["Positioning"] = "专为清理 Claude 封号后残留在设备中的账号/设备 ID、认证 Token 与会话缓存而设计，绝不改动 Windows 系统本身。";
                d["LangButton"] = "简体中文 / English";
                d["AboutButton"] = "安全与关于";
                d["AboutTitle"] = "关于与安全边界承诺";
                d["AboutBody"] =
                    "Claude Residual ID Cleaner — Claude 账号残余 ID 清理工具\r\n\r\n" +
                    "项目仓库：https://github.com/YUCZ-43/Claude-Residual-ID-Cleaner\r\n" +
                    "开源协议：MIT License（独立开源实现）\r\n" +
                    "定位：专为清理 Claude 封号后残留在设备中的账号/设备 ID、认证 Token 与会话缓存而设计，绝不改动 Windows 系统本身。\r\n\r\n" +
                    "核心安全铁律：\r\n" +
                    "1. 启动零改动、默认 100% 只读扫描；\r\n" +
                    "2. 所有清理严格通过 ClaudeCleanup.ps1 白名单与 Win32 句柄安全引擎执行；\r\n" +
                    "3. 不修改 Windows 系统文件、WSL、浏览器个人配置、系统硬件 ID 或远端账号状态；\r\n" +
                    "4. Credential Manager 与环境变量仅作只读数量/名称核查，绝不窃取或外传秘密值。";
                d["SidebarSectionTitle"] = "功能视图";
                d["NavScanClean"] = "1. 扫描与清理";
                d["NavReports"] = "2. 审计与报告";
                d["NavSafety"] = "3. 安全边界与关于";
                d["SidebarGuardTitle"] = "引擎安全护栏";
                d["SidebarGuardBody"] = "独立委托 ClaudeCleanup.ps1 执行\r\n默认只读 · 句柄校验 · 绝不改动 Windows 系统";
                d["PolicyPillPrefix"] = "策略: ";
                d["PolicyAccountShort"] = "AccountData";
                d["PolicyFullShort"] = "FullRemoval";
                d["MetricScannedTitle"] = "已扫描目标";
                d["MetricScannedSub"] = "白名单引擎检测项目数";
                d["MetricFoundTitle"] = "待处理残余";
                d["MetricFoundSub"] = "当前可清理或待复核项";
                d["MetricSizeTitle"] = "预计释放空间";
                d["MetricSizeSub"] = "基于树状快照字节统计";
                d["MetricSafetyTitle"] = "OS 安全状态";
                d["MetricSafetyValue"] = "已受保护";
                d["MetricSafetySub"] = "绝不改动 Windows 系统";
                d["AccountIdCardTitle"] = "已识别残余账号 ID (非敏感 UUID 元数据)";
                d["AccountIdCardSub"] = "仅提取 accountUuid / organizationUuid / userId / deviceId 供核对；严禁读取 Token 或秘密凭据";
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
                d["PlanGateLockedPill"] = "方案未就绪 · 需先扫描并预览方案";
                d["PlanGateReadyPill"] = "闸门已解锁 · Ready={0} · SHA256={1}...";
                d["CleaningProgressTitle"] = "正在实时安全清理...";
                d["CleaningProgressBanner"] = "正在清理第 {0}/{1} 项: {2}...";
                d["CompletionBannerTitleOk"] = "清理与核验全部完成！已安全清除 {0} 项残余，当前剩余可清理残余：0 项";
                d["CompletionBannerSubOk"] = "VERIFICATION.md 执行台账已原子写入；Windows 系统文件与无关配置 100% 未改动。";
                d["CompletionBannerTitlePartial"] = "部分清理完成：已清除 {0} 项，仍有 {1} 项被占用或待处理";
                d["CompletionBannerSubPartial"] = "请关闭占用 Claude 或浏览器的进程后重新扫描与清理。";
                d["LogDrawerTitle"] = "实时执行日志 · ClaudeCleanup.ps1 独立进程输出 (可拖拽上方分隔线调整高度)";
                d["GridEmptyHint"] = "尚未执行扫描 — 请点击“1. 立即扫描体检”进行只读检测。";
                d["DemoBanner"] = "演示审计模式 (--demo-audit)：当前展示脱敏模拟封号残余与模拟 Account UUID，未读取本机真实隐私数据，亦未改动系统。";
                d["DemoCleaningBanner"] = "实时清理演示模式 (--demo-cleaning)：展示第 3 步实时进度条、逐行状态徽标与日志流，未改动真实磁盘。";
                d["DemoVerifiedBanner"] = "核验清零演示模式 (--demo-verified)：展示清理完成并核验清零后的结果横幅与台账状态，未改动真实磁盘。";
                d["NavBannerScanClean"] = "视图 1 · 扫描与清理工作台：勾选目标范围 -> 1. 立即扫描体检 -> 2. 预览清理方案 (SHA-256) -> 3. 一键安全清理 -> 4. 自动核验清零。";
                d["NavBannerReports"] = "视图 2 · 审计与报告中心：只读汇总 AUDIT.md、CLEANUP-PLAN.md 与 VERIFICATION.md，支持系统弹窗另存为导出与目录访问。";
                d["NavBannerSafety"] = "视图 3 · 安全边界与关于：查看非破坏性白名单架构、Windows OS 保护红线与独立 MIT 开源许可声明。";
                d["ReportsViewTitle"] = "审计与报告中心";
                d["ReportsViewSub"] = "只读读取工作区内的 AUDIT.md、CLEANUP-PLAN.md 与 VERIFICATION.md 报告摘要，可一键通过 SaveFileDialog 另存为导出。";
                d["BtnRefreshReports"] = "刷新报告摘要";
                d["ReportAuditTitle"] = "AUDIT.md — 只读环境与残余审计报告";
                d["ReportPlanTitle"] = "CLEANUP-PLAN.md — 确定性清理方案清单 (SchemaVersion = 3)";
                d["ReportVerifyTitle"] = "VERIFICATION.md — 核验结果与原子执行台账";
                d["ReportMissing"] = "尚未生成该报告文件。请先在“1. 扫描与清理”中运行扫描、方案预览或清理核验。";
                d["BtnSaveAs"] = "另存为...";
                d["BtnOpenFile"] = "打开文件";
                d["SaveReportSuccess"] = "报告已保存至：\r\n{0}";
                d["SafetyViewTitle"] = "安全架构、OS 保护红线与关于";
                d["SafetyViewSubtitle"] = "本桌面端仅作为展示与编排界面，所有检测与清理均严格委托给唯一后端引擎 ClaudeCleanup.ps1。";
                d["SafetyCard1Title"] = "1. 非破坏性白名单架构与双阶段确认锁";
                d["SafetyCard1Body"] = "程序启动零改动，默认 100% 只读审计。清理按钮默认禁用，必须先完成只读扫描并生成包含 Ready 项的 64 位 SHA-256 方案后才会解锁，且执行前强制执行 -WhatIf 预览并弹出完整路径清单二次确认。";
                d["SafetyCard2Title"] = "2. Windows OS 保护红线与 Win32 句柄安全引擎";
                d["SafetyCard2Body"] = "严禁改动 Windows 系统文件、Program Files、WSL 分发、浏览器站点配置、硬件设备 ID 或远端账号状态；拒绝符号链接/联接点与跨所有者目录，通过 Win32 句柄与 NtDeleteKey 精准删除白名单项目，绝不回退到路径递归删除。";
                d["SafetyCard3Title"] = "3. 隐私边界与只读 UUID/凭据核查";
                d["SafetyCard3Body"] = "账号 ID 卡片仅读取非敏感 UUID 元数据（accountUuid / organizationUuid / deviceId）；Windows 凭据管理器仅报告 Claude* 目标计数，环境变量仅报告变量名称，绝不读取或外传 OAuth Token、API Key 或密钥原文。";
                d["SafetyCard4Title"] = "4. 版本与独立 MIT 开源许可声明";
                d["SafetyCard4Body"] = "产品名称：Claude Residual ID Cleaner (Claude 账号残余 ID 清理工具) v0.1.0\r\n运行架构：.NET Framework 4.x 原生 WPF 零控制台桌面端 (IMAGE_SUBSYSTEM_WINDOWS_GUI)\r\n开源许可：MIT License（独立开源项目，Copyright (c) 2026 Claude Residual ID Cleaner）\r\n项目仓库：https://github.com/YUCZ-43/Claude-Residual-ID-Cleaner";
                d["PrivilegeStandard"] = "标准权限";
                d["PrivilegeAdmin"] = "管理员权限";
                d["BtnRestartAdmin"] = "以管理员身份重启";
                d["RestartAdminTitle"] = "按需管理员提权确认";
                d["RestartAdminPrompt"] = "当前用户目录下的 Claude 残余清理无需管理员权限。\r\n\r\n仅当需要清理机器级注册表、系统级安装或权限受限项时才需要管理员权限。\r\n确定要触发 Windows UAC 并以管理员身份重启本程序吗？";
                d["RestartAdminFailed"] = "未完成管理员提权重启（已取消或被系统拦截）：{0}";
                d["ElevationHintFullRemoval"] = "提示：当前为标准权限，个人目录清理无需提权；若需处理系统级受保护残余，可按需点击右上角“以管理员身份重启”。";
                d["BtnBackToWorkspace"] = "返回扫描与清理工作台";
                d["FooterBoundary"] = "安全边界：仅限白名单 Claude 残余 · 绝不改动 Windows 系统";
                d["DemoPlanNotice"] = "当前处于演示模式，仅展示只读模拟清单，不会写入真实 CLEANUP-PLAN.md 或执行删除。";
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
                d["StatusApplying"] = "正在执行实时安全清理（已验证 SHA-256 与用户确认）...";
                d["StatusVerifying"] = "正在复核清理后残余与 VERIFICATION.md 台账...";
                d["StatusVerified"] = "核验完成：已复查 {0} 项清单目标，当前残留可清理项 {1} 条。";
                d["StatusExported"] = "已导出脱敏只读审计报告: {0}";
                d["SaveDialogTitle"] = "导出只读审计报告 (AUDIT.md)";
                d["SaveDialogFilter"] = "Markdown 文档 (*.md)|*.md|所有文件 (*.*)|*.*";
                d["ExportSuccessTitle"] = "导出完成";
                d["ExportSuccessAskOpen"] = "报告已保存至：\r\n{0}\r\n\r\n是否立即打开查看？";
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
                d["ClaudeRunningPromptBody"] = "检测到以下 Claude 进程仍在后台运行（已排除本清理工具自身）：\r\n{0}\r\n\r\n是否由本工具立即关闭这些进程并继续执行安全清理？";
                d["VsCodeRunningTitle"] = "检测到 VS Code 仍在运行";
                d["VsCodeRunningBody"] = "检测到 VS Code 仍在运行，为避免扩展残留删除失败，请先彻底关闭所有 VS Code 窗口后重试。";
                d["FoundLabel"] = "已发现";
                d["ExcludedLabel"] = "需切换至完整清理";
                d["CleanLabel"] = "无残留";
                d["RowCleaningLabel"] = "清理中...";
                d["RowClearedLabel"] = "已彻底清除";
                d["RowLockedLabel"] = "被占用跳过";
                d["ProtectedLabel"] = "安全红线受保护";
                d["ReviewLabel"] = "需人工复核";
                d["ReadOnlyLabel"] = "只读核查";
                d["PartialFailureTitle"] = "部分清理完成（部分文件被占用）";
                d["PartialFailureBody"] =
                    "已完成大部分清理（已移除 {0} 项），但有 {1} 项因文件被其他进程占用或权限受限而暂未删除。\r\n\r\n" +
                    "已成功清理：\r\n{2}\r\n\r\n" +
                    "仍被占用或未执行（请关闭相关程序或浏览器后重新扫描清理）：\r\n{3}";
                d["SplashSubtitle"] = "正在初始化安全检测引擎...";
                d["ExecReportTitle"] = "清理完成详情报告";
                d["ExecReportSubtitle"] = "安全清理执行结果明细与账号残余核验摘要";
                d["ExecReportAccountCleared"] = "账号 / 组织 ID 残留：0（已彻底清除）";
                d["ExecReportAccountRemaining"] = "仍检测到 {0} 项账号 / 组织 ID 残留（请参考下方占用提示）";
                d["ExecReportStatCleaned"] = "已清理项目";
                d["ExecReportStatFreed"] = "释放磁盘空间";
                d["ExecReportStatLocked"] = "被占用 / 跳过";
                d["ExecReportCleanedSection"] = "已彻底清除项目 ({0})";
                d["ExecReportLockedSection"] = "仍被占用或跳过项 ({0})";
                d["ExecReportNoneCleaned"] = "本次未移除任何新文件。";
                d["ExecReportNoneLocked"] = "无被占用或跳过项 — 所有已选目标均已验证清除。";
                d["ExecReportLockedAdvice"] = "处理建议：请关闭仍在运行的相关应用（如 Chrome、Edge 浏览器或系统托盘里的 Claude），然后点击“1. 立即扫描体检”重新清理该项。";
                d["ExecReportBtnCopy"] = "复制详情报告";
                d["ExecReportBtnCopied"] = "已复制报告";
                d["ExecReportBtnExport"] = "导出报告文件 (.md)";
                d["ExecReportBtnClose"] = "关闭";
                d["ExecReportExportTitle"] = "导出清理完成详情报告 (.md)";
                d["View2LatestCleanupHeader"] = "[最新本次清理结果] 已清理 {0} 项 | 释放 {1} | 被占用 {2} 项 | 账号 ID 残留 {3}";
            }
            else
            {
                d["AppTitle"] = "Claude Residual ID Cleaner (Claude 账号残余 ID 清理工具) v0.1.0";
                d["BrandName"] = "Claude Residual ID Cleaner";
                d["HeaderTitle"] = "Claude Residual ID Cleaner";
                d["VersionBadge"] = "v0.1.0 · Native WPF Studio";
                d["SafetyPill"] = "Cleans Claude Banned-Account Residuals Only · Never Alters Windows OS";
                d["Positioning"] = "Purpose-built to clean residual account/device IDs, auth tokens, and session caches left behind after a Claude ban — strictly without altering Windows OS itself.";
                d["LangButton"] = "简体中文 / English";
                d["AboutButton"] = "Safety & About";
                d["AboutTitle"] = "About & Safety Boundaries";
                d["AboutBody"] =
                    "Claude Residual ID Cleaner\r\n\r\n" +
                    "Repository: https://github.com/YUCZ-43/Claude-Residual-ID-Cleaner\r\n" +
                    "License: MIT License (Independent Open-Source Project)\r\n" +
                    "Positioning: Purpose-built to clean residual local account/device IDs, auth tokens, and session caches left behind after a Claude account ban — strictly without altering Windows OS itself.\r\n\r\n" +
                    "Security Guarantees:\r\n" +
                    "1. Zero changes on startup; scanning is 100% read-only;\r\n" +
                    "2. Cleanup delegates exclusively to ClaudeCleanup.ps1 allowlists and Win32 handle-bound deletion;\r\n" +
                    "3. Never alters Windows OS files, WSL, browser profiles, OS hardware IDs, or remote server state;\r\n" +
                    "4. Credential Manager and env vars report counts/names only — secret values are never read.";
                d["SidebarSectionTitle"] = "VIEWS";
                d["NavScanClean"] = "1. Scan & Clean";
                d["NavReports"] = "2. Reports & Export";
                d["NavSafety"] = "3. Safety & About";
                d["SidebarGuardTitle"] = "Engine Guardrail";
                d["SidebarGuardBody"] = "Delegates to ClaudeCleanup.ps1\r\nRead-only default · Handle-bound · Never Alters Windows OS";
                d["PolicyPillPrefix"] = "Policy: ";
                d["PolicyAccountShort"] = "AccountData";
                d["PolicyFullShort"] = "FullRemoval";
                d["MetricScannedTitle"] = "Scanned Targets";
                d["MetricScannedSub"] = "Allowlisted engine probes";
                d["MetricFoundTitle"] = "Remaining Residuals";
                d["MetricFoundSub"] = "Active cleanable or review items";
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
                d["PlanGateLockedPill"] = "Gate Locked · Scan & Preview Plan First";
                d["PlanGateReadyPill"] = "Armed · Ready={0} · SHA256={1}...";
                d["CleaningProgressTitle"] = "Real-Time Safe Cleanup in Progress...";
                d["CleaningProgressBanner"] = "Cleaning item {0}/{1}: {2}...";
                d["CompletionBannerTitleOk"] = "Cleanup & Verification Complete! Safely cleared {0} residual(s) — 0 remaining";
                d["CompletionBannerSubOk"] = "VERIFICATION.md execution ledger committed atomically; Windows OS and unrelated configs 100% untouched.";
                d["CompletionBannerTitlePartial"] = "Partial Cleanup Complete: cleared {0} item(s), {1} locked or remaining";
                d["CompletionBannerSubPartial"] = "Close any locking Claude/browser processes, then re-scan and clean remaining items.";
                d["LogDrawerTitle"] = "Live Execution Log · ClaudeCleanup.ps1 Output (Drag splitter above to resize)";
                d["GridEmptyHint"] = "No scan run yet — click '1. Scan Residuals' to perform a read-only audit.";
                d["DemoBanner"] = "Demo Audit Mode (--demo-audit): Displaying sanitized mock residuals & Account UUIDs; zero host disk reads or mutations.";
                d["DemoCleaningBanner"] = "Demo Cleaning Mode (--demo-cleaning): Showing Step 3 live progress bar, per-row badges, and streaming logs; zero disk mutations.";
                d["DemoVerifiedBanner"] = "Demo Verified Mode (--demo-verified): Showing post-cleanup 0-remaining completion banner and ledger summary; zero disk mutations.";
                d["NavBannerScanClean"] = "View 1 · Scan & Clean Workspace: Select scope -> 1. Scan Residuals -> 2. Preview Plan (SHA-256) -> 3. Clean Selected -> 4. Auto Verify.";
                d["NavBannerReports"] = "View 2 · Reports & Export: Inspect read-only AUDIT.md, CLEANUP-PLAN.md, and VERIFICATION.md summaries and export via Save As.";
                d["NavBannerSafety"] = "View 3 · Safety & About: Review non-destructive allowlist architecture, Windows OS red lines, and independent MIT license notice.";
                d["ReportsViewTitle"] = "Reports & Export Center";
                d["ReportsViewSub"] = "Read-only summary of AUDIT.md, CLEANUP-PLAN.md, and VERIFICATION.md in the workspace, with one-click SaveFileDialog export.";
                d["BtnRefreshReports"] = "Refresh Summaries";
                d["ReportAuditTitle"] = "AUDIT.md — Read-Only Audit Report";
                d["ReportPlanTitle"] = "CLEANUP-PLAN.md — Deterministic Plan Manifest (SchemaVersion = 3)";
                d["ReportVerifyTitle"] = "VERIFICATION.md — Verification & Execution Ledger";
                d["ReportMissing"] = "Report file not generated yet. Run Scan, Preview Plan, or Clean/Verify in '1. Scan & Clean'.";
                d["BtnSaveAs"] = "Save As...";
                d["BtnOpenFile"] = "Open File";
                d["SaveReportSuccess"] = "Report saved cleanly to:\r\n{0}";
                d["SafetyViewTitle"] = "Security Architecture, OS Red Lines & About";
                d["SafetyViewSubtitle"] = "This desktop app is a pure presentation shell; all discovery and cleanup run out-of-process inside ClaudeCleanup.ps1.";
                d["SafetyCard1Title"] = "1. Non-Destructive Allowlist & Two-Stage Lock";
                d["SafetyCard1Body"] = "Zero changes on startup; 100% read-only audit by default. Clean button stays disabled until read-only audit + Ready 64-hex SHA-256 plan exist, followed by -WhatIf preview and explicit path confirmation.";
                d["SafetyCard2Title"] = "2. Windows OS Red Lines & Win32 Handle Engine";
                d["SafetyCard2Body"] = "Never alters Windows OS files, Program Files, WSL distributions, browser profiles, OS hardware IDs, or remote server state. Rejects reparse points/mixed owners and deletes strictly via Win32 handles and NtDeleteKey with zero Remove-Item fallback.";
                d["SafetyCard3Title"] = "3. Privacy Boundary & Non-Secret UUID Inspection";
                d["SafetyCard3Body"] = "Account ID card reads non-secret UUID metadata only; Credential Manager reports counts only, env vars emit names only — OAuth tokens, API keys, and secrets are never read.";
                d["SafetyCard4Title"] = "4. Version & Independent MIT License Notice";
                d["SafetyCard4Body"] = "Product: Claude Residual ID Cleaner v0.1.0\r\nRuntime: Native .NET Framework 4.x WPF Zero-Console App (IMAGE_SUBSYSTEM_WINDOWS_GUI)\r\nLicense: MIT License (Independent Open-Source Project, Copyright (c) 2026 Claude Residual ID Cleaner)\r\nRepository: https://github.com/YUCZ-43/Claude-Residual-ID-Cleaner";
                d["PrivilegeStandard"] = "Standard User";
                d["PrivilegeAdmin"] = "Administrator";
                d["BtnRestartAdmin"] = "Restart as Admin";
                d["RestartAdminTitle"] = "On-Demand Administrator Elevation";
                d["RestartAdminPrompt"] = "Standard user-profile Claude residual cleanup works without Administrator privileges.\r\n\r\nOnly machine-wide items or ACL-protected residuals require elevation.\r\nTrigger Windows UAC and restart this app as Administrator now?";
                d["RestartAdminFailed"] = "Administrator restart did not complete (cancelled or blocked): {0}";
                d["ElevationHintFullRemoval"] = "Tip: Running as Standard User. User-profile cleanup needs no elevation; click 'Restart as Admin' only if machine-level residuals require it.";
                d["BtnBackToWorkspace"] = "Back to Scan & Clean";
                d["FooterBoundary"] = "Boundary: Allowlisted Claude residuals only · Never Alters Windows OS";
                d["DemoPlanNotice"] = "Demo mode active: simulates read-only discovery only; no real CLEANUP-PLAN.md write or deletion.";
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
                d["StatusApplying"] = "Running real-time allowlisted cleanup (SHA-256 verified & user confirmed)...";
                d["StatusVerifying"] = "Verifying residual state & VERIFICATION.md ledger...";
                d["StatusVerified"] = "Verification complete: {0} plan record(s) checked, {1} remaining cleanable item(s).";
                d["StatusExported"] = "Exported sanitized audit report: {0}";
                d["SaveDialogTitle"] = "Save Sanitized Audit Report (AUDIT.md)";
                d["SaveDialogFilter"] = "Markdown (*.md)|*.md|All Files (*.*)|*.*";
                d["ExportSuccessTitle"] = "Export Complete";
                d["ExportSuccessAskOpen"] = "Report saved cleanly to:\r\n{0}\r\n\r\nOpen the exported file now?";
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
                d["ClaudeRunningPromptBody"] = "The following Claude processes are still running in the background (excluding this cleaner):\r\n{0}\r\n\r\nWould you like this tool to close them now and continue cleaning?";
                d["VsCodeRunningTitle"] = "VS Code Is Still Running";
                d["VsCodeRunningBody"] = "VS Code is currently running. Please close all VS Code windows completely before removing its Claude extension and retry.";
                d["FoundLabel"] = "Found";
                d["ExcludedLabel"] = "FullRemoval Scope";
                d["CleanLabel"] = "Clean";
                d["RowCleaningLabel"] = "Cleaning...";
                d["RowClearedLabel"] = "Cleared";
                d["RowLockedLabel"] = "Locked / Skipped";
                d["ProtectedLabel"] = "OS Protected";
                d["ReviewLabel"] = "Needs Review";
                d["ReadOnlyLabel"] = "Read-Only Audit";
                d["PartialFailureTitle"] = "Partial Cleanup Completed (Some Files Locked)";
                d["PartialFailureBody"] =
                    "Most residuals were cleaned ({0} removed), while {1} item(s) could not be deleted due to active file locks or access constraints.\r\n\r\n" +
                    "Cleaned items:\r\n{2}\r\n\r\n" +
                    "Locked or remaining items (close the locking app/browser, then re-scan and clean):\r\n{3}";
                d["SplashSubtitle"] = "Initializing Security Audit Engine...";
                d["ExecReportTitle"] = "Cleanup Execution Report";
                d["ExecReportSubtitle"] = "Detailed Cleanup Breakdown & Post-Clean Residual Account Verification";
                d["ExecReportAccountCleared"] = "Account / Org ID Residuals: 0 (Completely Cleared)";
                d["ExecReportAccountRemaining"] = "{0} Account / Org ID Residual(s) Still Detected (See Locked Items Below)";
                d["ExecReportStatCleaned"] = "Cleaned Items";
                d["ExecReportStatFreed"] = "Space Freed";
                d["ExecReportStatLocked"] = "Locked / Skipped";
                d["ExecReportCleanedSection"] = "Cleaned Items ({0})";
                d["ExecReportLockedSection"] = "Locked or Skipped Items ({0})";
                d["ExecReportNoneCleaned"] = "No items were removed in this run.";
                d["ExecReportNoneLocked"] = "No locked or skipped items — all selected targets verified absent.";
                d["ExecReportLockedAdvice"] = "Advice: Close the locking application (such as Chrome, Edge, or Claude in the system tray), then re-scan and clean.";
                d["ExecReportBtnCopy"] = "Copy Report";
                d["ExecReportBtnCopied"] = "Copied";
                d["ExecReportBtnExport"] = "Export Report (.md)";
                d["ExecReportBtnClose"] = "Close";
                d["ExecReportExportTitle"] = "Export Cleanup Execution Report (.md)";
                d["View2LatestCleanupHeader"] = "[Latest Cleanup Summary] Cleaned: {0} | Freed: {1} | Locked: {2} | Remaining Account IDs: {3}";
            }
            return d;
        }
    }
}
