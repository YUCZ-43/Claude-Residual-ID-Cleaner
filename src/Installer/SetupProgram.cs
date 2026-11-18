using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;

namespace ClaudeResidualIdCleanerSetup
{
    internal sealed class SetupInstallManifest
    {
        public int SchemaVersion { get; set; }
        public string Product { get; set; }
        public string Version { get; set; }
        public string InstalledBy { get; set; }
        public string InstalledUtc { get; set; }
        public string InstallRoot { get; set; }
        public string UninstallRegistryHive { get; set; }
        public string UninstallRegistrySubKey { get; set; }
        public List<string> ManagedFiles { get; set; }
        public List<string> ShortcutFiles { get; set; }
    }

    internal sealed class SetupOperationResult
    {
        public bool Succeeded { get; set; }
        public string Mode { get; set; }
        public string InstallRoot { get; set; }
        public int InstalledFileCount { get; set; }
        public int RemovedFileCount { get; set; }
        public bool HasWindowIcon { get; set; }
        public bool IsElevated { get; set; }
        public bool DryRun { get; set; }
        public string RegistryHive { get; set; }
        public string RegistrySubKey { get; set; }
        public string UninstallString { get; set; }
        public string DisplayIcon { get; set; }
        public string Message { get; set; }
    }

    internal static class SetupLocalization
    {
        public static string DetectDefaultLanguage()
        {
            return "zh-CN";
        }

        public static Dictionary<string, string> GetStrings(string lang)
        {
            var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            bool zh = string.Equals(lang, "zh-CN", StringComparison.OrdinalIgnoreCase);
            if (zh)
            {
                d["Title"] = "Claude Residual ID Cleaner 安装向导 — Claude 账号残余 ID 清理工具";
                d["UninstallTitle"] = "Claude Residual ID Cleaner 卸载向导 — Claude 账号残余 ID 清理工具";
                d["HeaderSub"] = "仅安装 Claude Residual ID Cleaner 工具包 · 绝不改动 Claude 本地数据或 Windows 系统";
                d["SafetyPill"] = "标准安全向导 · 支持用户目录免提权安装";
                d["PrivStandard"] = "标准权限";
                d["PrivAdmin"] = "管理员权限";
                d["LangBtn"] = "简体中文 / English";
                d["PathLabel"] = "目标安装目录:";
                d["BrowseBtn"] = "浏览...";
                d["ChkDesktop"] = "创建桌面快捷方式 (Claude Residual ID Cleaner.lnk)";
                d["ChkStartMenu"] = "创建开始菜单快捷方式与卸载入口";
                d["ChkRegisterArp"] = "注册 Windows“应用和功能”卸载项 (Add/Remove Programs)";
                d["ChkLaunchAfter"] = "安装完成后立即启动 Claude Residual ID Cleaner";
                d["BtnInstall"] = "立即安装";
                d["BtnUninstall"] = "确认卸载工具包";
                d["BtnClose"] = "关闭";
                d["StatusReady"] = "就绪：请选择安装目录并点击“立即安装”。";
                d["StatusUninstallReady"] = "就绪：将仅卸载 Claude Residual ID Cleaner 程序文件与快捷方式（保留用户审计报告及所有 Claude 数据）。";
                d["StatusInstalling"] = "正在校验路径并解压工具包...";
                d["StatusUninstalling"] = "正在卸载托管文件与注册表卸载项...";
                d["StatusDoneInstall"] = "安装成功！工具已安装至: {0}";
                d["StatusDoneUninstall"] = "卸载完成：已移除 {0} 个托管文件。";
                d["BrowseDesc"] = "选择 Claude Residual ID Cleaner 安装目录（工具将安装至该目录）";
                d["ScopeNote"] = "说明：默认安装至当前用户本地目录（无需管理员权限）；若以管理员运行，默认安装至 Program Files 并注册全局卸载项。";
            }
            else
            {
                d["Title"] = "Claude Residual ID Cleaner Setup Wizard";
                d["UninstallTitle"] = "Claude Residual ID Cleaner Uninstaller";
                d["HeaderSub"] = "Installs Claude Residual ID Cleaner toolkit only · Never alters Claude data or Windows OS";
                d["SafetyPill"] = "Safe Setup · User-Scope Install Without UAC";
                d["PrivStandard"] = "Standard User";
                d["PrivAdmin"] = "Administrator";
                d["LangBtn"] = "简体中文 / English";
                d["PathLabel"] = "Destination Folder:";
                d["BrowseBtn"] = "Browse...";
                d["ChkDesktop"] = "Create Desktop shortcut (Claude Residual ID Cleaner.lnk)";
                d["ChkStartMenu"] = "Create Start Menu shortcuts and uninstaller entry";
                d["ChkRegisterArp"] = "Register in Windows Installed Apps (Add/Remove Programs)";
                d["ChkLaunchAfter"] = "Launch Claude Residual ID Cleaner after installation";
                d["BtnInstall"] = "Install";
                d["BtnUninstall"] = "Uninstall Toolkit";
                d["BtnClose"] = "Close";
                d["StatusReady"] = "Ready: Review destination folder and click Install.";
                d["StatusUninstallReady"] = "Ready: Removes only Claude Residual ID Cleaner managed files & shortcuts (preserves reports and all Claude data).";
                d["StatusInstalling"] = "Validating destination path and extracting toolkit payload...";
                d["StatusUninstalling"] = "Removing managed files and Add/Remove Programs entry...";
                d["StatusDoneInstall"] = "Installation complete! Installed cleanly to: {0}";
                d["StatusDoneUninstall"] = "Uninstall complete: removed {0} managed file(s).";
                d["BrowseDesc"] = "Select installation folder for Claude Residual ID Cleaner";
                d["ScopeNote"] = "Note: Standard users install under %LOCALAPPDATA%\\Programs without UAC; running as Administrator defaults to Program Files.";
            }
            return d;
        }
    }

    internal static class SetupEngine
    {
        internal const string ManifestFileName = ".claude-cleanup-install.json";
        internal const string UninstallSubKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\Claude-Residual-ID-Cleaner";
        internal const string PayloadResourceName = "ClaudeResidualIdCleanerSetup.payload.zip";
        internal const string IconResourceName = "ClaudeResidualIdCleanerSetup.app.ico";

        public static bool IsElevated()
        {
            try
            {
                using (WindowsIdentity id = WindowsIdentity.GetCurrent())
                {
                    if (id == null) return false;
                    return new WindowsPrincipal(id).IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
            catch
            {
                return false;
            }
        }

        public static string GetDefaultInstallRoot(bool elevated)
        {
            if (elevated)
            {
                string pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
                if (!string.IsNullOrEmpty(pf))
                {
                    return Path.Combine(pf, "Claude-Residual-ID-Cleaner");
                }
            }
            string localApp = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            return Path.Combine(localApp, @"Programs\Claude-Residual-ID-Cleaner");
        }

        public static string ValidateSafeInstallRoot(string rawPath)
        {
            if (string.IsNullOrWhiteSpace(rawPath))
            {
                throw new InvalidOperationException("Install path cannot be empty.");
            }
            string trimmed = rawPath.Trim();
            if (trimmed.Length >= 2 && trimmed.Substring(2).Contains(":"))
            {
                throw new InvalidOperationException("Install path contains invalid colon / alternate data stream syntax.");
            }
            if (trimmed.IndexOf('?') >= 0 || trimmed.IndexOf('*') >= 0)
            {
                throw new InvalidOperationException("Install path contains invalid wildcard characters.");
            }

            string full = Path.GetFullPath(trimmed);
            string root = Path.GetPathRoot(full);
            if (full.Length > root.Length)
            {
                full = full.TrimEnd('\\', '/');
            }
            if (string.Equals(full, root.TrimEnd('\\', '/'), StringComparison.OrdinalIgnoreCase) ||
                string.Equals(full, root, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Refusing drive root as install destination: " + full);
            }

            string[] segs = full.Substring(root.Length).Split(new char[] { '\\', '/' }, StringSplitOptions.RemoveEmptyEntries);
            for (int i = 0; i < segs.Length; i++)
            {
                if (segs[i].EndsWith(" ") || segs[i].EndsWith("."))
                {
                    throw new InvalidOperationException("Install path segment has unsafe trailing space or dot.");
                }
            }

            string winDir = Environment.GetEnvironmentVariable("WINDIR");
            string userProfile = Environment.GetEnvironmentVariable("USERPROFILE");
            string appData = Environment.GetEnvironmentVariable("APPDATA");
            string localApp = Environment.GetEnvironmentVariable("LOCALAPPDATA");
            string progFiles = Environment.GetEnvironmentVariable("ProgramFiles");
            string progFilesX86 = Environment.GetEnvironmentVariable("ProgramFiles(x86)");

            if (!string.IsNullOrEmpty(winDir) && IsPathWithin(full, winDir))
            {
                throw new InvalidOperationException("Refusing Windows OS directory as install destination.");
            }

            string[] exactForbidden = new string[] { userProfile, appData, localApp, progFiles, progFilesX86 };
            for (int i = 0; i < exactForbidden.Length; i++)
            {
                if (!string.IsNullOrEmpty(exactForbidden[i]))
                {
                    string norm = Path.GetFullPath(exactForbidden[i]).TrimEnd('\\', '/');
                    if (string.Equals(full, norm, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException("Refusing exact system/profile root as install destination: " + full);
                    }
                }
            }

            if (!string.IsNullOrEmpty(userProfile))
            {
                string[] agentRoots = new string[] { ".codex", ".gemini", ".agents", ".claude" };
                for (int i = 0; i < agentRoots.Length; i++)
                {
                    string agentDir = Path.Combine(userProfile, agentRoots[i]);
                    if (IsPathWithin(full, agentDir))
                    {
                        throw new InvalidOperationException("Refusing agent/Claude state folder as install destination: " + full);
                    }
                }
            }

            AssertNoReparsePointAncestors(full);
            return full;
        }

        private static bool IsPathWithin(string candidate, string baseDir)
        {
            string c = Path.GetFullPath(candidate).TrimEnd('\\', '/');
            string b = Path.GetFullPath(baseDir).TrimEnd('\\', '/');
            if (string.Equals(c, b, StringComparison.OrdinalIgnoreCase)) return true;
            return c.StartsWith(b + "\\", StringComparison.OrdinalIgnoreCase);
        }

        private static void AssertNoReparsePointAncestors(string fullPath)
        {
            string current = fullPath;
            string root = Path.GetPathRoot(current);
            while (!string.IsNullOrEmpty(current) && !string.Equals(current, root, StringComparison.OrdinalIgnoreCase))
            {
                if (Directory.Exists(current) || File.Exists(current))
                {
                    FileAttributes attrs = File.GetAttributes(current);
                    if ((attrs & FileAttributes.ReparsePoint) != 0)
                    {
                        throw new InvalidOperationException("Reparse point detected in destination path: " + current);
                    }
                }
                string parent = Path.GetDirectoryName(current);
                if (string.IsNullOrEmpty(parent) || string.Equals(parent, current, StringComparison.OrdinalIgnoreCase)) break;
                current = parent;
            }
        }

        public static SetupOperationResult ExecuteInstall(
            string targetInstallRoot,
            bool createDesktopShortcut,
            bool createStartMenuShortcut,
            bool registerAddRemove,
            bool dryRun,
            bool skipRegistry,
            bool skipShortcuts,
            string desktopDirOverride,
            string startMenuDirOverride,
            string regOutJsonPath,
            Action<string> logger)
        {
            string resolvedRoot = ValidateSafeInstallRoot(targetInstallRoot);
            bool elevated = IsElevated();
            string hiveName = elevated ? "HKLM" : "HKCU";
            string setupExeDestination = Path.Combine(resolvedRoot, "Claude-Residual-ID-Cleaner-Setup.exe");
            string mainExeDestination = Path.Combine(resolvedRoot, "Claude-Residual-ID-Cleaner.exe");
            string uninstallCmd = string.Format("\"{0}\" --uninstall --install-dir \"{1}\"", setupExeDestination, resolvedRoot);
            string displayIcon = string.Format("{0},0", mainExeDestination);

            var managedFiles = new List<string>();
            var shortcutFiles = new List<string>();

            Stream payloadStream = Assembly.GetExecutingAssembly().GetManifestResourceStream(PayloadResourceName);
            if (payloadStream == null)
            {
                throw new InvalidOperationException("Embedded payload resource missing: " + PayloadResourceName);
            }

            using (payloadStream)
            using (var archive = new ZipArchive(payloadStream, ZipArchiveMode.Read))
            {
                if (!dryRun)
                {
                    Directory.CreateDirectory(resolvedRoot);
                }

                string rootPrefix = resolvedRoot.TrimEnd('\\', '/') + Path.DirectorySeparatorChar;
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    if (string.IsNullOrEmpty(entry.Name))
                    {
                        continue;
                    }
                    string normalizedRel = entry.FullName.Replace('/', Path.DirectorySeparatorChar).TrimStart('\\');
                    string destPath = Path.GetFullPath(Path.Combine(resolvedRoot, normalizedRel));
                    if (!destPath.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidOperationException("Refusing unsafe zip entry traversal: " + entry.FullName);
                    }

                    managedFiles.Add(normalizedRel);
                    if (!dryRun)
                    {
                        string destDir = Path.GetDirectoryName(destPath);
                        if (!string.IsNullOrEmpty(destDir))
                        {
                            Directory.CreateDirectory(destDir);
                        }
                        using (Stream entryStream = entry.Open())
                        using (FileStream fs = new FileStream(destPath, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            entryStream.CopyTo(fs);
                        }
                    }
                }

                if (!dryRun)
                {
                    string selfPath = Assembly.GetExecutingAssembly().Location;
                    if (!string.IsNullOrEmpty(selfPath) && File.Exists(selfPath) &&
                        !string.Equals(Path.GetFullPath(selfPath), Path.GetFullPath(setupExeDestination), StringComparison.OrdinalIgnoreCase))
                    {
                        File.Copy(selfPath, setupExeDestination, true);
                        managedFiles.Add("Claude-Residual-ID-Cleaner-Setup.exe");
                    }
                }
            }

            if (logger != null)
            {
                logger(string.Format("Payload verified ({0} managed file(s)).", managedFiles.Count));
            }

            if (!dryRun && !skipShortcuts)
            {
                string targetApp = File.Exists(mainExeDestination)
                    ? mainExeDestination
                    : Path.Combine(resolvedRoot, "ClaudeCleanupLauncher.cmd");

                if (createDesktopShortcut)
                {
                    string deskDir = !string.IsNullOrEmpty(desktopDirOverride)
                        ? desktopDirOverride
                        : Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                    if (!string.IsNullOrEmpty(deskDir))
                    {
                        Directory.CreateDirectory(deskDir);
                        string deskLnk = Path.Combine(deskDir, "Claude Residual ID Cleaner.lnk");
                        CreateWindowsShortcut(deskLnk, targetApp, string.Empty, resolvedRoot, displayIcon, "Claude Residual ID Cleaner");
                        shortcutFiles.Add(deskLnk);
                        if (logger != null) logger("Created shortcut: " + deskLnk);
                    }
                }

                if (createStartMenuShortcut)
                {
                    string smBase = !string.IsNullOrEmpty(startMenuDirOverride)
                        ? startMenuDirOverride
                        : Path.Combine(Environment.GetFolderPath(elevated ? Environment.SpecialFolder.CommonPrograms : Environment.SpecialFolder.Programs), "Claude Residual ID Cleaner");
                    if (!string.IsNullOrEmpty(smBase))
                    {
                        Directory.CreateDirectory(smBase);
                        string appLnk = Path.Combine(smBase, "Claude Residual ID Cleaner.lnk");
                        CreateWindowsShortcut(appLnk, targetApp, string.Empty, resolvedRoot, displayIcon, "Claude Residual ID Cleaner");
                        shortcutFiles.Add(appLnk);

                        string uninstLnk = Path.Combine(smBase, "Uninstall Claude Residual ID Cleaner.lnk");
                        CreateWindowsShortcut(uninstLnk, setupExeDestination, "--uninstall --install-dir \"" + resolvedRoot + "\"", resolvedRoot, displayIcon, "Uninstall Claude Residual ID Cleaner");
                        shortcutFiles.Add(uninstLnk);
                        if (logger != null) logger("Created Start Menu shortcuts under: " + smBase);
                    }
                }
            }

            var manifest = new SetupInstallManifest
            {
                SchemaVersion = 1,
                Product = "Claude Residual ID Cleaner",
                Version = "1.0.0.0",
                InstalledBy = "Claude-Residual-ID-Cleaner-Setup",
                InstalledUtc = DateTime.UtcNow.ToString("o"),
                InstallRoot = resolvedRoot,
                UninstallRegistryHive = hiveName,
                UninstallRegistrySubKey = UninstallSubKey,
                ManagedFiles = managedFiles,
                ShortcutFiles = shortcutFiles
            };

            if (!dryRun)
            {
                var ser = new JavaScriptSerializer();
                string manifestPath = Path.Combine(resolvedRoot, ManifestFileName);
                File.WriteAllText(manifestPath, ser.Serialize(manifest), new UTF8Encoding(false));
            }

            if (registerAddRemove && !dryRun && !skipRegistry)
            {
                RegistryKey baseKey = elevated ? Registry.LocalMachine : Registry.CurrentUser;
                using (RegistryKey key = baseKey.CreateSubKey(UninstallSubKey))
                {
                    if (key != null)
                    {
                        key.SetValue("DisplayName", "Claude Residual ID Cleaner", RegistryValueKind.String);
                        key.SetValue("DisplayVersion", "1.0.0.0", RegistryValueKind.String);
                        key.SetValue("Publisher", "Claude Residual ID Cleaner", RegistryValueKind.String);
                        key.SetValue("InstallLocation", resolvedRoot, RegistryValueKind.String);
                        key.SetValue("DisplayIcon", displayIcon, RegistryValueKind.String);
                        key.SetValue("UninstallString", uninstallCmd, RegistryValueKind.String);
                        key.SetValue("QuietUninstallString", uninstallCmd + " --headless", RegistryValueKind.String);
                        key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                        key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                    }
                }
                if (logger != null) logger(string.Format("Registered Add/Remove Programs entry under {0}\\{1}", hiveName, UninstallSubKey));
            }

            var result = new SetupOperationResult
            {
                Succeeded = true,
                Mode = "Install",
                InstallRoot = resolvedRoot,
                InstalledFileCount = managedFiles.Count,
                RemovedFileCount = 0,
                HasWindowIcon = false,
                IsElevated = elevated,
                DryRun = dryRun,
                RegistryHive = hiveName,
                RegistrySubKey = UninstallSubKey,
                UninstallString = uninstallCmd,
                DisplayIcon = displayIcon,
                Message = "Install completed cleanly."
            };

            if (!string.IsNullOrEmpty(regOutJsonPath))
            {
                WriteJsonFile(regOutJsonPath, new Dictionary<string, object>
                {
                    { "RegistryHive", hiveName },
                    { "RegistrySubKey", UninstallSubKey },
                    { "DisplayName", "Claude Residual ID Cleaner" },
                    { "Publisher", "Claude Residual ID Cleaner" },
                    { "DisplayVersion", "1.0.0.0" },
                    { "InstallLocation", resolvedRoot },
                    { "DisplayIcon", displayIcon },
                    { "UninstallString", uninstallCmd },
                    { "SkippedLiveRegistryWrite", (dryRun || skipRegistry) }
                });
            }

            return result;
        }

        public static SetupOperationResult ExecuteUninstall(
            string targetInstallRoot,
            bool dryRun,
            bool skipRegistry,
            bool skipShortcuts,
            Action<string> logger)
        {
            string resolvedRoot = ValidateSafeInstallRoot(targetInstallRoot);
            string manifestPath = Path.Combine(resolvedRoot, ManifestFileName);
            if (!File.Exists(manifestPath))
            {
                throw new InvalidOperationException("Refusing to uninstall unmanaged directory (manifest missing): " + manifestPath);
            }

            var ser = new JavaScriptSerializer();
            string rawManifest = File.ReadAllText(manifestPath, Encoding.UTF8);
            var manifest = ser.Deserialize<SetupInstallManifest>(rawManifest);
            if (manifest == null || manifest.ManagedFiles == null)
            {
                throw new InvalidOperationException("Invalid install manifest: " + manifestPath);
            }

            string selfPath = Assembly.GetExecutingAssembly().Location;
            string rootPrefix = resolvedRoot.TrimEnd('\\', '/') + Path.DirectorySeparatorChar;
            int removedCount = 0;

            for (int i = 0; i < manifest.ManagedFiles.Count; i++)
            {
                string rel = manifest.ManagedFiles[i];
                if (string.IsNullOrEmpty(rel)) continue;
                string full = Path.GetFullPath(Path.Combine(resolvedRoot, rel));
                if (!full.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase)) continue;
                if (!File.Exists(full)) continue;
                if (!string.IsNullOrEmpty(selfPath) &&
                    string.Equals(full, Path.GetFullPath(selfPath), StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }
                if (!dryRun)
                {
                    File.Delete(full);
                }
                removedCount++;
            }

            if (!dryRun)
            {
                if (File.Exists(manifestPath))
                {
                    File.Delete(manifestPath);
                }
                PruneEmptySubdirectories(resolvedRoot);
            }

            if (!dryRun && !skipShortcuts && manifest.ShortcutFiles != null)
            {
                for (int i = 0; i < manifest.ShortcutFiles.Count; i++)
                {
                    string lnk = manifest.ShortcutFiles[i];
                    if (!string.IsNullOrEmpty(lnk) && File.Exists(lnk))
                    {
                        File.Delete(lnk);
                        string parent = Path.GetDirectoryName(lnk);
                        if (!string.IsNullOrEmpty(parent) && Directory.Exists(parent) &&
                            (string.Equals(Path.GetFileName(parent), "Claude Residual ID Cleaner", StringComparison.OrdinalIgnoreCase) ||
                             string.Equals(Path.GetFileName(parent), "claude-cleanup", StringComparison.OrdinalIgnoreCase)))
                        {
                            try
                            {
                                if (Directory.GetFileSystemEntries(parent).Length == 0)
                                {
                                    Directory.Delete(parent, false);
                                }
                            }
                            catch { }
                        }
                    }
                }
            }

            if (!dryRun && !skipRegistry)
            {
                TryDeleteUninstallSubKey(Registry.CurrentUser, UninstallSubKey);
                if (IsElevated())
                {
                    TryDeleteUninstallSubKey(Registry.LocalMachine, UninstallSubKey);
                }
            }

            if (logger != null)
            {
                logger(string.Format("Uninstalled {0} managed file(s) from {1}.", removedCount, resolvedRoot));
            }

            return new SetupOperationResult
            {
                Succeeded = true,
                Mode = "Uninstall",
                InstallRoot = resolvedRoot,
                InstalledFileCount = 0,
                RemovedFileCount = removedCount,
                HasWindowIcon = false,
                IsElevated = IsElevated(),
                DryRun = dryRun,
                RegistryHive = IsElevated() ? "HKLM" : "HKCU",
                RegistrySubKey = UninstallSubKey,
                UninstallString = string.Empty,
                DisplayIcon = string.Empty,
                Message = "Uninstall completed cleanly."
            };
        }

        private static void TryDeleteUninstallSubKey(RegistryKey rootKey, string subKey)
        {
            try
            {
                using (RegistryKey existing = rootKey.OpenSubKey(subKey, false))
                {
                    if (existing != null)
                    {
                        rootKey.DeleteSubKeyTree(subKey, false);
                    }
                }
            }
            catch { }
        }

        private static void PruneEmptySubdirectories(string rootDir)
        {
            if (!Directory.Exists(rootDir)) return;
            string[] dirs = Directory.GetDirectories(rootDir, "*", SearchOption.AllDirectories);
            Array.Sort(dirs, delegate(string a, string b) { return b.Length.CompareTo(a.Length); });
            for (int i = 0; i < dirs.Length; i++)
            {
                try
                {
                    if (Directory.Exists(dirs[i]) && Directory.GetFileSystemEntries(dirs[i]).Length == 0)
                    {
                        Directory.Delete(dirs[i], false);
                    }
                }
                catch { }
            }
            try
            {
                if (Directory.Exists(rootDir) && Directory.GetFileSystemEntries(rootDir).Length == 0)
                {
                    Directory.Delete(rootDir, false);
                }
            }
            catch { }
        }

        private static void CreateWindowsShortcut(string lnkPath, string targetPath, string arguments, string workingDir, string iconLocation, string description)
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null) return;
            object shell = Activator.CreateInstance(shellType);
            object shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { lnkPath });
            Type scType = shortcut.GetType();
            scType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { targetPath });
            if (!string.IsNullOrEmpty(arguments))
            {
                scType.InvokeMember("Arguments", BindingFlags.SetProperty, null, shortcut, new object[] { arguments });
            }
            if (!string.IsNullOrEmpty(workingDir))
            {
                scType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { workingDir });
            }
            if (!string.IsNullOrEmpty(iconLocation))
            {
                scType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { iconLocation });
            }
            if (!string.IsNullOrEmpty(description))
            {
                scType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { description });
            }
            scType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
        }

        public static void WriteJsonFile(string path, object payload)
        {
            string parent = Path.GetDirectoryName(Path.GetFullPath(path));
            if (!string.IsNullOrEmpty(parent) && !Directory.Exists(parent))
            {
                Directory.CreateDirectory(parent);
            }
            var ser = new JavaScriptSerializer();
            File.WriteAllText(path, ser.Serialize(payload), new UTF8Encoding(false));
        }

        public static ImageSource LoadEmbeddedIcon()
        {
            try
            {
                using (Stream st = Assembly.GetExecutingAssembly().GetManifestResourceStream(IconResourceName))
                {
                    if (st == null) return null;
                    var dec = new IconBitmapDecoder(st, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad);
                    BitmapFrame best = null;
                    for (int i = 0; i < dec.Frames.Count; i++)
                    {
                        if (best == null || dec.Frames[i].PixelWidth > best.PixelWidth)
                        {
                            best = dec.Frames[i];
                        }
                    }
                    if (best != null)
                    {
                        best.Freeze();
                    }
                    return best;
                }
            }
            catch
            {
                return null;
            }
        }
    }

    public sealed class SetupWindow : Window
    {
        private static readonly Brush BrushBgOuter = CreateBrush(24, 26, 31);          // #181A1F
        private static readonly Brush BrushBgChrome = CreateBrush(29, 32, 38);         // #1D2026
        private static readonly Brush BrushBgCard = CreateBrush(33, 37, 43);           // #21252B
        private static readonly Brush BrushBgLog = CreateBrush(20, 22, 26);            // #14161A
        private static readonly Brush BrushBorder = CreateBrush(50, 56, 66);           // #323842
        private static readonly Brush BrushAccent = CreateBrush(59, 130, 246);         // #3B82F6
        private static readonly Brush BrushAccentBright = CreateBrush(96, 165, 250);   // #60A5FA
        private static readonly Brush BrushSafetyBg = CreateBrush(16, 42, 28);         // #102A1C
        private static readonly Brush BrushSafetyBorder = CreateBrush(34, 197, 94);    // #22C55E
        private static readonly Brush BrushSafetyFg = CreateBrush(134, 239, 172);      // #86EFAC
        private static readonly Brush BrushDanger = CreateBrush(153, 27, 27);
        private static readonly Brush BrushTextPrimary = CreateBrush(243, 244, 246);
        private static readonly Brush BrushTextSecondary = CreateBrush(156, 163, 175);

        private string _lang;
        private readonly bool _uninstallMode;
        private readonly bool _dryRun;
        private readonly bool _skipRegistry;
        private readonly bool _skipShortcuts;
        private readonly bool _elevated;
        private readonly bool _hasIcon;

        private TextBlock _lblHeaderTitle;
        private TextBlock _lblHeaderSub;
        private TextBlock _lblSafetyPill;
        private TextBlock _lblPrivPill;
        private Button _btnLang;
        private TextBlock _lblPathLabel;
        private TextBox _txtInstallDir;
        private Button _btnBrowse;
        private CheckBox _chkDesktop;
        private CheckBox _chkStartMenu;
        private CheckBox _chkRegisterArp;
        private CheckBox _chkLaunchAfter;
        private TextBlock _lblScopeNote;
        private TextBox _txtLog;
        private ProgressBar _progress;
        private Button _btnAction;
        private Button _btnClose;

        private static Brush CreateBrush(byte r, byte g, byte b)
        {
            var br = new SolidColorBrush(Color.FromRgb(r, g, b));
            br.Freeze();
            return br;
        }

        public SetupWindow(string lang, bool uninstallMode, string initialDir, bool dryRun, bool skipRegistry, bool skipShortcuts)
        {
            _lang = string.IsNullOrEmpty(lang) ? SetupLocalization.DetectDefaultLanguage() : lang;
            _uninstallMode = uninstallMode;
            _dryRun = dryRun;
            _skipRegistry = skipRegistry;
            _skipShortcuts = skipShortcuts;
            _elevated = SetupEngine.IsElevated();

            ImageSource iconSrc = SetupEngine.LoadEmbeddedIcon();
            if (iconSrc != null)
            {
                Icon = iconSrc;
                _hasIcon = true;
            }

            Width = 720;
            Height = 560;
            MinWidth = 640;
            MinHeight = 500;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            ResizeMode = ResizeMode.CanMinimize;
            Background = BrushBgOuter;
            Foreground = BrushTextPrimary;
            FontFamily = new FontFamily("Microsoft YaHei UI, Segoe UI");
            FontSize = 12.5;

            BuildUi(iconSrc, string.IsNullOrEmpty(initialDir) ? SetupEngine.GetDefaultInstallRoot(_elevated) : initialDir);
            ApplyLanguage(_lang);
        }

        public bool HasWindowIcon { get { return _hasIcon; } }

        private void BuildUi(ImageSource iconSrc, string initialDir)
        {
            var rootGrid = new Grid();
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            // Header
            var header = new Border
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorder,
                BorderThickness = new Thickness(0, 0, 0, 1),
                Padding = new Thickness(18, 14, 18, 14)
            };
            var hGrid = new Grid();
            hGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            hGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            hGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var logoBox = new Border
            {
                Width = 46,
                Height = 46,
                CornerRadius = new CornerRadius(10),
                Background = BrushBgCard,
                BorderBrush = BrushAccentBright,
                BorderThickness = new Thickness(1),
                Margin = new Thickness(0, 0, 14, 0),
                ClipToBounds = true
            };
            if (iconSrc != null)
            {
                var img = new Image { Source = iconSrc, Width = 44, Height = 44, Stretch = Stretch.Uniform };
                RenderOptions.SetBitmapScalingMode(img, BitmapScalingMode.HighQuality);
                logoBox.Child = img;
            }
            Grid.SetColumn(logoBox, 0);
            hGrid.Children.Add(logoBox);

            var titleStack = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            _lblHeaderTitle = new TextBlock { FontSize = 16, FontWeight = FontWeights.Bold, Foreground = BrushTextPrimary };
            _lblHeaderSub = new TextBlock { FontSize = 11.5, Foreground = BrushTextSecondary, Margin = new Thickness(0, 3, 0, 4), TextWrapping = TextWrapping.Wrap };
            var badgeRow = new WrapPanel();
            var safetyBorder = new Border { Background = BrushSafetyBg, BorderBrush = BrushSafetyBorder, BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(10), Padding = new Thickness(9, 2, 9, 2), Margin = new Thickness(0, 0, 8, 0) };
            _lblSafetyPill = new TextBlock { Foreground = BrushSafetyFg, FontSize = 11, FontWeight = FontWeights.SemiBold };
            safetyBorder.Child = _lblSafetyPill;
            var privBorder = new Border { Background = BrushBgCard, BorderBrush = BrushBorder, BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(10), Padding = new Thickness(9, 2, 9, 2) };
            _lblPrivPill = new TextBlock { Foreground = BrushTextSecondary, FontSize = 11 };
            privBorder.Child = _lblPrivPill;
            badgeRow.Children.Add(safetyBorder);
            badgeRow.Children.Add(privBorder);
            titleStack.Children.Add(_lblHeaderTitle);
            titleStack.Children.Add(_lblHeaderSub);
            titleStack.Children.Add(badgeRow);
            Grid.SetColumn(titleStack, 1);
            hGrid.Children.Add(titleStack);

            _btnLang = new Button
            {
                Background = BrushAccent,
                BorderBrush = BrushAccentBright,
                BorderThickness = new Thickness(1),
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                Padding = new Thickness(12, 6, 12, 6),
                VerticalAlignment = VerticalAlignment.Center
            };
            _btnLang.Click += delegate(object s, RoutedEventArgs e)
            {
                ApplyLanguage(string.Equals(_lang, "zh-CN", StringComparison.OrdinalIgnoreCase) ? "en-US" : "zh-CN");
            };
            Grid.SetColumn(_btnLang, 2);
            hGrid.Children.Add(_btnLang);
            header.Child = hGrid;
            Grid.SetRow(header, 0);
            rootGrid.Children.Add(header);

            // Body
            var body = new StackPanel { Margin = new Thickness(20, 16, 20, 12) };
            var card = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorder,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(14, 12, 14, 12),
                Margin = new Thickness(0, 0, 0, 12)
            };
            var cardStack = new StackPanel();
            _lblPathLabel = new TextBlock { Foreground = BrushTextPrimary, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 6) };
            var pathRow = new Grid { Margin = new Thickness(0, 0, 0, 10) };
            pathRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            pathRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            _txtInstallDir = new TextBox
            {
                Text = initialDir,
                Background = BrushBgLog,
                Foreground = BrushTextPrimary,
                BorderBrush = BrushBorder,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(8, 6, 8, 6),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 12
            };
            _btnBrowse = new Button
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorder,
                BorderThickness = new Thickness(1),
                Foreground = BrushTextPrimary,
                Padding = new Thickness(12, 6, 12, 6),
                Margin = new Thickness(8, 0, 0, 0),
                IsEnabled = !_uninstallMode
            };
            _btnBrowse.Click += OnBrowseClick;
            Grid.SetColumn(_txtInstallDir, 0);
            Grid.SetColumn(_btnBrowse, 1);
            pathRow.Children.Add(_txtInstallDir);
            pathRow.Children.Add(_btnBrowse);

            _chkDesktop = new CheckBox { IsChecked = true, Foreground = BrushTextPrimary, Margin = new Thickness(0, 3, 0, 5), Visibility = _uninstallMode ? Visibility.Collapsed : Visibility.Visible };
            _chkStartMenu = new CheckBox { IsChecked = true, Foreground = BrushTextPrimary, Margin = new Thickness(0, 0, 0, 5), Visibility = _uninstallMode ? Visibility.Collapsed : Visibility.Visible };
            _chkRegisterArp = new CheckBox { IsChecked = true, Foreground = BrushTextPrimary, Margin = new Thickness(0, 0, 0, 5), Visibility = _uninstallMode ? Visibility.Collapsed : Visibility.Visible };
            _chkLaunchAfter = new CheckBox { IsChecked = true, Foreground = BrushTextPrimary, Margin = new Thickness(0, 0, 0, 6), Visibility = _uninstallMode ? Visibility.Collapsed : Visibility.Visible };
            _lblScopeNote = new TextBlock { Foreground = BrushTextSecondary, FontSize = 11.5, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 4, 0, 0) };

            cardStack.Children.Add(_lblPathLabel);
            cardStack.Children.Add(pathRow);
            cardStack.Children.Add(_chkDesktop);
            cardStack.Children.Add(_chkStartMenu);
            cardStack.Children.Add(_chkRegisterArp);
            cardStack.Children.Add(_chkLaunchAfter);
            cardStack.Children.Add(_lblScopeNote);
            card.Child = cardStack;
            body.Children.Add(card);

            _progress = new ProgressBar { Height = 8, Minimum = 0, Maximum = 100, Value = 0, Margin = new Thickness(0, 0, 0, 10), Background = BrushBgLog, Foreground = BrushAccentBright, BorderBrush = BrushBorder };
            body.Children.Add(_progress);

            _txtLog = new TextBox
            {
                Height = 140,
                IsReadOnly = true,
                AcceptsReturn = true,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                Background = BrushBgLog,
                Foreground = BrushTextPrimary,
                BorderBrush = BrushBorder,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(8, 6, 8, 6),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11.5
            };
            body.Children.Add(_txtLog);
            Grid.SetRow(body, 1);
            rootGrid.Children.Add(body);

            // Footer
            var footer = new Border
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorder,
                BorderThickness = new Thickness(0, 1, 0, 0),
                Padding = new Thickness(18, 12, 18, 12)
            };
            var fPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
            _btnAction = new Button
            {
                Background = _uninstallMode ? BrushDanger : BrushAccent,
                BorderBrush = _uninstallMode ? CreateBrush(239, 68, 68) : BrushAccentBright,
                BorderThickness = new Thickness(1),
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                Padding = new Thickness(18, 7, 18, 7),
                Margin = new Thickness(0, 0, 10, 0)
            };
            _btnAction.Click += OnActionClick;

            _btnClose = new Button
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorder,
                BorderThickness = new Thickness(1),
                Foreground = BrushTextPrimary,
                Padding = new Thickness(16, 7, 16, 7)
            };
            _btnClose.Click += delegate(object s, RoutedEventArgs e) { Close(); };

            fPanel.Children.Add(_btnAction);
            fPanel.Children.Add(_btnClose);
            footer.Child = fPanel;
            Grid.SetRow(footer, 2);
            rootGrid.Children.Add(footer);

            Content = rootGrid;
        }

        private void ApplyLanguage(string lang)
        {
            _lang = lang;
            var s = SetupLocalization.GetStrings(lang);
            Title = _uninstallMode ? s["UninstallTitle"] : s["Title"];
            _lblHeaderTitle.Text = _uninstallMode ? s["UninstallTitle"] : s["Title"];
            _lblHeaderSub.Text = s["HeaderSub"];
            _lblSafetyPill.Text = s["SafetyPill"];
            _lblPrivPill.Text = _elevated ? s["PrivAdmin"] : s["PrivStandard"];
            _btnLang.Content = s["LangBtn"];
            _lblPathLabel.Text = s["PathLabel"];
            _btnBrowse.Content = s["BrowseBtn"];
            _chkDesktop.Content = s["ChkDesktop"];
            _chkStartMenu.Content = s["ChkStartMenu"];
            _chkRegisterArp.Content = s["ChkRegisterArp"];
            _chkLaunchAfter.Content = s["ChkLaunchAfter"];
            _lblScopeNote.Text = s["ScopeNote"];
            _btnAction.Content = _uninstallMode ? s["BtnUninstall"] : s["BtnInstall"];
            _btnClose.Content = s["BtnClose"];
            if (string.IsNullOrEmpty(_txtLog.Text))
            {
                _txtLog.Text = (_uninstallMode ? s["StatusUninstallReady"] : s["StatusReady"]) + Environment.NewLine;
            }
        }

        private void OnBrowseClick(object sender, RoutedEventArgs e)
        {
            var s = SetupLocalization.GetStrings(_lang);
            using (var dlg = new System.Windows.Forms.FolderBrowserDialog())
            {
                dlg.Description = s["BrowseDesc"];
                dlg.ShowNewFolderButton = true;
                if (Directory.Exists(_txtInstallDir.Text))
                {
                    dlg.SelectedPath = _txtInstallDir.Text;
                }
                if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK && !string.IsNullOrEmpty(dlg.SelectedPath))
                {
                    string picked = dlg.SelectedPath;
                    if (!string.Equals(Path.GetFileName(picked.TrimEnd('\\', '/')), "Claude-Residual-ID-Cleaner", StringComparison.OrdinalIgnoreCase))
                    {
                        picked = Path.Combine(picked, "Claude-Residual-ID-Cleaner");
                    }
                    _txtInstallDir.Text = picked;
                }
            }
        }

        private void AppendLog(string line)
        {
            _txtLog.AppendText(line + Environment.NewLine);
            _txtLog.ScrollToEnd();
        }

        private void OnActionClick(object sender, RoutedEventArgs e)
        {
            var s = SetupLocalization.GetStrings(_lang);
            _btnAction.IsEnabled = false;
            try
            {
                string targetDir = _txtInstallDir.Text;
                if (_uninstallMode)
                {
                    AppendLog(s["StatusUninstalling"]);
                    _progress.Value = 40;
                    SetupOperationResult res = SetupEngine.ExecuteUninstall(targetDir, _dryRun, _skipRegistry, _skipShortcuts, AppendLog);
                    _progress.Value = 100;
                    AppendLog(string.Format(s["StatusDoneUninstall"], res.RemovedFileCount));
                }
                else
                {
                    AppendLog(s["StatusInstalling"]);
                    _progress.Value = 30;
                    SetupOperationResult res = SetupEngine.ExecuteInstall(
                        targetDir,
                        _chkDesktop.IsChecked == true,
                        _chkStartMenu.IsChecked == true,
                        _chkRegisterArp.IsChecked == true,
                        _dryRun,
                        _skipRegistry,
                        _skipShortcuts,
                        null,
                        null,
                        null,
                        AppendLog);
                    _progress.Value = 100;
                    AppendLog(string.Format(s["StatusDoneInstall"], res.InstallRoot));
                    if (!_dryRun && _chkLaunchAfter.IsChecked == true)
                    {
                        string appExe = Path.Combine(res.InstallRoot, "Claude-Residual-ID-Cleaner.exe");
                        if (File.Exists(appExe))
                        {
                            Process.Start(new ProcessStartInfo { FileName = appExe, Arguments = "--language " + _lang, UseShellExecute = true });
                            Close();
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _progress.Value = 0;
                AppendLog("[ERROR] " + ex.Message);
                MessageBox.Show(this, ex.Message, Title, MessageBoxButton.OK, MessageBoxImage.Error);
                _btnAction.IsEnabled = true;
            }
        }
    }

    internal static class SetupProgram
    {
        [STAThread]
        private static int Main(string[] args)
        {
            string language = null;
            string installDir = null;
            string selfTestPath = null;
            string regOutPath = null;
            string desktopDir = null;
            string startMenuDir = null;
            bool headless = false;
            bool uninstall = false;
            bool dryRun = false;
            bool noRegistry = false;
            bool noShortcuts = false;

            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i];
                if (string.Equals(a, "--headless", StringComparison.OrdinalIgnoreCase)) headless = true;
                else if (string.Equals(a, "--uninstall", StringComparison.OrdinalIgnoreCase)) uninstall = true;
                else if (string.Equals(a, "--dry-run", StringComparison.OrdinalIgnoreCase)) dryRun = true;
                else if (string.Equals(a, "--no-registry", StringComparison.OrdinalIgnoreCase)) noRegistry = true;
                else if (string.Equals(a, "--no-shortcuts", StringComparison.OrdinalIgnoreCase)) noShortcuts = true;
                else if (string.Equals(a, "--language", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) language = args[++i];
                else if (string.Equals(a, "--install-dir", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) installDir = args[++i];
                else if (string.Equals(a, "--self-test", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) selfTestPath = args[++i];
                else if (string.Equals(a, "--reg-out", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) regOutPath = args[++i];
                else if (string.Equals(a, "--desktop-dir", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) desktopDir = args[++i];
                else if (string.Equals(a, "--start-menu-dir", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length) startMenuDir = args[++i];
            }

            if (headless)
            {
                SetupOperationResult res;
                bool hasWinIcon = (SetupEngine.LoadEmbeddedIcon() != null);
                if (uninstall)
                {
                    string dir = string.IsNullOrEmpty(installDir) ? SetupEngine.GetDefaultInstallRoot(SetupEngine.IsElevated()) : installDir;
                    res = SetupEngine.ExecuteUninstall(dir, dryRun, noRegistry, noShortcuts, null);
                }
                else
                {
                    string dir = string.IsNullOrEmpty(installDir) ? SetupEngine.GetDefaultInstallRoot(SetupEngine.IsElevated()) : installDir;
                    res = SetupEngine.ExecuteInstall(dir, !noShortcuts, !noShortcuts, !noRegistry, dryRun, noRegistry, noShortcuts, desktopDir, startMenuDir, regOutPath, null);
                }
                res.HasWindowIcon = hasWinIcon;
                if (!string.IsNullOrEmpty(selfTestPath))
                {
                    SetupEngine.WriteJsonFile(selfTestPath, res);
                }
                return res.Succeeded ? 0 : 1;
            }

            var app = new Application();
            var win = new SetupWindow(language, uninstall, installDir, dryRun, noRegistry, noShortcuts);
            app.Run(win);
            return 0;
        }
    }
}
