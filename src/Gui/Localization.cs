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
                d["HeaderTitle"] = "Claude 账号残余 ID 清理工具 (Claude Residual ID Cleaner)";
                d["VersionBadge"] = "v1.0 · 原生 WPF 独立桌面版";
                d["SafetyPill"] = "仅清理 Claude 封号残余数据 · 绝不改动 Windows 系统";
                d["Positioning"] = "专为清理 Claude 封号后残留在设备中的账号/设备 ID、认证 Token 与会话缓存而设计，绝不改动 Windows 系统本身。";
                d["LangButton"] = "中文 / English (当前: 简体中文)";
                d["AboutButton"] = "关于与安全承诺";
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
                d["ScopeHeader"] = "扫描与清理目标范围 (基于核心引擎严格白名单)";
                d["ChkCli"] = "1. Claude Code CLI 配置与设备/账号 ID (~/.claude, .claude.json, npm/global state)";
                d["ChkDesktop"] = "2. Claude Desktop 客户端会话与本地存储 (%APPDATA%\\Claude, %LOCALAPPDATA%\\Claude)";
                d["ChkVsCode"] = "3. VS Code / Cursor 扩展残余缓存 (globalStorage / workspaceStorage Claude entries)";
                d["ChkCred"] = "4. Windows 凭据管理器中的 Claude 登录凭据 (Credential Manager Claude targets · 只读计数)";
                d["ChkEnv"] = "5. Claude 相关用户环境变量 (ANTHROPIC_* / CLAUDE_* user env vars · 仅报名称)";
                d["PolicyHeader"] = "清理策略";
                d["PolicyAccount"] = "AccountData (清除登录/设备缓存与日志，保留 .claude 自建配置)";
                d["PolicyFull"] = "FullRemoval (彻底移除用户级 Claude 客户端、扩展、配置与注册项)";
                d["BtnScan"] = "1. 立即扫描体检";
                d["BtnPlan"] = "2. 预览清理方案";
                d["BtnClean"] = "3. 一键安全清理";
                d["BtnVerify"] = "4. 清理结果核验";
                d["BtnOpenFolder"] = "打开报告目录";
                d["BtnExportSummary"] = "导出诊断摘要 (AUDIT.md)";
                d["ColSelect"] = "选择";
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
                d["FoundLabel"] = "已发现";
                d["CleanLabel"] = "无残留";
                d["ProtectedLabel"] = "受保护/跳过";
                d["ReadOnlyLabel"] = "只读核查";
            }
            else
            {
                d["AppTitle"] = "Claude Residual ID Cleaner (Claude 账号残余 ID 清理工具) v1.0";
                d["HeaderTitle"] = "Claude Residual ID Cleaner (Claude 账号残余 ID 清理工具)";
                d["VersionBadge"] = "v1.0 · Native WPF Desktop App";
                d["SafetyPill"] = "Cleans Claude Banned-Account Residuals Only · Never Alters Windows OS";
                d["Positioning"] = "Purpose-built to clean residual account/device IDs, auth tokens, and session caches left behind after a Claude ban — strictly without altering Windows OS itself.";
                d["LangButton"] = "中文 / English (Active: English)";
                d["AboutButton"] = "About & Safety";
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
                d["ScopeHeader"] = "Scan & Cleanup Target Scope (Guarded by ClaudeCleanup.ps1 Allowlist)";
                d["ChkCli"] = "1. Claude Code CLI Configs & Account/Device IDs (~/.claude, .claude.json, npm/global state)";
                d["ChkDesktop"] = "2. Claude Desktop Session & Local Storage (%APPDATA%\\Claude, %LOCALAPPDATA%\\Claude)";
                d["ChkVsCode"] = "3. VS Code / Cursor Extension Residual Caches (globalStorage / workspaceStorage Claude entries)";
                d["ChkCred"] = "4. Windows Credential Manager Claude Logins (Credential Manager Claude targets · Read-only count)";
                d["ChkEnv"] = "5. Claude User Environment Variables (ANTHROPIC_* / CLAUDE_* user env vars · Names only)";
                d["PolicyHeader"] = "Cleanup Policy";
                d["PolicyAccount"] = "AccountData (Clears auth tokens, device metadata caches & logs; keeps .claude files)";
                d["PolicyFull"] = "FullRemoval (Removes user-level Claude apps, extensions, configs & host keys)";
                d["BtnScan"] = "1. Scan Residuals";
                d["BtnPlan"] = "2. Preview Plan";
                d["BtnClean"] = "3. Clean Selected";
                d["BtnVerify"] = "4. Verify Clean";
                d["BtnOpenFolder"] = "Open Reports Folder";
                d["BtnExportSummary"] = "Export Summary (AUDIT.md)";
                d["ColSelect"] = "Select";
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
                d["FoundLabel"] = "Found";
                d["CleanLabel"] = "Clean";
                d["ProtectedLabel"] = "Protected / Skipped";
                d["ReadOnlyLabel"] = "Read-Only Audit";
            }
            return d;
        }
    }
}
