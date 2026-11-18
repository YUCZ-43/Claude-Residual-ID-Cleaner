[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$Audit,
    [switch]$Plan,
    [switch]$Apply,
    [switch]$Verify,
    [switch]$Help,
    [ValidateSet('AccountData', 'FullRemoval')][string]$Policy,
    [ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ApprovedManifestSha256,
    [ValidateSet('Text', 'Json')][string]$OutputFormat = 'Text',
    [ValidateSet('Auto', 'zh-CN', 'en-US')][string]$Language = 'Auto',
    [switch]$SaveAuditReport,
    [string]$AuditOutputPath = '',
    [switch]$CloseRunningProcesses,
    [switch]$EmitProgress
)

Set-StrictMode -Version 2.0
$script:ProjectRoot = $PSScriptRoot
$script:PlanPath = Join-Path $PSScriptRoot 'CLEANUP-PLAN.md'
$script:AuditPath = Join-Path $PSScriptRoot 'AUDIT.md'
$script:VerificationPath = Join-Path $PSScriptRoot 'VERIFICATION.md'

function Initialize-Utf8ConsoleEncoding {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $script:OutputEncoding = $utf8NoBom
    $global:OutputEncoding = $utf8NoBom
    try { [Console]::OutputEncoding = $utf8NoBom } catch {}
    try { [Console]::InputEncoding = $utf8NoBom } catch {}
    if ($OutputFormat -eq 'Json' -or [Console]::IsOutputRedirected -or [Console]::IsErrorRedirected) {
        $psStyleVar = Get-Variable -Name PSStyle -ErrorAction SilentlyContinue
        if ($null -ne $psStyleVar -and $null -ne $psStyleVar.Value) {
            try { $psStyleVar.Value.OutputRendering = 'PlainText' } catch {}
        }
    }
}

function Resolve-UiLanguage {
    param([string]$RequestedLanguage = $Language)

    if ($RequestedLanguage -eq 'zh-CN' -or $RequestedLanguage -eq 'en-US') {
        return $RequestedLanguage
    }
    try {
        $uiName = [System.Globalization.CultureInfo]::CurrentUICulture.Name
        if ($uiName -like 'zh*') {
            return 'zh-CN'
        }
    } catch {}
    return 'en-US'
}

$script:ActiveLanguage = Resolve-UiLanguage -RequestedLanguage $Language

function Get-LocalizedUiText {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$Lang = $script:ActiveLanguage
    )

    $isZh = ($Lang -eq 'zh-CN')
    switch ($Key) {
        'PositioningTagline' {
            if ($isZh) { return '专用于扫描并安全清理 Claude 账号封禁后遗留的本地账号/设备元数据、授权缓存、会话与扩展残留 —— 绝不改动或损害 Windows 系统本身。' }
            return 'Non-destructive Windows utility specifically designed to scan and clean residual Claude account/device metadata, auth tokens, session caches, and leftover extension/registry entries after a Claude account ban — strictly without altering or harming Windows OS itself.'
        }
        'SafetyDisclaimer' {
            if ($isZh) { return '安全边界：默认仅执行只读审计；仅清理白名单内的 Claude 残余项目，绝不修改操作系统文件、无关应用、WSL、硬件/系统设备 ID 或远端服务器账号状态。' }
            return 'Safety boundary: Default mode is strictly read-only Audit; cleanup targets only allowlisted Claude residuals and never modifies Windows OS files, unrelated apps, WSL, OS device IDs, or remote server-side account state.'
        }
        'PlanTitle' {
            if ($isZh) { return '# Windows Claude 封号残余数据清理方案 (CLEANUP-PLAN)' }
            return '# Windows Claude cleanup plan'
        }
        'PlanIdPrefix' {
            if ($isZh) { return '计划 ID: ' }
            return 'Plan ID: '
        }
        'PlanGeneratedPrefix' {
            if ($isZh) { return '生成时间 (UTC): ' }
            return 'Generated: '
        }
        'PlanRule1' {
            if ($isZh) { return '当前尚未执行任何删除。仅 Decision=Ready 的条目在明确批准本文件精确 SHA-256 哈希与单一清理策略后可执行清理。' }
            return 'No deletion has been performed. Only Decision=Ready entries can be applied after explicit approval of this exact file hash and one policy.'
        }
        'PlanRule2' {
            if ($isZh) { return 'ReviewOnly 与 Blocked 条目已被自动排除；缺失路径已省略；Windows 操作系统文件、WSL 与浏览器个人配置绝不被修改。' }
            return 'ReviewOnly and Blocked entries are excluded. Missing paths are omitted. WSL and browser site data are excluded.'
        }
        'PlanTableHeader' {
            if ($isZh) { return '| 清理策略 | 条目 ID | 类别 | 目标路径或包名 | 大小(字节) | 决策 | 原因 / 警告 |' }
            return '| Policy | ID | Category | Path or package | Size (bytes) | Decision | Reason / warning |'
        }
        'AuditTitle' {
            if ($isZh) { return '# Windows Claude 账号封号残余数据只读审计报告 (AUDIT)' }
            return '# Windows Claude Residual ID Audit Report'
        }
        'VerificationTitle' {
            if ($isZh) { return '# 执行核验报告与账本' }
            return '# Execution verification log'
        }
        default { return $Key }
    }
}

if (-not ('ClaudeCleanup.NativeFs' -as [type])) {
    $nativeSource = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace ClaudeCleanup {
    public sealed class FsIdentity {
        public uint Attributes;
        public uint VolumeSerialNumber;
        public ulong FileIndex;
        public uint NumberOfLinks;
        public long Length;
        public long LastWriteUtcTicks;
        public string FinalPath;
        public string OwnerSid;
    }

    public sealed class DirChildEntry {
        public string Name;
        public uint Attributes;
        public ulong FileIndex;
        public long EndOfFile;
        public long LastWriteUtcTicks;
    }

    public static class NativeFs {
        public const uint INVALID_FILE_ATTRIBUTES = 0xFFFFFFFFu;
        public const uint FILE_ATTRIBUTE_READONLY = 0x00000001u;
        public const uint FILE_ATTRIBUTE_DIRECTORY = 0x00000010u;
        public const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400u;

        private const int ERROR_FILE_NOT_FOUND = 2;
        private const int ERROR_PATH_NOT_FOUND = 3;
        private const int ERROR_NO_MORE_FILES = 18;
        private const int ERROR_NOT_SUPPORTED = 50;
        private const int ERROR_INVALID_PARAMETER = 87;

        private const uint GENERIC_READ = 0x80000000u;
        private const uint DELETE_ACCESS = 0x00010000u;
        private const uint READ_CONTROL = 0x00020000u;
        private const uint SYNCHRONIZE = 0x00100000u;
        private const uint FILE_LIST_DIRECTORY = 0x00000001u;
        private const uint FILE_READ_ATTRIBUTES = 0x00000080u;
        private const uint FILE_WRITE_ATTRIBUTES = 0x00000100u;

        private const uint FILE_SHARE_NONE = 0x00000000u;
        private const uint FILE_SHARE_READ = 0x00000001u;
        private const uint FILE_SHARE_WRITE = 0x00000002u;
        private const uint FILE_SHARE_DELETE = 0x00000004u;

        private const uint OPEN_EXISTING = 3u;
        private const uint FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000u;
        private const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000u;

        private const int FileBasicInfo = 0;
        private const int FileDispositionInfo = 4;
        private const int FileDispositionInfoEx = 21;
        private const int FileIdBothDirectoryInfo = 10;

        private const uint FILE_DISPOSITION_FLAG_DELETE = 0x00000001u;
        private const uint FILE_DISPOSITION_FLAG_POSIX_SEMANTICS = 0x00000002u;

        private const int SE_FILE_OBJECT = 1;
        private const uint OWNER_SECURITY_INFORMATION = 0x00000001u;

        private const uint REG_OPTION_OPEN_LINK = 0x00000008u;
        private const int KEY_QUERY_VALUE = 0x0001;
        private const int KEY_ENUMERATE_SUB_KEYS = 0x0008;
        private const uint REG_LINK = 6u;

        [StructLayout(LayoutKind.Sequential)]
        private struct WIN32_FILETIME {
            public uint LowDateTime;
            public uint HighDateTime;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct BY_HANDLE_FILE_INFORMATION {
            public uint FileAttributes;
            public WIN32_FILETIME CreationTime;
            public WIN32_FILETIME LastAccessTime;
            public WIN32_FILETIME LastWriteTime;
            public uint VolumeSerialNumber;
            public uint FileSizeHigh;
            public uint FileSizeLow;
            public uint NumberOfLinks;
            public uint FileIndexHigh;
            public uint FileIndexLow;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct FILE_BASIC_INFO {
            public long CreationTime;
            public long LastAccessTime;
            public long LastWriteTime;
            public long ChangeTime;
            public uint FileAttributes;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct FILE_DISPOSITION_INFO {
            [MarshalAs(UnmanagedType.U1)]
            public bool DeleteFile;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct FILE_DISPOSITION_INFO_EX {
            public uint Flags;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFileAttributesW(string lpFileName);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetLongPathNameW(string lpszShortPath, StringBuilder lpszLongPath, uint cchBuffer);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFileW(
            string lpFileName,
            uint dwDesiredAccess,
            uint dwShareMode,
            IntPtr lpSecurityAttributes,
            uint dwCreationDisposition,
            uint dwFlagsAndAttributes,
            IntPtr hTemplateFile);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandle(
            SafeFileHandle hFile,
            out BY_HANDLE_FILE_INFORMATION lpFileInformation);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFileInformationByHandleEx(
            SafeFileHandle hFile,
            int FileInformationClass,
            IntPtr lpFileInformation,
            uint dwBufferSize);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandleW(
            SafeFileHandle hFile,
            StringBuilder lpszFilePath,
            uint cchFilePath,
            uint dwFlags);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool SetFileInformationByHandle(
            SafeFileHandle hFile,
            int FileInformationClass,
            IntPtr lpFileInformation,
            uint dwBufferSize);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern uint GetSecurityInfo(
            SafeFileHandle handle,
            int ObjectType,
            uint SecurityInfo,
            out IntPtr ppsidOwner,
            IntPtr ppsidGroup,
            IntPtr ppDacl,
            IntPtr ppSacl,
            out IntPtr ppSecurityDescriptor);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool ConvertSidToStringSidW(IntPtr pSid, out IntPtr strSid);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr LocalFree(IntPtr hMem);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
        private static extern int RegOpenKeyExW(
            UIntPtr hKey,
            string lpSubKey,
            uint ulOptions,
            int samDesired,
            out IntPtr phkResult);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
        private static extern int RegQueryValueExW(
            IntPtr hKey,
            string lpValueName,
            IntPtr lpReserved,
            out uint lpType,
            IntPtr lpData,
            ref uint lpcbData);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
        private static extern int RegQueryInfoKeyW(
            IntPtr hKey,
            IntPtr lpClass,
            IntPtr lpcchClass,
            IntPtr lpReserved,
            out uint lpcSubKeys,
            IntPtr lpcbMaxSubKeyLen,
            IntPtr lpcbMaxClassLen,
            IntPtr lpcValues,
            IntPtr lpcbMaxValueNameLen,
            IntPtr lpcbMaxValueLen,
            IntPtr lpcbSecurityDescriptor,
            IntPtr lpftLastWriteTime);

        [DllImport("ntdll.dll")]
        private static extern int NtDeleteKey(IntPtr KeyHandle);

        [DllImport("advapi32.dll")]
        private static extern int RegCloseKey(IntPtr hKey);

        public static string ToExtendedPath(string normalPath) {
            if (string.IsNullOrEmpty(normalPath)) {
                throw new ArgumentException("Path cannot be empty.");
            }
            if (normalPath.StartsWith("\\\\?\\", StringComparison.Ordinal)) {
                return normalPath;
            }
            return "\\\\?\\" + normalPath;
        }

        public static bool TryGetAttributes(string normalPath, out uint attributes) {
            attributes = GetFileAttributesW(ToExtendedPath(normalPath));
            if (attributes != INVALID_FILE_ATTRIBUTES) {
                return true;
            }
            int err = Marshal.GetLastWin32Error();
            if (err == ERROR_FILE_NOT_FOUND || err == ERROR_PATH_NOT_FOUND) {
                return false;
            }
            throw new Win32Exception(err, "Failed to query attributes for: " + normalPath);
        }

        public static string ResolveLongPath(string normalPath) {
            string ext = ToExtendedPath(normalPath);
            StringBuilder sb = new StringBuilder(32768);
            uint len = GetLongPathNameW(ext, sb, (uint)sb.Capacity);
            if (len == 0) {
                return normalPath;
            }
            string result = sb.ToString();
            if (result.StartsWith("\\\\?\\", StringComparison.Ordinal)) {
                result = result.Substring(4);
            }
            return result.TrimEnd('\\');
        }

        public static SafeFileHandle OpenHandle(string normalPath, bool forDelete, bool isDirectoryHint, out int win32Error) {
            uint access = FILE_READ_ATTRIBUTES | READ_CONTROL | SYNCHRONIZE;
            if (forDelete) {
                access |= DELETE_ACCESS | FILE_WRITE_ATTRIBUTES;
            }
            if (isDirectoryHint) {
                access |= FILE_LIST_DIRECTORY;
            }
            uint share;
            if (forDelete) {
                // Keep directories readable/writable for child ops while blocking renames/deletes; lock files exclusively.
                share = isDirectoryHint ? (FILE_SHARE_READ | FILE_SHARE_WRITE) : FILE_SHARE_NONE;
            } else {
                share = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
            }
            uint flags = FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS;
            SafeFileHandle handle = CreateFileW(ToExtendedPath(normalPath), access, share, IntPtr.Zero, OPEN_EXISTING, flags, IntPtr.Zero);
            win32Error = handle.IsInvalid ? Marshal.GetLastWin32Error() : 0;
            return handle;
        }

        public static bool IsNotFoundError(int win32Error) {
            return win32Error == ERROR_FILE_NOT_FOUND || win32Error == ERROR_PATH_NOT_FOUND;
        }

        public static FsIdentity InspectHandle(SafeFileHandle handle) {
            BY_HANDLE_FILE_INFORMATION info;
            if (!GetFileInformationByHandle(handle, out info)) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetFileInformationByHandle failed.");
            }
            StringBuilder sb = new StringBuilder(32768);
            uint pathLen = GetFinalPathNameByHandleW(handle, sb, (uint)sb.Capacity, 0u);
            if (pathLen == 0) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetFinalPathNameByHandleW failed.");
            }
            if (pathLen >= (uint)sb.Capacity) {
                sb = new StringBuilder((int)pathLen + 2);
                pathLen = GetFinalPathNameByHandleW(handle, sb, (uint)sb.Capacity, 0u);
                if (pathLen == 0) {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "GetFinalPathNameByHandleW failed on retry.");
                }
            }

            IntPtr pSidOwner = IntPtr.Zero;
            IntPtr pSd = IntPtr.Zero;
            IntPtr pSidStr = IntPtr.Zero;
            string ownerSid;
            try {
                uint secErr = GetSecurityInfo(handle, SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION, out pSidOwner, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, out pSd);
                if (secErr != 0) {
                    throw new Win32Exception((int)secErr, "GetSecurityInfo failed.");
                }
                if (pSidOwner == IntPtr.Zero || !ConvertSidToStringSidW(pSidOwner, out pSidStr) || pSidStr == IntPtr.Zero) {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "ConvertSidToStringSidW failed.");
                }
                ownerSid = Marshal.PtrToStringUni(pSidStr);
            } finally {
                if (pSidStr != IntPtr.Zero) { LocalFree(pSidStr); }
                if (pSd != IntPtr.Zero) { LocalFree(pSd); }
            }

            long ft = (((long)info.LastWriteTime.HighDateTime) << 32) | (uint)info.LastWriteTime.LowDateTime;
            long lastWriteTicks = DateTime.FromFileTimeUtc(ft).Ticks;
            ulong fileIndex = (((ulong)info.FileIndexHigh) << 32) | (ulong)info.FileIndexLow;
            long length = (((long)info.FileSizeHigh) << 32) | (uint)info.FileSizeLow;

            FsIdentity id = new FsIdentity();
            id.Attributes = info.FileAttributes;
            id.VolumeSerialNumber = info.VolumeSerialNumber;
            id.FileIndex = fileIndex;
            id.NumberOfLinks = info.NumberOfLinks;
            id.Length = length;
            id.LastWriteUtcTicks = lastWriteTicks;
            id.FinalPath = sb.ToString();
            id.OwnerSid = ownerSid;
            return id;
        }

        public static List<DirChildEntry> EnumerateHandleChildren(SafeFileHandle dirHandle) {
            List<DirChildEntry> list = new List<DirChildEntry>();
            const uint bufSize = 65536u;
            IntPtr buffer = Marshal.AllocHGlobal((int)bufSize);
            try {
                while (true) {
                    if (!GetFileInformationByHandleEx(dirHandle, FileIdBothDirectoryInfo, buffer, bufSize)) {
                        int err = Marshal.GetLastWin32Error();
                        if (err == ERROR_NO_MORE_FILES) {
                            break;
                        }
                        throw new Win32Exception(err, "GetFileInformationByHandleEx(FileIdBothDirectoryInfo) failed.");
                    }
                    long offset = 0;
                    while (true) {
                        IntPtr entryPtr = new IntPtr(buffer.ToInt64() + offset);
                        uint nextOffset = (uint)Marshal.ReadInt32(entryPtr, 0);
                        long lastWriteFt = Marshal.ReadInt64(entryPtr, 24);
                        long endOfFile = Marshal.ReadInt64(entryPtr, 40);
                        uint attrs = (uint)Marshal.ReadInt32(entryPtr, 56);
                        int nameBytes = Marshal.ReadInt32(entryPtr, 60);
                        ulong fileId = (ulong)Marshal.ReadInt64(entryPtr, 96);
                        string name = Marshal.PtrToStringUni(new IntPtr(entryPtr.ToInt64() + 104), nameBytes / 2);
                        if (name != "." && name != "..") {
                            DirChildEntry child = new DirChildEntry();
                            child.Name = name;
                            child.Attributes = attrs;
                            child.FileIndex = fileId;
                            child.EndOfFile = endOfFile;
                            child.LastWriteUtcTicks = DateTime.FromFileTimeUtc(lastWriteFt).Ticks;
                            list.Add(child);
                        }
                        if (nextOffset == 0) {
                            break;
                        }
                        offset += (long)nextOffset;
                    }
                }
            } finally {
                Marshal.FreeHGlobal(buffer);
            }
            return list;
        }

        public static void DeleteHandleObject(SafeFileHandle handle, uint currentAttributes) {
            if ((currentAttributes & FILE_ATTRIBUTE_READONLY) != 0) {
                FILE_BASIC_INFO basic = new FILE_BASIC_INFO();
                basic.CreationTime = 0;
                basic.LastAccessTime = 0;
                basic.LastWriteTime = 0;
                basic.ChangeTime = 0;
                basic.FileAttributes = (currentAttributes & ~FILE_ATTRIBUTE_READONLY);
                if (basic.FileAttributes == 0) {
                    basic.FileAttributes = 0x00000080u; // FILE_ATTRIBUTE_NORMAL
                }
                int basicSize = Marshal.SizeOf(typeof(FILE_BASIC_INFO));
                IntPtr basicPtr = Marshal.AllocHGlobal(basicSize);
                try {
                    Marshal.StructureToPtr(basic, basicPtr, false);
                    if (!SetFileInformationByHandle(handle, FileBasicInfo, basicPtr, (uint)basicSize)) {
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "Failed to clear ReadOnly attribute on handle.");
                    }
                } finally {
                    Marshal.FreeHGlobal(basicPtr);
                }
            }

            FILE_DISPOSITION_INFO_EX dispEx = new FILE_DISPOSITION_INFO_EX();
            dispEx.Flags = FILE_DISPOSITION_FLAG_DELETE | FILE_DISPOSITION_FLAG_POSIX_SEMANTICS;
            int exSize = Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO_EX));
            IntPtr exPtr = Marshal.AllocHGlobal(exSize);
            try {
                Marshal.StructureToPtr(dispEx, exPtr, false);
                if (SetFileInformationByHandle(handle, FileDispositionInfoEx, exPtr, (uint)exSize)) {
                    return;
                }
                int err = Marshal.GetLastWin32Error();
                if (err != ERROR_INVALID_PARAMETER && err != ERROR_NOT_SUPPORTED) {
                    throw new Win32Exception(err, "SetFileInformationByHandle(FileDispositionInfoEx) failed.");
                }
            } finally {
                Marshal.FreeHGlobal(exPtr);
            }

            FILE_DISPOSITION_INFO disp = new FILE_DISPOSITION_INFO();
            disp.DeleteFile = true;
            int dispSize = Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO));
            IntPtr dispPtr = Marshal.AllocHGlobal(dispSize);
            try {
                Marshal.StructureToPtr(disp, dispPtr, false);
                if (!SetFileInformationByHandle(handle, FileDispositionInfo, dispPtr, (uint)dispSize)) {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "SetFileInformationByHandle(FileDispositionInfo) failed.");
                }
            } finally {
                Marshal.FreeHGlobal(dispPtr);
            }
        }

        private static void AssertRegistryKeyNotLink(IntPtr hKey, string displayPath) {
            uint linkType = 0;
            uint linkDataSize = 0;
            int linkErr = RegQueryValueExW(hKey, "SymbolicLinkValue", IntPtr.Zero, out linkType, IntPtr.Zero, ref linkDataSize);
            if (linkErr == 0 || linkType == REG_LINK) {
                throw new InvalidOperationException("Registry symbolic link is not an approved deletion target: " + displayPath);
            }
        }

        public static void DeleteHkcuLeafKeySafely(string subKey, string expectedDefaultValue) {
            if (string.IsNullOrEmpty(subKey) || subKey.IndexOf('\0') >= 0 || subKey.Contains("..") || subKey.Contains("/")) {
                throw new ArgumentException("Unsafe registry subkey path: " + subKey);
            }
            UIntPtr hkcu = new UIntPtr(0x80000001u);
            string[] parts = subKey.Split('\\');
            string prefix = "";
            for (int i = 0; i < parts.Length - 1; i++) {
                if (string.IsNullOrEmpty(parts[i])) {
                    throw new ArgumentException("Invalid registry subkey segment: " + subKey);
                }
                prefix = (i == 0) ? parts[i] : (prefix + "\\" + parts[i]);
                IntPtr hAncestor = IntPtr.Zero;
                int ancErr = RegOpenKeyExW(hkcu, prefix, REG_OPTION_OPEN_LINK, KEY_QUERY_VALUE, out hAncestor);
                if (ancErr != 0) {
                    throw new Win32Exception(ancErr, "Failed to inspect registry ancestor key: HKCU:\\" + prefix);
                }
                try {
                    AssertRegistryKeyNotLink(hAncestor, "HKCU:\\" + prefix);
                } finally {
                    if (hAncestor != IntPtr.Zero) {
                        RegCloseKey(hAncestor);
                    }
                }
            }

            IntPtr hKey = IntPtr.Zero;
            int sam = KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | (int)DELETE_ACCESS;
            int openErr = RegOpenKeyExW(hkcu, subKey, REG_OPTION_OPEN_LINK, sam, out hKey);
            if (openErr != 0) {
                throw new Win32Exception(openErr, "Failed to open registry key safely with DELETE access: HKCU:\\" + subKey);
            }
            try {
                AssertRegistryKeyNotLink(hKey, "HKCU:\\" + subKey);
                uint subKeys = 0;
                int infoErr = RegQueryInfoKeyW(hKey, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, out subKeys, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
                if (infoErr != 0) {
                    throw new Win32Exception(infoErr, "Failed to inspect registry key metadata: HKCU:\\" + subKey);
                }
                if (subKeys != 0) {
                    throw new InvalidOperationException("Registry key unexpectedly contains subkeys: HKCU:\\" + subKey);
                }
                uint valType = 0;
                uint valSize = 0;
                int qErr = RegQueryValueExW(hKey, "", IntPtr.Zero, out valType, IntPtr.Zero, ref valSize);
                string actualValue = "";
                if (qErr == 0 && valSize > 0) {
                    IntPtr dataBuf = Marshal.AllocHGlobal((int)valSize);
                    try {
                        int qErr2 = RegQueryValueExW(hKey, "", IntPtr.Zero, out valType, dataBuf, ref valSize);
                        if (qErr2 != 0) {
                            throw new Win32Exception(qErr2, "Failed to read registry default value.");
                        }
                        actualValue = Marshal.PtrToStringUni(dataBuf);
                        if (actualValue != null) {
                            actualValue = actualValue.TrimEnd('\0');
                        } else {
                            actualValue = "";
                        }
                    } finally {
                        Marshal.FreeHGlobal(dataBuf);
                    }
                }
                string expected = expectedDefaultValue ?? "";
                if (!string.Equals(actualValue, expected, StringComparison.OrdinalIgnoreCase)) {
                    throw new InvalidOperationException("Registry default value changed before deletion: HKCU:\\" + subKey);
                }
                // Bind deletion directly to the validated open kernel handle rather than re-opening by path.
                int ntStatus = NtDeleteKey(hKey);
                if (ntStatus != 0) {
                    throw new InvalidOperationException("NtDeleteKey failed with NTSTATUS 0x" + ntStatus.ToString("X8") + " for HKCU:\\" + subKey);
                }
            } finally {
                if (hKey != IntPtr.Zero) {
                    RegCloseKey(hKey);
                }
            }
        }
    }
}
'@
    Add-Type -TypeDefinition $nativeSource -Language CSharp
}

function Get-NormalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.IndexOf([char]0) -ge 0) {
        throw "Path contains NUL character: $Path"
    }
    if (-not [IO.Path]::IsPathRooted($Path) -or $Path.StartsWith('\\') -or $Path.StartsWith('\\?\')) {
        throw "Only local absolute paths are allowed: $Path"
    }
    if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path -match '[*?]' -or
        $Path -match '(^|[\\/])\.\.([\\/]|$)' -or $Path -match '(^|[\\/])\.([\\/]|$)' -or
        $Path.Substring(2).Contains(':')) {
        throw "Unsafe path syntax: $Path"
    }
    foreach ($segment in ($Path.Substring(3) -split '[\\/]')) {
        if ($segment.Length -gt 0 -and $segment -match '[\s\.]$') {
            throw "Unsafe trailing space or dot in path segment: $Path"
        }
    }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd([char]'\')
    $root = [IO.Path]::GetPathRoot($full).TrimEnd([char]'\')
    if ($full -eq $root) { throw "Drive root is protected: $Path" }
    return $full
}

function Test-PathWithin {
    param([string]$Path, [string]$Root)
    $comparison = [StringComparison]::OrdinalIgnoreCase
    return ($Path.Equals($Root, $comparison) -or $Path.StartsWith($Root + '\', $comparison))
}

function Get-TargetPresenceState {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path -match '^HK[A-Z]{2}:\\') {
        try {
            $exists = Test-Path -LiteralPath $Path -ErrorAction Stop
            $st = if ($exists) { 'Present' } else { 'Absent' }
            return [pscustomobject]@{ State = $st; Error = '' }
        } catch {
            return [pscustomobject]@{ State = 'Unknown'; Error = $_.Exception.Message }
        }
    }
    try {
        $normal = Get-NormalPath $Path
        [uint32]$attrs = 0
        $exists = [ClaudeCleanup.NativeFs]::TryGetAttributes($normal, [ref]$attrs)
        $st = if ($exists) { 'Present' } else { 'Absent' }
        return [pscustomobject]@{ State = $st; Error = '' }
    } catch {
        return [pscustomobject]@{ State = 'Unknown'; Error = $_.Exception.Message }
    }
}

function Get-ExistingItem {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path -match '^HK[A-Z]{2}:\\') {
        try { return (Get-Item -LiteralPath $Path -Force -ErrorAction Stop) }
        catch [System.Management.Automation.ItemNotFoundException] { return $null }
    }
    $normal = Get-NormalPath $Path
    [uint32]$attrs = 0
    if (-not [ClaudeCleanup.NativeFs]::TryGetAttributes($normal, [ref]$attrs)) { return $null }
    try { return (Get-Item -LiteralPath $normal -Force -ErrorAction Stop) }
    catch [System.Management.Automation.ItemNotFoundException] {
        return [pscustomobject]@{
            FullName = $normal
            Attributes = [IO.FileAttributes]$attrs
            PSIsContainer = (($attrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_DIRECTORY) -ne 0)
            LastWriteTimeUtc = [DateTime]::MinValue
        }
    }
}

function Assert-NoLinkAncestors {
    param([Parameter(Mandatory = $true)][string]$Path)
    $current = Get-NormalPath $Path
    while ($current) {
        [uint32]$attrs = 0
        $exists = [ClaudeCleanup.NativeFs]::TryGetAttributes($current, [ref]$attrs)
        if ($exists -and (($attrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0)) {
            throw "Reparse point is not an approved deletion target: $current"
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent.TrimEnd([char]'\')
        if ($current -match '^[A-Za-z]:$') {
            [uint32]$rootAttrs = 0
            if ([ClaudeCleanup.NativeFs]::TryGetAttributes(($current + '\'), [ref]$rootAttrs) -and
                (($rootAttrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0)) {
                throw "Reparse point drive root is not allowed: $current\"
            }
            break
        }
    }
}

function Get-ExpectedCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$NormalPath)
    $resolved = [ClaudeCleanup.NativeFs]::ResolveLongPath($NormalPath)
    return ('\\?\' + $resolved)
}

function Assert-HandleIdentity {
    param(
        [Parameter(Mandatory = $true)][Microsoft.Win32.SafeHandles.SafeFileHandle]$Handle,
        [Parameter(Mandatory = $true)][string]$ExpectedNormalPath,
        [switch]$RequireOwnerMatch,
        [AllowNull()][Nullable[bool]]$ExpectDirectory = $null
    )
    $id = [ClaudeCleanup.NativeFs]::InspectHandle($Handle)
    if (($id.Attributes -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0) {
        throw "Linked item blocks operation: $ExpectedNormalPath"
    }
    if ($null -ne $ExpectDirectory) {
        $isDir = (($id.Attributes -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_DIRECTORY) -ne 0)
        if ($isDir -ne [bool]$ExpectDirectory) {
            throw "Target filesystem kind changed unexpectedly: $ExpectedNormalPath"
        }
    }
    $expectedFinal = Get-ExpectedCanonicalPath $ExpectedNormalPath
    if (-not $id.FinalPath.Equals($expectedFinal, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Handle final path mismatch (possible path substitution): expected=$expectedFinal actual=$($id.FinalPath)"
    }
    if ($RequireOwnerMatch) {
        $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if (-not $id.OwnerSid.Equals($currentSid, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Target is not owned by the current user: $ExpectedNormalPath"
        }
    }
    return $id
}

function Assert-AuthorizedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$AllowedRoots
    )
    $full = Get-NormalPath $Path
    $normalizedAllowedRoots = @($AllowedRoots | ForEach-Object { Get-NormalPath $_ })
    $testSandbox = Get-NormalPath (Join-Path $script:ProjectRoot 'tests\sandbox')
    $isApprovedTestPath = (Test-PathWithin $full $testSandbox) -and
        (@($normalizedAllowedRoots | Where-Object { Test-PathWithin $_ $testSandbox }).Count -eq $normalizedAllowedRoots.Count) -and
        ($normalizedAllowedRoots.Count -gt 0)

    $subtreeProtected = @(
        $env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $script:ProjectRoot,
        (Join-Path $env:USERPROFILE '.codex'),
        (Join-Path $env:USERPROFILE '.agents'),
        (Join-Path $env:USERPROFILE '.gemini')
    )
    foreach ($p in $subtreeProtected) {
        if (-not $p) { continue }
        $base = Get-NormalPath $p
        $allowSandboxUnderBase = $isApprovedTestPath -and (
            $base.Equals($script:ProjectRoot, [StringComparison]::OrdinalIgnoreCase) -or
            (Test-PathWithin $script:ProjectRoot $base)
        )
        if ((Test-PathWithin $full $base) -and -not $allowSandboxUnderBase) {
            throw "Protected path: $full"
        }
    }

    $exactRootProtected = @(
        $env:USERPROFILE, $env:APPDATA, $env:LOCALAPPDATA, $env:ProgramData,
        $env:PUBLIC, $env:TEMP, $env:TMP
    )
    foreach ($p in $exactRootProtected) {
        if (-not $p) { continue }
        $base = Get-NormalPath $p
        if ($full.Equals($base, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Protected root path cannot be targeted directly: $full"
        }
    }

    $allowed = $false
    foreach ($base in $normalizedAllowedRoots) {
        if (Test-PathWithin $full $base) { $allowed = $true; break }
    }
    if (-not $allowed) { throw "Path is not on the exact allowlist: $full" }

    Assert-NoLinkAncestors $full

    [uint32]$attrs = 0
    if ([ClaudeCleanup.NativeFs]::TryGetAttributes($full, [ref]$attrs)) {
        if (($attrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0) {
            throw "Reparse point is not an approved deletion target: $full"
        }
        $isDir = (($attrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_DIRECTORY) -ne 0)
        [int]$err = 0
        $handle = [ClaudeCleanup.NativeFs]::OpenHandle($full, $false, $isDir, [ref]$err)
        try {
            if ($handle.IsInvalid) {
                throw (New-Object System.ComponentModel.Win32Exception($err, "Cannot open target for identity check: $full"))
            }
            Assert-HandleIdentity -Handle $handle -ExpectedNormalPath $full -RequireOwnerMatch -ExpectDirectory:$isDir | Out-Null
        } finally {
            if ($null -ne $handle) { $handle.Dispose() }
        }
    }
    return $full
}

function Test-SafeTarget {
    param([string]$Path, [string[]]$AllowedRoots)
    try {
        $full = Assert-AuthorizedPath -Path $Path -AllowedRoots $AllowedRoots
        return [pscustomobject]@{ Allowed = $true; Path = $full; Reason = '' }
    } catch {
        return [pscustomobject]@{ Allowed = $false; Path = $Path; Reason = $_.Exception.Message }
    }
}

function Get-SafeTreeSnapshot {
    param([Parameter(Mandatory = $true)][string]$Path)
    $normal = Get-NormalPath $Path
    Assert-NoLinkAncestors $normal
    [uint32]$rootAttrs = 0
    if (-not [ClaudeCleanup.NativeFs]::TryGetAttributes($normal, [ref]$rootAttrs)) {
        throw [System.Management.Automation.ItemNotFoundException]::new("Path not found: $normal")
    }
    if (($rootAttrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0) {
        throw "Linked item blocks inspection: $normal"
    }
    $rootIsDir = (($rootAttrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_DIRECTORY) -ne 0)
    [int]$err = 0
    $rootHandle = [ClaudeCleanup.NativeFs]::OpenHandle($normal, $false, $rootIsDir, [ref]$err)
    try {
        if ($rootHandle.IsInvalid) {
            throw (New-Object System.ComponentModel.Win32Exception($err, "Cannot open target: $normal"))
        }
        $rootId = Assert-HandleIdentity -Handle $rootHandle -ExpectedNormalPath $normal -RequireOwnerMatch -ExpectDirectory:$rootIsDir
        if (-not $rootIsDir) {
            return [pscustomobject]@{
                Bytes = [long]$rootId.Length
                Entries = 1
                VolumeSerialNumber = [uint32]$rootId.VolumeSerialNumber
                FileIndex = [uint64]$rootId.FileIndex
                LastWriteUtcTicks = [long]$rootId.LastWriteUtcTicks
                MaxLastWriteUtcTicks = [long]$rootId.LastWriteUtcTicks
                NumberOfLinks = [uint32]$rootId.NumberOfLinks
            }
        }
    } finally {
        if ($null -ne $rootHandle) { $rootHandle.Dispose() }
    }

    $bytes = [long]0
    $count = 0
    $maxTicks = [long]$rootId.LastWriteUtcTicks
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($normal)
    while ($stack.Count -gt 0) {
        $dirPath = $stack.Pop()
        [int]$dErr = 0
        $dHandle = [ClaudeCleanup.NativeFs]::OpenHandle($dirPath, $false, $true, [ref]$dErr)
        try {
            if ($dHandle.IsInvalid) {
                throw (New-Object System.ComponentModel.Win32Exception($dErr, "Cannot open directory: $dirPath"))
            }
            $dId = Assert-HandleIdentity -Handle $dHandle -ExpectedNormalPath $dirPath -RequireOwnerMatch -ExpectDirectory:$true
            $count++
            if ($count -gt 100000) { throw 'Size measurement limit reached (100000 entries)' }
            if ($dId.LastWriteUtcTicks -gt $maxTicks) { $maxTicks = $dId.LastWriteUtcTicks }
            $children = [ClaudeCleanup.NativeFs]::EnumerateHandleChildren($dHandle)
            foreach ($child in $children) {
                if (($child.Attributes -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0) {
                    throw "Linked item blocks inspection: $(Join-Path $dirPath $child.Name)"
                }
                if ($child.Name -match '[*?:/\\]' -or $child.Name -eq '.' -or $child.Name -eq '..') {
                    throw "Unsafe child name in directory: $dirPath"
                }
                $childPath = Join-Path $dirPath $child.Name
                $childIsDir = (($child.Attributes -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_DIRECTORY) -ne 0)
                if ($childIsDir) {
                    $stack.Push($childPath)
                } else {
                    [int]$fErr = 0
                    $fHandle = [ClaudeCleanup.NativeFs]::OpenHandle($childPath, $false, $false, [ref]$fErr)
                    try {
                        if ($fHandle.IsInvalid) {
                            if ($fErr -notin @(32, 33)) {
                                throw (New-Object System.ComponentModel.Win32Exception($fErr, "Cannot open child file for ownership check: $childPath"))
                            }
                        } else {
                            Assert-HandleIdentity -Handle $fHandle -ExpectedNormalPath $childPath -RequireOwnerMatch -ExpectDirectory:$false | Out-Null
                        }
                    } finally {
                        if ($null -ne $fHandle) { $fHandle.Dispose() }
                    }
                    $count++
                    if ($count -gt 100000) { throw 'Size measurement limit reached (100000 entries)' }
                    $bytes += [long]$child.EndOfFile
                    if ($child.LastWriteUtcTicks -gt $maxTicks) { $maxTicks = $child.LastWriteUtcTicks }
                }
            }
        } finally {
            if ($null -ne $dHandle) { $dHandle.Dispose() }
        }
    }

    return [pscustomobject]@{
        Bytes = $bytes
        Entries = $count
        VolumeSerialNumber = [uint32]$rootId.VolumeSerialNumber
        FileIndex = [uint64]$rootId.FileIndex
        LastWriteUtcTicks = [long]$rootId.LastWriteUtcTicks
        MaxLastWriteUtcTicks = [long]$maxTicks
        NumberOfLinks = [uint32]$rootId.NumberOfLinks
    }
}

function Assert-TreeWithoutLinks {
    param([Parameter(Mandatory = $true)][string]$Path)
    Get-SafeTreeSnapshot -Path $Path | Out-Null
}

function Get-SafeSize {
    param([string]$Path)
    return (Get-SafeTreeSnapshot -Path $Path)
}

function Invoke-HandleTreeDeletion {
    param(
        [Parameter(Mandatory = $true)][string]$NormalPath,
        [AllowNull()][Nullable[uint64]]$ExpectedFileIndex = $null,
        [AllowNull()][Nullable[uint32]]$ExpectedVolumeSerial = $null,
        [switch]$RequireOwnerMatch
    )
    $state = [pscustomobject]@{
        ItemsRemoved = 0
        ItemsFailed = 0
        Errors = (New-Object 'System.Collections.Generic.List[string]')
        AbortTree = $false
    }

    function Remove-NodeByHandle {
        param(
            [string]$NodePath,
            [Nullable[uint64]]$NodeExpectedFileIndex,
            [Nullable[uint32]]$NodeExpectedVolumeSerial,
            [bool]$CheckOwner
        )
        [uint32]$attrs = 0
        if (-not [ClaudeCleanup.NativeFs]::TryGetAttributes($NodePath, [ref]$attrs)) {
            return
        }
        if (($attrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0) {
            throw "Linked item blocks removal: $NodePath"
        }
        $isDir = (($attrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_DIRECTORY) -ne 0)
        [int]$openErr = 0
        $handle = [ClaudeCleanup.NativeFs]::OpenHandle($NodePath, $true, $isDir, [ref]$openErr)
        $hadChildSecurityError = $false
        try {
            if ($handle.IsInvalid) {
                if ([ClaudeCleanup.NativeFs]::IsNotFoundError($openErr)) { return }
                throw (New-Object System.ComponentModel.Win32Exception($openErr, "Failed to open handle for deletion: $NodePath"))
            }
            $id = Assert-HandleIdentity -Handle $handle -ExpectedNormalPath $NodePath -RequireOwnerMatch:$CheckOwner -ExpectDirectory:$isDir
            if ($null -ne $NodeExpectedVolumeSerial -and $id.VolumeSerialNumber -ne [uint32]$NodeExpectedVolumeSerial) {
                $hadChildSecurityError = $true
                throw "Target volume changed before deletion: $NodePath"
            }
            if ($null -ne $NodeExpectedFileIndex -and [uint64]$NodeExpectedFileIndex -ne 0 -and $id.FileIndex -ne [uint64]$NodeExpectedFileIndex) {
                $hadChildSecurityError = $true
                throw "Target file identity (FileIndex) changed before deletion: $NodePath"
            }
            $dirStartFails = $state.ItemsFailed
            if ($isDir) {
                $children = [ClaudeCleanup.NativeFs]::EnumerateHandleChildren($handle)
                foreach ($child in $children) {
                    if (($child.Attributes -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0) {
                        $hadChildSecurityError = $true
                        throw "Linked child blocks removal: $(Join-Path $NodePath $child.Name)"
                    }
                    $childPath = Join-Path $NodePath $child.Name
                    if ($childPath -match '(^|[\\/])\.\.?$' -or $child.Name -match '[*?:/\\]') {
                        $hadChildSecurityError = $true
                        throw "Unsafe child path during removal: $childPath"
                    }
                    $childIdx = if ($child.FileIndex -ne 0) { [Nullable[uint64]]$child.FileIndex } else { $null }
                    Remove-NodeByHandle -NodePath $childPath -NodeExpectedFileIndex $childIdx -NodeExpectedVolumeSerial $id.VolumeSerialNumber -CheckOwner $CheckOwner
                    if ($state.AbortTree) { return }
                }
            }
            if ($state.ItemsFailed -eq $dirStartFails) {
                [ClaudeCleanup.NativeFs]::DeleteHandleObject($handle, $id.Attributes)
                $state.ItemsRemoved++
            }
        } catch {
            $state.ItemsFailed++
            $state.Errors.Add($_.Exception.Message)
            if ($hadChildSecurityError -or $_.Exception.Message -match 'Owner mismatch|Reparse point|Linked child|Unsafe child|changed before deletion|outside allowlist|symlink') {
                $state.AbortTree = $true
            }
        } finally {
            if ($null -ne $handle) { $handle.Dispose() }
        }
    }

    Remove-NodeByHandle -NodePath $NormalPath -NodeExpectedFileIndex $ExpectedFileIndex -NodeExpectedVolumeSerial $ExpectedVolumeSerial -CheckOwner ([bool]$RequireOwnerMatch)
    return $state
}

function New-SafeFileRemovalResult {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Status,
        [int]$ItemsRemoved = 0,
        [int]$ItemsFailed = 0,
        [bool]$PartialRemoval = $false,
        [AllowNull()]$RemainingExists = $false,
        [Parameter(Mandatory = $true)][string]$PresenceState,
        [bool]$VerifiedAbsent = $false,
        [AllowEmptyString()][string]$Error = ''
    )
    return [pscustomobject]@{
        Path = $Path
        Status = $Status
        ItemsRemoved = $ItemsRemoved
        ItemsFailed = $ItemsFailed
        PartialRemoval = $PartialRemoval
        RemainingExists = $RemainingExists
        PresenceState = $PresenceState
        VerifiedAbsent = $VerifiedAbsent
        Error = $Error
    }
}

function Invoke-SafeFileRemoval {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$AllowedRoots,
        [AllowNull()][Nullable[uint64]]$ExpectedFileIndex = $null,
        [AllowNull()][Nullable[uint32]]$ExpectedVolumeSerial = $null,
        [switch]$ReturnFailureResult
    )
    $full = Assert-AuthorizedPath -Path $Path -AllowedRoots $AllowedRoots
    $preState = Get-TargetPresenceState $full
    if ($preState.State -eq 'Unknown') {
        $preErr = "Cannot verify target state before removal (Unknown): $($preState.Error)"
        $unknownResult = New-SafeFileRemovalResult -Path $full -Status 'Failed' -ItemsFailed 1 -RemainingExists $null -PresenceState 'Unknown' -Error $preErr
        if ($ReturnFailureResult) { return $unknownResult }
        $ex = New-Object System.IO.IOException($preErr)
        $ex.Data['RemovalResult'] = $unknownResult
        throw $ex
    }
    if ($preState.State -eq 'Absent') {
        return (New-SafeFileRemovalResult -Path $full -Status 'AlreadyAbsent' -PresenceState 'Absent' -VerifiedAbsent $true)
    }
    Assert-TreeWithoutLinks $full
    if ($PSCmdlet.ShouldProcess($full, 'Permanently remove')) {
        $delState = Invoke-HandleTreeDeletion -NormalPath $full -ExpectedFileIndex $ExpectedFileIndex -ExpectedVolumeSerial $ExpectedVolumeSerial -RequireOwnerMatch
        $postState = Get-TargetPresenceState $full
        $remaining = if ($postState.State -eq 'Present') { $true } elseif ($postState.State -eq 'Absent') { $false } else { $null }
        if ($delState.ItemsFailed -gt 0 -or $postState.State -ne 'Absent') {
            $errParts = New-Object 'System.Collections.Generic.List[string]'
            if ($delState.Errors.Count -gt 0) { $errParts.Add(($delState.Errors -join '; ')) }
            if ($postState.State -eq 'Present') { $errParts.Add("Target still exists after deletion attempt: $full") }
            elseif ($postState.State -eq 'Unknown') { $errParts.Add("Post-deletion presence check failed (Unknown): $($postState.Error)") }
            $errText = $errParts -join '; '
            $failResult = New-SafeFileRemovalResult -Path $full -Status 'Failed' -ItemsRemoved $delState.ItemsRemoved -ItemsFailed ([Math]::Max(1, $delState.ItemsFailed)) -PartialRemoval ($delState.ItemsRemoved -gt 0 -and ($postState.State -ne 'Absent')) -RemainingExists $remaining -PresenceState $postState.State -Error $errText
            if ($ReturnFailureResult) { return $failResult }
            $ex = New-Object System.IO.IOException($errText)
            $ex.Data['RemovalResult'] = $failResult
            throw $ex
        }
        return (New-SafeFileRemovalResult -Path $full -Status 'Removed' -ItemsRemoved $delState.ItemsRemoved -PresenceState 'Absent' -VerifiedAbsent $true)
    }
    return (New-SafeFileRemovalResult -Path $full -Status 'PreviewOnly' -RemainingExists $true -PresenceState 'Present')
}

function Get-Sha256FromBytes {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    return (Get-Sha256FromBytes -Bytes $bytes)
}

function Assert-ManifestAuthorization {
    param([string]$ManifestPath, [string]$ApprovedHash)
    if (-not $ApprovedHash -or $ApprovedHash -notmatch '^[A-Fa-f0-9]{64}$') { throw 'An approved SHA-256 manifest hash is required.' }
    if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "Manifest file not found: $ManifestPath" }
    $actual = Get-Sha256 -Path $ManifestPath
    if (-not $actual.Equals($ApprovedHash, [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest hash does not match approval.' }
    return $true
}

function Test-ManifestAuthorization {
    param([string]$ManifestPath, [string]$ApprovedHash)
    Assert-ManifestAuthorization -ManifestPath $ManifestPath -ApprovedHash $ApprovedHash | Out-Null
    return $true
}

function Get-ClaudeAppxPackage {
    $previous = $WhatIfPreference
    $WhatIfPreference = $false
    try { Get-AppxPackage -Name 'Claude' -ErrorAction Stop }
    finally { $WhatIfPreference = $previous }
}

function Get-Candidate {
    param([string]$Id, [string]$Path, [string]$Category, [string]$Policy,
        [string]$Kind = 'Filesystem', [string]$Warning = '', [string]$Decision = 'Ready',
        [AllowNull()][string]$Identity = $null)
    return [pscustomobject]@{ Id = $Id; Path = $Path; Category = $Category; Policy = $Policy;
        Kind = $Kind; Warning = $Warning; Decision = $Decision; Identity = $Identity }
}

function Resolve-SidToAccountName {
    param([Parameter(Mandatory = $true)][string]$SidValue)
    try {
        $sidObj = New-Object System.Security.Principal.SecurityIdentifier($SidValue)
        return $sidObj.Translate([System.Security.Principal.NTAccount]).Value
    } catch {
        return $SidValue
    }
}

function Get-PathAclDiagnostics {
    param([Parameter(Mandatory = $true)][string]$Path)
    $pres = Get-TargetPresenceState $Path
    if ($pres.State -ne 'Present') {
        return [pscustomobject]@{
            Path = $Path
            State = $pres.State
            Owner = $null
            OwnerSid = $null
            IsCurrentUserOwner = $null
            IsBuiltinAdminOwned = $null
            ProtectedFromInheritance = $null
            ExplicitDenyCount = $null
            Status = if ($pres.State -eq 'Absent') { 'Absent' } else { 'AccessDenied' }
            Error = $pres.Error
        }
    }
    try {
        $normal = Get-NormalPath $Path
        [uint32]$attrs = 0
        [void][ClaudeCleanup.NativeFs]::TryGetAttributes($normal, [ref]$attrs)
        if (($attrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_REPARSE_POINT) -ne 0) {
            return [pscustomobject]@{
                Path = $normal; State = 'Present'; Owner = $null; OwnerSid = $null
                IsCurrentUserOwner = $null; IsBuiltinAdminOwned = $null
                ProtectedFromInheritance = $null; ExplicitDenyCount = $null
                Status = 'ReparseBlocked'; Error = 'Reparse point blocks direct ACL inspection/deletion'
            }
        }
        $isDir = (($attrs -band [ClaudeCleanup.NativeFs]::FILE_ATTRIBUTE_DIRECTORY) -ne 0)
        [int]$err = 0
        $handle = [ClaudeCleanup.NativeFs]::OpenHandle($normal, $false, $isDir, [ref]$err)
        try {
            if ($handle.IsInvalid) {
                throw (New-Object System.ComponentModel.Win32Exception($err, "Cannot open target for ACL diagnostics: $normal"))
            }
            $id = [ClaudeCleanup.NativeFs]::InspectHandle($handle)
            $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $isOwner = $id.OwnerSid.Equals($currentSid, [StringComparison]::OrdinalIgnoreCase)
            $isAdmin = $id.OwnerSid.Equals('S-1-5-32-544', [StringComparison]::OrdinalIgnoreCase)
            $ownerName = Resolve-SidToAccountName -SidValue $id.OwnerSid
            $protected = $null
            $denyCount = $null
            try {
                $acl = Get-Acl -LiteralPath $normal -ErrorAction Stop
                $protected = $acl.AreAccessRulesProtected
                $denyCount = @($acl.Access | Where-Object { $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny }).Count
            } catch {}
            $status = if ($isOwner) { 'Ok' } elseif ($isAdmin) { 'AdminOwned' } else { 'OtherOwner' }
            return [pscustomobject]@{
                Path = $normal
                State = 'Present'
                Owner = $ownerName
                OwnerSid = $id.OwnerSid
                IsCurrentUserOwner = $isOwner
                IsBuiltinAdminOwned = $isAdmin
                ProtectedFromInheritance = $protected
                ExplicitDenyCount = $denyCount
                Status = $status
                Error = ''
            }
        } finally {
            if ($null -ne $handle) { $handle.Dispose() }
        }
    } catch {
        return [pscustomobject]@{
            Path = $Path; State = 'Unknown'; Owner = $null; OwnerSid = $null
            IsCurrentUserOwner = $false; IsBuiltinAdminOwned = $null
            ProtectedFromInheritance = $null; ExplicitDenyCount = $null
            Status = 'AccessDenied'; Error = $_.Exception.Message
        }
    }
}

function Get-NpmPrefixCandidates {
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $addPrefix = {
        param([string]$RawPath)
        if ([string]::IsNullOrWhiteSpace($RawPath)) { return }
        try {
            $norm = Get-NormalPath $RawPath.Trim()
            if ($seen.Add($norm)) { $candidates.Add($norm) }
        } catch {}
    }
    $envPrefix = [Environment]::GetEnvironmentVariable('NPM_CONFIG_PREFIX')
    & $addPrefix $envPrefix
    $npmrc = Join-Path $env:USERPROFILE '.npmrc'
    if ((Get-TargetPresenceState $npmrc).State -eq 'Present') {
        try {
            foreach ($line in (Get-Content -LiteralPath $npmrc -ErrorAction Stop)) {
                if ($line -match '^\s*prefix\s*=\s*(.+)$') {
                    $val = $matches[1].Trim().Trim('"').Trim("'")
                    & $addPrefix $val
                }
            }
        } catch {}
    }
    & $addPrefix (Join-Path $env:APPDATA 'npm')
    if ($env:ProgramFiles) { & $addPrefix (Join-Path $env:ProgramFiles 'nodejs') }
    return $candidates.ToArray()
}

function New-BlockedNpmInstallation {
    param(
        [Parameter(Mandatory = $true)][string]$PackagePath,
        [Parameter(Mandatory = $true)][string]$PrefixPath,
        [Parameter(Mandatory = $true)][string]$BlockReason
    )
    return [pscustomobject]@{
        PackagePath = $PackagePath
        PrefixPath = $PrefixPath
        Version = $null
        Shims = @()
        SafeToUninstall = $false
        BlockReason = $BlockReason
    }
}

function Get-NpmClaudePackageInstallations {
    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($prefix in (Get-NpmPrefixCandidates)) {
        $pkgDir = Join-Path $prefix 'node_modules\@anthropic-ai\claude-code'
        $pkgJsonPath = Join-Path $pkgDir 'package.json'
        $pkgState = Get-TargetPresenceState $pkgJsonPath
        if ($pkgState.State -eq 'Absent') { continue }
        if ($pkgState.State -eq 'Unknown') {
            $results.Add((New-BlockedNpmInstallation -PackagePath $pkgDir -PrefixPath $prefix -BlockReason "Cannot inspect npm package.json: $($pkgState.Error)"))
            continue
        }
        try {
            $pkgMeta = Get-Content -LiteralPath $pkgJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($pkgMeta.name -ne '@anthropic-ai/claude-code') { continue }
            $safePkg = Test-SafeTarget -Path $pkgDir -AllowedRoots @($pkgDir)
            $shims = New-Object 'System.Collections.Generic.List[string]'
            foreach ($shimName in @('claude', 'claude.cmd', 'claude.ps1')) {
                $shimPath = Join-Path $prefix $shimName
                if ((Get-TargetPresenceState $shimPath).State -eq 'Present') { $shims.Add($shimPath) }
            }
            $results.Add([pscustomobject]@{
                PackagePath = $pkgDir
                PrefixPath = $prefix
                Version = [string]$pkgMeta.version
                Shims = $shims.ToArray()
                SafeToUninstall = [bool]$safePkg.Allowed
                BlockReason = if ($safePkg.Allowed) { '' } else { $safePkg.Reason }
            })
        } catch {
            $results.Add((New-BlockedNpmInstallation -PackagePath $pkgDir -PrefixPath $prefix -BlockReason "Cannot parse npm package metadata: $($_.Exception.Message)"))
        }
    }
    return $results.ToArray()
}

function Get-AppDataClassification {
    $rows = New-Object 'System.Collections.Generic.List[object]'
    $roamingClaude = Join-Path $env:APPDATA 'Claude'
    $localClaude = Join-Path $env:LOCALAPPDATA 'Claude'
    $specs = @(
        @($roamingClaude, 'Cache', 'Cache'),
        @($roamingClaude, 'Code Cache', 'Cache'),
        @($roamingClaude, 'GPUCache', 'Cache'),
        @($roamingClaude, 'DawnGraphiteCache', 'Cache'),
        @($roamingClaude, 'DawnWebGPUCache', 'Cache'),
        @($roamingClaude, 'logs', 'Diagnostics'),
        @($roamingClaude, 'Crashpad', 'Diagnostics'),
        @($roamingClaude, 'buddy-tokens.json', 'AuthReview'),
        @($roamingClaude, 'Cookies', 'AuthReview'),
        @($roamingClaude, 'Network', 'AuthReview'),
        @($roamingClaude, 'Local Storage', 'UserSessionOrMixed'),
        @($roamingClaude, 'IndexedDB', 'UserSessionOrMixed'),
        @($roamingClaude, 'local-agent-mode-sessions', 'UserSessionOrMixed'),
        @($roamingClaude, 'claude-code-sessions', 'UserSessionOrMixed'),
        @($roamingClaude, 'claude-code-vm', 'UserSessionOrMixed'),
        @($roamingClaude, 'vm_bundles', 'UserSessionOrMixed'),
        @($roamingClaude, 'Claude Extensions', 'UserSessionOrMixed'),
        @($roamingClaude, 'claude_desktop_config.json', 'UserSessionOrMixed'),
        @($roamingClaude, 'claude_desktop_config.json.rea.backup', 'UserSessionOrMixed'),
        @($localClaude, 'logs', 'Diagnostics'),
        @((Join-Path $env:LOCALAPPDATA 'Claude-3p'), '', 'AmbiguousLegacy'),
        @((Join-Path $env:APPDATA 'Claude-3p'), '', 'AmbiguousLegacy')
    )
    foreach ($s in $specs) {
        $target = if ([string]::IsNullOrEmpty($s[1])) { $s[0] } else { Join-Path $s[0] $s[1] }
        $st = Get-TargetPresenceState $target
        if ($st.State -eq 'Absent') { continue }
        $acl = Get-PathAclDiagnostics -Path $target
        $rows.Add([pscustomobject]@{
            Path = $target
            Name = if ([string]::IsNullOrEmpty($s[1])) { Split-Path -Leaf $s[0] } else { $s[1] }
            Role = $s[2]
            PresenceState = $st.State
            OwnerStatus = $acl.Status
            Owner = $acl.Owner
        })
    }
    $pkgRoot = Join-Path $env:LOCALAPPDATA 'Packages'
    if ((Get-TargetPresenceState $pkgRoot).State -eq 'Present') {
        foreach ($pivot in (Get-ChildItem -LiteralPath $pkgRoot -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^0_https___pivot\.claude\.ai' })) {
            $acl = Get-PathAclDiagnostics -Path $pivot.FullName
            $rows.Add([pscustomobject]@{
                Path = $pivot.FullName
                Name = $pivot.Name
                Role = 'AmbiguousLegacy'
                PresenceState = 'Present'
                OwnerStatus = $acl.Status
                Owner = $acl.Owner
            })
        }
    }
    return $rows.ToArray()
}

function Get-ClaudeShortcutResiduals {
    $shortcuts = New-Object 'System.Collections.Generic.List[object]'
    $roots = @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
        (Join-Path $env:USERPROFILE 'Desktop'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs')
    )
    $shell = $null
    try {
        foreach ($root in $roots) {
            if (-not $root -or (Get-TargetPresenceState $root).State -ne 'Present') { continue }
            foreach ($lnk in (Get-ChildItem -LiteralPath $root -Filter '*.lnk' -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '(?i)claude' })) {
                $targetPath = $null
                try {
                    if ($null -eq $shell) { $shell = New-Object -ComObject WScript.Shell }
                    $sc = $shell.CreateShortcut($lnk.FullName)
                    $targetPath = $sc.TargetPath
                } catch {}
                $shortcuts.Add([pscustomobject]@{
                    ShortcutPath = $lnk.FullName
                    TargetPath = $targetPath
                    Decision = 'ReviewOnly'
                })
            }
        }
    } finally {
        if ($null -ne $shell) {
            try { [Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null } catch {}
        }
    }
    return $shortcuts.ToArray()
}

function Get-VsCodeClaudeDiscovery {
    $codeCmd = try { Get-VsCodeCliCommand } catch { $null }
    $extRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
    $extRootState = Get-TargetPresenceState $extRoot
    $dirs = New-Object 'System.Collections.Generic.List[object]'
    if ($extRootState.State -eq 'Present') {
        foreach ($ext in (Get-ChildItem -LiteralPath $extRoot -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^anthropic\.claude-code-[0-9]' })) {
            $metadata = Join-Path $ext.FullName 'package.json'
            try {
                $package = Get-Content -LiteralPath $metadata -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                if ($package.publisher -eq 'anthropic' -and $package.name -eq 'claude-code') {
                    $dirs.Add([pscustomobject]@{
                        Name = $ext.Name
                        FullName = $ext.FullName
                        Version = [string]$package.version
                    })
                }
            } catch { continue }
        }
    }
    $obsolete = Join-Path $extRoot '.obsolete'
    $obsoleteState = Get-TargetPresenceState $obsolete
    $obsoleteHasClaude = $false
    if ($obsoleteState.State -eq 'Present') {
        $obsoleteText = Get-Content -LiteralPath $obsolete -Raw -ErrorAction SilentlyContinue
        $obsoleteHasClaude = [bool]($obsoleteText -match '(?i)anthropic\.claude-code')
    }
    return [pscustomobject]@{
        CodeCliPath = if ($codeCmd) { $codeCmd.Source } else { $null }
        ExtensionsRoot = $extRoot
        ExtensionsRootState = $extRootState.State
        ExtensionsRootError = $extRootState.Error
        ExtensionDirs = $dirs.ToArray()
        ObsoletePath = $obsolete
        ObsoleteState = $obsoleteState.State
        ObsoleteError = $obsoleteState.Error
        ObsoleteReferencesClaude = $obsoleteHasClaude
    }
}

function Test-SafeReadableConfigFile {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [int64]$MaxBytes = 2097152
    )

    if ([string]::IsNullOrWhiteSpace($FilePath)) { return $false }
    if ((Get-TargetPresenceState -Path $FilePath).State -ne 'Present') { return $false }
    try {
        $item = Get-Item -LiteralPath $FilePath -Force -ErrorAction Stop
        if ($item.PSIsContainer) { return $false }
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
        if ($item.Length -le 0 -or $item.Length -gt $MaxBytes) { return $false }
        $parent = Split-Path -Parent $item.FullName
        while (-not [string]::IsNullOrWhiteSpace($parent)) {
            $pItem = Get-Item -LiteralPath $parent -Force -ErrorAction Stop
            if (($pItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
            $nextParent = Split-Path -Parent $parent
            if ($nextParent -eq $parent) { break }
            $parent = $nextParent
        }
        return $true
    } catch {
        return $false
    }
}

function Find-SafeClaudeAccountIdentifiersFromObject {
    param(
        [AllowNull()][object]$Node,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Results,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$SeenKeys,
        [int]$Depth = 0
    )

    if ($null -eq $Node -or $Depth -gt 5) { return }

    if ($Node -is [System.Collections.IDictionary]) {
        $keys = @($Node.Keys)
    } elseif ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($elem in $Node) {
            Find-SafeClaudeAccountIdentifiersFromObject -Node $elem -Source $Source -ConfigPath $ConfigPath -Results $Results -SeenKeys $SeenKeys -Depth ($Depth + 1)
        }
        return
    } elseif ($Node.PSObject -and $Node.PSObject.Properties) {
        $keys = @($Node.PSObject.Properties | ForEach-Object { $_.Name })
    } else {
        return
    }

    # Strictly allowlist ONLY non-secret identifier field names for user verification.
    $allowedFieldMap = @{
        'accountuuid'      = 'AccountUuid'
        'organizationuuid' = 'OrganizationUuid'
        'orguuid'          = 'OrganizationUuid'
        'userid'           = 'UserId'
        'anonymousid'      = 'DeviceId'
        'deviceid'         = 'DeviceId'
        'installationid'   = 'DeviceId'
        'clientid'         = 'DeviceId'
    }

    foreach ($k in $keys) {
        $kStr = [string]$k
        $kLower = $kStr.ToLowerInvariant()
        $val = if ($Node -is [System.Collections.IDictionary]) { $Node[$k] } else { $Node.$kStr }

        if ($allowedFieldMap.ContainsKey($kLower)) {
            if ($val -is [string] -or $val -is [ValueType]) {
                $sVal = ([string]$val).Trim()
                if (-not [string]::IsNullOrWhiteSpace($sVal) -and
                    ($sVal -match '^[A-Za-z0-9._:-]{6,128}$') -and
                    ($sVal -notmatch '@') -and
                    ($sVal -notmatch '(?i)^(?:sk-|ghp_|github_pat_|eyJ|Bearer\b)')) {
                    $dedupKey = "$Source|$kLower|$sVal"
                    if ($SeenKeys.Add($dedupKey)) {
                        $Results.Add([pscustomobject]@{
                            Source     = $Source
                            ConfigPath = $ConfigPath
                            Field      = $kStr
                            IdType     = $allowedFieldMap[$kLower]
                            Value      = $sVal
                        })
                    }
                }
            }
            continue
        }

        # Never inspect credential/secret/token/cookie/email properties or branches.
        if ($kLower -match 'token|secret|password|key|cookie|credential|email|session') {
            continue
        }

        if ($null -ne $val -and -not ($val -is [string]) -and -not ($val -is [ValueType])) {
            Find-SafeClaudeAccountIdentifiersFromObject -Node $val -Source $Source -ConfigPath $ConfigPath -Results $Results -SeenKeys $SeenKeys -Depth ($Depth + 1)
        }
    }
}

function Get-ClaudeResidualAccountMetadata {
    param(
        [string]$ClaudeCliConfigPath = (Join-Path $env:USERPROFILE '.claude.json'),
        [string]$ClaudeCliDir = (Join-Path $env:USERPROFILE '.claude'),
        [string]$ClaudeDesktopDir = (Join-Path $env:APPDATA 'Claude')
    )

    $results = New-Object 'System.Collections.Generic.List[object]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    $candidates = New-Object 'System.Collections.Generic.List[object]'
    if (-not [string]::IsNullOrWhiteSpace($ClaudeCliConfigPath)) {
        $candidates.Add([pscustomobject]@{ Source = 'Claude Code CLI'; Path = $ClaudeCliConfigPath })
    }
    if (-not [string]::IsNullOrWhiteSpace($ClaudeCliDir)) {
        foreach ($name in @('config.json', 'settings.json', 'settings.local.json')) {
            $candidates.Add([pscustomobject]@{ Source = 'Claude Code CLI'; Path = (Join-Path $ClaudeCliDir $name) })
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ClaudeDesktopDir)) {
        foreach ($rel in @('config.json', 'claude_desktop_config.json', 'Preferences', 'Local State', 'sentry\scope_v3.json', 'window-state.json')) {
            $candidates.Add([pscustomobject]@{ Source = 'Claude Desktop'; Path = (Join-Path $ClaudeDesktopDir $rel) })
        }
    }

    foreach ($cand in $candidates) {
        $leaf = [IO.Path]::GetFileName($cand.Path)
        # Never open credential or secret-bearing files (for example .credentials.json)
        if ($leaf -match '(?i)credential|secret|token|\.env') { continue }
        if (-not (Test-SafeReadableConfigFile -FilePath $cand.Path)) { continue }

        try {
            $raw = [IO.File]::ReadAllText($cand.Path, [System.Text.Encoding]::UTF8)
            if ([string]::IsNullOrWhiteSpace($raw)) { continue }
            $trimmed = $raw.TrimStart()
            if (-not ($trimmed.StartsWith('{') -or $trimmed.StartsWith('['))) { continue }
            $parsed = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
            Find-SafeClaudeAccountIdentifiersFromObject -Node $parsed -Source $cand.Source -ConfigPath $cand.Path -Results $results -SeenKeys $seen
        } catch {
            continue
        }
    }

    return @($results.ToArray())
}

function Get-WindowsResidualSummary {
    $pathEntries = New-Object 'System.Collections.Generic.List[object]'
    foreach ($scope in @('User', 'Machine')) {
        $pathValue = [Environment]::GetEnvironmentVariable('PATH', $scope)
        foreach ($entry in @($pathValue -split ';')) {
            if ($entry -match '(?i)claude|anthropic|[\\/]\.local[\\/]bin$') {
                $pathEntries.Add([pscustomobject]@{ Scope = $scope; Entry = $entry })
            }
        }
    }
    $envVarNames = New-Object 'System.Collections.Generic.List[object]'
    foreach ($scope in @('User', 'Machine')) {
        foreach ($name in [Environment]::GetEnvironmentVariables($scope).Keys) {
            if ($name -match '(?i)claude|anthropic') {
                $envVarNames.Add([pscustomobject]@{ Scope = $scope; Name = $name })
            }
        }
    }
    $overridePaths = New-Object 'System.Collections.Generic.List[object]'
    foreach ($name in @('CLAUDE_CONFIG_DIR', 'CLAUDE_USER_DATA_DIR')) {
        $val = [Environment]::GetEnvironmentVariable($name)
        if ($val) { $overridePaths.Add([pscustomobject]@{ Name = $name; Value = $val }) }
    }
    $uninstallKeys = New-Object 'System.Collections.Generic.List[string]'
    foreach ($root in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
        foreach ($key in (Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $value = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if (-not $value -or -not $value.PSObject.Properties['DisplayName'] -or
                -not $value.PSObject.Properties['Publisher']) { continue }
            if ($value.DisplayName -match '(?i)^Claude( Code| Desktop)?$' -and $value.Publisher -match 'Anthropic') {
                $uninstallKeys.Add($key.Name)
            }
        }
    }
    $protocolKeys = New-Object 'System.Collections.Generic.List[string]'
    foreach ($proto in @('HKCU:\Software\Classes\claude', 'HKLM:\Software\Classes\claude')) {
        if ((Get-TargetPresenceState $proto).State -eq 'Present') { $protocolKeys.Add($proto) }
    }
    $aclPaths = @(
        (Join-Path $env:USERPROFILE '.claude'),
        (Join-Path $env:USERPROFILE '.local\share\claude'),
        (Join-Path $env:USERPROFILE '.cache\claude'),
        (Join-Path $env:APPDATA 'Claude'),
        (Join-Path $env:LOCALAPPDATA 'Claude'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Claude_pzs8sxrjxfjjc')
    )
    $aclDiagnostics = @($aclPaths | ForEach-Object { Get-PathAclDiagnostics -Path $_ })

    $nativePath = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    $nativeInfo = $null
    if ((Get-TargetPresenceState $nativePath).State -eq 'Present') {
        $native = Get-Item -LiteralPath $nativePath -ErrorAction SilentlyContinue
        if ($native) {
            $sig = Get-AuthenticodeSignature -LiteralPath $native.FullName
            $nativeInfo = [pscustomobject]@{
                Path = $native.FullName
                Version = $native.VersionInfo.FileVersion
                SignatureStatus = [string]$sig.Status
                Company = $native.VersionInfo.CompanyName
            }
        }
    }

    return [pscustomobject]@{
        NativeClaudeCode = $nativeInfo
        NpmClaudePackages = @(Get-NpmClaudePackageInstallations)
        VsCode = (Get-VsCodeClaudeDiscovery)
        AppDataClassification = @(Get-AppDataClassification)
        Shortcuts = @(Get-ClaudeShortcutResiduals)
        PathEntries = $pathEntries.ToArray()
        EnvironmentVariableNames = $envVarNames.ToArray()
        PathOverrides = $overridePaths.ToArray()
        UninstallKeys = $uninstallKeys.ToArray()
        ProtocolKeys = $protocolKeys.ToArray()
        AclDiagnostics = $aclDiagnostics
        ResidualAccountIds = @(Get-ClaudeResidualAccountMetadata)
    }
}

function Invoke-ClaudeAppxUninstall {
    param([Parameter(Mandatory = $true)][string]$PackageFullName)
    if ($PackageFullName -notmatch '^Claude_[^\\/\s]+__pzs8sxrjxfjjc$') {
        throw "Unexpected MSIX package name: $PackageFullName"
    }
    Remove-AppxPackage -Package $PackageFullName -ErrorAction Stop -Confirm:$false
}

function Get-NpmCommand {
    Get-Command npm.cmd -ErrorAction Stop
}

function Get-VsCodeCliCommand {
    Get-Command code.cmd, code.exe, code -ErrorAction Stop | Select-Object -First 1
}

function Invoke-NpmClaudeUninstall {
    param(
        [Parameter(Mandatory = $true)][string]$PackageName,
        [Parameter(Mandatory = $true)][string]$PrefixPath
    )
    if ($PackageName -ne '@anthropic-ai/claude-code') {
        throw "Refusing to uninstall unapproved npm package: $PackageName"
    }
    $npmCmd = Get-NpmCommand
    $normalPrefix = Get-NormalPath $PrefixPath
    Assert-NoLinkAncestors $normalPrefix
    $output = & $npmCmd.Source uninstall -g '@anthropic-ai/claude-code' --prefix $normalPrefix 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("npm uninstall failed (exit=$LASTEXITCODE): " + ($output | Out-String).Trim())
    }
}

function Invoke-VsCodeExtensionUninstall {
    param([Parameter(Mandatory = $true)][string]$ExtensionId)
    if ($ExtensionId -ne 'anthropic.claude-code') {
        throw "Refusing to uninstall unapproved VS Code extension: $ExtensionId"
    }
    $codeCmd = Get-VsCodeCliCommand
    $output = & $codeCmd.Source --uninstall-extension 'anthropic.claude-code' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("VS Code extension uninstall failed (exit=$LASTEXITCODE): " + ($output | Out-String).Trim())
    }
}

function Test-RemovableRoot {
    param([string]$Path)
    try {
        Assert-AuthorizedPath -Path $Path -AllowedRoots @($Path) | Out-Null
        Assert-TreeWithoutLinks -Path $Path
        return $true
    } catch { return $false }
}

function Assert-NoOverlappingTargets {
    param([object[]]$Records)
    $paths = @($Records | Where-Object { $_.Kind -eq 'Filesystem' } | ForEach-Object { Get-NormalPath $_.Path })
    for ($i = 0; $i -lt $paths.Count; $i++) {
        for ($j = $i + 1; $j -lt $paths.Count; $j++) {
            if ((Test-PathWithin $paths[$i] $paths[$j]) -or (Test-PathWithin $paths[$j] $paths[$i])) {
                throw "Overlapping deletion targets: $($paths[$i]) and $($paths[$j])"
            }
        }
    }
}

function Get-CurrentCandidates {
    $homePath = $env:USERPROFILE
    $roaming = $env:APPDATA
    $local = $env:LOCALAPPDATA
    $cli = Join-Path $homePath '.claude'
    $items = New-Object 'System.Collections.Generic.List[object]'
    $account = @(
        @('cli-credentials', (Join-Path $cli '.credentials.json'), 'Authentication'),
        @('cli-auth-cache', (Join-Path $cli 'mcp-needs-auth-cache.json'), 'Authentication cache'),
        @('cli-global', (Join-Path $homePath '.claude.json'), 'Claude Code account metadata'),
        @('cli-cache', (Join-Path $cli 'cache'), 'Cache'),
        @('cli-stats', (Join-Path $cli 'stats-cache.json'), 'Cache'),
        @('cli-session-env', (Join-Path $cli 'session-env'), 'Session cache'),
        @('cli-telemetry', (Join-Path $cli 'telemetry'), 'Diagnostics'),
        @('native-staging', (Join-Path $homePath '.cache\claude\staging'), 'Installer cache'),
        @('desktop-buddy-tokens', (Join-Path $roaming 'Claude\buddy-tokens.json'), 'Authentication'),
        @('desktop-cookies', (Join-Path $roaming 'Claude\Cookies'), 'Authentication'),
        @('desktop-network', (Join-Path $roaming 'Claude\Network'), 'Authentication & session'),
        @('desktop-preferences', (Join-Path $roaming 'Claude\Preferences'), 'Account & device metadata'),
        @('desktop-local-storage', (Join-Path $roaming 'Claude\Local Storage'), 'Session & account storage'),
        @('desktop-indexeddb', (Join-Path $roaming 'Claude\IndexedDB'), 'Session & account storage'),
        @('desktop-session-storage', (Join-Path $roaming 'Claude\Session Storage'), 'Session & account storage'),
        @('desktop-dips', (Join-Path $roaming 'Claude\DIPS'), 'Session & tracking state'),
        @('desktop-trust-tokens', (Join-Path $roaming 'Claude\Trust Tokens'), 'Authentication cache'),
        @('desktop-transport-security', (Join-Path $roaming 'Claude\TransportSecurity'), 'Network state'),
        @('desktop-cache', (Join-Path $roaming 'Claude\Cache'), 'Cache'),
        @('desktop-code-cache', (Join-Path $roaming 'Claude\Code Cache'), 'Cache'),
        @('desktop-gpu-cache', (Join-Path $roaming 'Claude\GPUCache'), 'Cache'),
        @('desktop-dawn-graphite', (Join-Path $roaming 'Claude\DawnGraphiteCache'), 'Cache'),
        @('desktop-dawn-webgpu', (Join-Path $roaming 'Claude\DawnWebGPUCache'), 'Cache'),
        @('desktop-logs', (Join-Path $roaming 'Claude\logs'), 'Diagnostics'),
        @('local-cache', (Join-Path $local 'Claude\Cache'), 'Cache'),
        @('local-logs', (Join-Path $local 'Claude\logs'), 'Diagnostics')
    )
    foreach ($row in $account) {
        $warning = if ($row[0] -eq 'cli-global') { 'Removes .claude.json account UUID and auth metadata; custom .claude/skills and .claude/commands are preserved.' } else { '' }
        $items.Add((Get-Candidate -Id $row[0] -Path $row[1] -Category $row[2] -Policy 'AccountData' -Decision 'Ready' -Warning $warning))
    }
    $full = @(
        @('cli-home', $cli, 'Claude Code user data'),
        @('cli-exe', (Join-Path $homePath '.local\bin\claude.exe'), 'Claude Code installation'),
        @('cli-versions', (Join-Path $homePath '.local\share\claude'), 'Claude Code installation'),
        @('cli-installer-cache', (Join-Path $homePath '.cache\claude'), 'Claude Code cache'),
        @('desktop-roaming', (Join-Path $roaming 'Claude'), 'Claude Desktop user data'),
        @('desktop-local', (Join-Path $local 'Claude'), 'Claude Desktop user data'),
        @('desktop-old-local', (Join-Path $local 'Claude-3p'), 'Possible old Desktop data'),
        @('desktop-old-roaming', (Join-Path $roaming 'Claude-3p'), 'Possible old Desktop data')
    )
    foreach ($row in $full) {
        $decision = 'Ready'
        $warning = ''
        if ($row[0] -eq 'cli-home') { $warning = 'Removes skills, plugins, MCP settings, history, sessions, and other user-created data.' }
        if ($row[0] -eq 'desktop-roaming') {
            $warning = 'Removes Desktop sessions, local files, extensions, Cowork data, and any user backup inside this directory.'
            $reaState = Get-TargetPresenceState (Join-Path $roaming 'Claude\claude_desktop_config.json.rea.backup')
            if ($reaState.State -ne 'Absent') {
                $decision = 'ReviewOnly'
                if ($reaState.State -eq 'Unknown') { $warning = "$warning Backup probe error: $($reaState.Error)" }
            }
        }
        if ($row[0] -match '^desktop-old') { $decision = 'ReviewOnly'; $warning = 'Old path attribution requires separate confirmation.' }
        $items.Add((Get-Candidate -Id $row[0] -Path $row[1] -Category $row[2] -Policy 'FullRemoval' -Warning $warning -Decision $decision))
    }
    $cliReady = Test-RemovableRoot $cli
    $nativeCacheRoot = Join-Path $homePath '.cache\claude'
    $nativeCacheReady = Test-RemovableRoot $nativeCacheRoot
    $desktopRoamingRoot = Join-Path $roaming 'Claude'
    $reaRootState = Get-TargetPresenceState (Join-Path $desktopRoamingRoot 'claude_desktop_config.json.rea.backup')
    $desktopRoamingReady = ($reaRootState.State -eq 'Absent') -and
        (Test-RemovableRoot $desktopRoamingRoot)
    $desktopLocalReady = Test-RemovableRoot (Join-Path $local 'Claude')
    foreach ($row in $account) {
        $covered = switch -Regex ($row[0]) {
            '^cli-global$' { $false; break }
            '^cli-' { $cliReady; break }
            '^native-' { $nativeCacheReady; break }
            '^desktop-' { $desktopRoamingReady; break }
            '^local-' { $desktopLocalReady; break }
            default { $false }
        }
        if ($covered) { continue }
        $warning = if ($row[0] -eq 'cli-global') { 'Removes .claude.json account metadata and MCP state.' } else { 'Fallback because the parent directory is blocked or under review.' }
        $items.Add((Get-Candidate -Id ('full-' + $row[0]) -Path $row[1] -Category $row[2] -Policy 'FullRemoval' -Decision 'Ready' -Warning $warning))
    }
    $vsDiscovery = Get-VsCodeClaudeDiscovery
    if ($vsDiscovery.ExtensionsRootState -eq 'Present') {
        $hasCodeCli = [bool]$vsDiscovery.CodeCliPath
        if ($hasCodeCli -and $vsDiscovery.ExtensionDirs.Count -gt 0) {
            $items.Add((Get-Candidate -Id 'vscode-cli-anthropic.claude-code' -Path 'anthropic.claude-code' -Category 'VS Code extension (CLI)' -Policy 'FullRemoval' -Kind 'VsCodeExtension' -Identity $vsDiscovery.ExtensionsRoot -Warning 'Uses VS Code CLI (code --uninstall-extension anthropic.claude-code) so extensions.json/.obsolete stay consistent; VS Code should be closed.'))
        }
        foreach ($ext in $vsDiscovery.ExtensionDirs) {
            $extDecision = if ($hasCodeCli) { 'ReviewOnly' } else { 'Ready' }
            $extWarning = if ($hasCodeCli) { 'Managed by VsCodeExtension CLI removal; review only if directory remains after code --uninstall-extension.' } else { 'VS Code should be closed before removal.' }
            $items.Add((Get-Candidate -Id ('vscode-' + $ext.Name) -Path $ext.FullName -Category 'VS Code extension' -Policy 'FullRemoval' -Decision $extDecision -Warning $extWarning))
        }
    } elseif ($vsDiscovery.ExtensionsRootState -eq 'Unknown') {
        $items.Add((Get-Candidate -Id 'vscode-extensions-probe-blocked' -Path $vsDiscovery.ExtensionsRoot -Category 'VS Code extension' -Policy 'FullRemoval' -Decision 'Blocked' -Warning ("Cannot probe VS Code extensions directory: $($vsDiscovery.ExtensionsRootError)")))
    }
    foreach ($npmPkg in (Get-NpmClaudePackageInstallations)) {
        $npmDec = if ($npmPkg.SafeToUninstall) { 'Ready' } else { 'Blocked' }
        $npmWarn = if ($npmPkg.SafeToUninstall) { 'Removes global @anthropic-ai/claude-code via npm uninstall without touching Node.js, npm, or unrelated packages.' } else { $npmPkg.BlockReason }
        $items.Add((Get-Candidate -Id ('npm-claude-code-' + ([Math]::Abs($npmPkg.PrefixPath.GetHashCode()))) -Path $npmPkg.PackagePath -Category 'npm Claude Code package' -Policy 'FullRemoval' -Kind 'NpmPackage' -Decision $npmDec -Identity $npmPkg.PrefixPath -Warning $npmWarn))
    }
    try {
        $pkg = Get-ClaudeAppxPackage | Where-Object {
            $_.PackageFamilyName -eq 'Claude_pzs8sxrjxfjjc' -and $_.Publisher -match 'Anthropic'
        }
        foreach ($p in $pkg) {
            $items.Add((Get-Candidate -Id ('appx-' + $p.PackageFullName) -Path $p.PackageFullName -Category 'Claude Desktop MSIX' -Policy 'FullRemoval' -Kind 'AppxPackage' -Warning 'Windows package removal may remove package-managed data and its service.'))
            $packageData = Join-Path $local ('Packages\' + $p.PackageFamilyName)
            $pkgDataState = Get-TargetPresenceState $packageData
            if ($pkgDataState.State -ne 'Absent') {
                $items.Add((Get-Candidate -Id 'desktop-msix-data' -Path $packageData -Category 'OS-managed MSIX data' -Policy 'FullRemoval' -Decision 'ReviewOnly' -Warning 'Contains junctions; never direct-delete. Package removal may affect this data.'))
            }
        }
    } catch {
        $items.Add((Get-Candidate -Id 'appx-claude-query-blocked' -Path 'Claude_pzs8sxrjxfjjc' -Category 'Claude Desktop MSIX' -Policy 'FullRemoval' -Kind 'AppxPackage' -Decision 'Blocked' -Warning ('Unable to query MSIX package state: ' + $_.Exception.Message)))
    }
    if ($vsDiscovery.ObsoleteState -eq 'Present' -and $vsDiscovery.ObsoleteReferencesClaude) {
        $items.Add((Get-Candidate -Id 'vscode-shared-obsolete' -Path $vsDiscovery.ObsoletePath -Category 'Shared VS Code registration file' -Policy 'FullRemoval' -Decision 'ReviewOnly' -Warning 'Shared file; do not delete as a whole.'))
    } elseif ($vsDiscovery.ObsoleteState -eq 'Unknown') {
        $items.Add((Get-Candidate -Id 'vscode-shared-obsolete' -Path $vsDiscovery.ObsoletePath -Category 'Shared VS Code registration file' -Policy 'FullRemoval' -Decision 'Blocked' -Warning ("Cannot probe VS Code .obsolete file: $($vsDiscovery.ObsoleteError)")))
    }
    $pivotRoot = Join-Path $local 'Packages'
    foreach ($pivot in (Get-ChildItem -LiteralPath $pivotRoot -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^0_https___pivot\.claude\.ai' })) {
        $items.Add((Get-Candidate -Id ('suspected-' + $pivot.Name) -Path $pivot.FullName -Category 'Suspected Claude-related package data' -Policy 'FullRemoval' -Decision 'ReviewOnly' -Warning 'Name alone does not establish ownership.'))
    }
    foreach ($browser in @('Google\Chrome', 'Microsoft\Edge')) {
        $key = 'HKCU:\Software\' + $browser + '\NativeMessagingHosts\com.anthropic.claude_browser_extension'
        $regState = Get-TargetPresenceState $key
        if ($regState.State -eq 'Present') {
            $decision = 'ReviewOnly'
            $regWarning = 'Does not modify browser profiles or site data.'
            try {
                $regItem = Get-Item -LiteralPath $key -ErrorAction Stop
                $destination = [string]$regItem.GetValue('')
                $decision = if ($destination -match '(?i)Claude|Anthropic') { 'Ready' } else { 'ReviewOnly' }
            } catch {
                $decision = 'Blocked'
                $regWarning = 'Cannot read registry key: ' + $_.Exception.Message
            }
            $items.Add((Get-Candidate -Id ('native-host-' + ($browser -replace '[\\ ]', '-')) -Path $key -Category 'Browser native host registration' -Policy 'FullRemoval' -Kind 'RegistryKey' -Decision $decision -Warning $regWarning))
        } elseif ($regState.State -eq 'Unknown') {
            $items.Add((Get-Candidate -Id ('native-host-' + ($browser -replace '[\\ ]', '-')) -Path $key -Category 'Browser native host registration' -Policy 'FullRemoval' -Kind 'RegistryKey' -Decision 'Blocked' -Warning ('Cannot probe registry key: ' + $regState.Error)))
        }
    }
    return $items.ToArray()
}

function Get-ArtifactRecord {
    param([object]$Candidate)
    $status = $Candidate.Decision
    $bytes = $null
    $entries = $null
    $reason = ''
    $lastWriteUtcTicks = $null
    $maxLastWriteUtcTicks = $null
    $volumeSerial = $null
    $fileIndex = $null
    $identity = $null

    if ($Candidate.Kind -eq 'Filesystem') {
        try {
            $normal = Get-NormalPath $Candidate.Path
            [uint32]$attrs = 0
            $exists = [ClaudeCleanup.NativeFs]::TryGetAttributes($normal, [ref]$attrs)
        } catch {
            $status = 'Blocked'
            $reason = 'Cannot inspect target: ' + $_.Exception.Message
            $exists = $true
        }
        if ($status -eq 'Blocked') {
            return [pscustomobject]@{
                Id = $Candidate.Id; Path = $Candidate.Path; Category = $Candidate.Category
                Policy = $Candidate.Policy; Kind = $Candidate.Kind; Decision = $status
                SizeBytes = $null; Entries = $null; LastWriteUtcTicks = $null
                MaxLastWriteUtcTicks = $null; VolumeSerialNumber = $null; FileIndex = $null
                Identity = $null; Reason = $reason; Warning = $Candidate.Warning
                Ownership = 'Unverified'
            }
        }
        if (-not $exists) { return $null }
        $safe = Test-SafeTarget -Path $Candidate.Path -AllowedRoots @($Candidate.Path)
        if (-not $safe.Allowed) { $status = 'Blocked'; $reason = $safe.Reason }
        if ($status -ne 'Blocked') {
            try {
                $snap = Get-SafeTreeSnapshot -Path $Candidate.Path
                $bytes = $snap.Bytes
                $entries = $snap.Entries
                $lastWriteUtcTicks = $snap.LastWriteUtcTicks
                $maxLastWriteUtcTicks = $snap.MaxLastWriteUtcTicks
                $volumeSerial = [uint32]$snap.VolumeSerialNumber
                $fileIndex = [string]$snap.FileIndex
            } catch {
                $status = 'Blocked'
                $reason = $_.Exception.Message
            }
        }
    } elseif ($Candidate.Kind -eq 'RegistryKey') {
        try {
            $regItem = Get-Item -LiteralPath $Candidate.Path -ErrorAction Stop
            $identity = [string]$regItem.GetValue('')
        } catch {
            $status = 'Blocked'
            $reason = 'Cannot inspect registry key: ' + $_.Exception.Message
        }
    } elseif ($Candidate.Kind -eq 'NpmPackage') {
        $identity = $Candidate.Identity
        if ($Candidate.Decision -eq 'Blocked') { $reason = $Candidate.Warning }
    } elseif ($Candidate.Kind -eq 'VsCodeExtension') {
        $identity = $Candidate.Identity
        if ($Candidate.Decision -eq 'Blocked') { $reason = $Candidate.Warning }
    } elseif ($Candidate.Kind -eq 'AppxPackage' -and $Candidate.Decision -eq 'Blocked') {
        $reason = $Candidate.Warning
    }

    return [pscustomobject]@{
        Id = $Candidate.Id; Path = $Candidate.Path; Category = $Candidate.Category
        Policy = $Candidate.Policy; Kind = $Candidate.Kind; Decision = $status
        SizeBytes = $bytes; Entries = $entries; LastWriteUtcTicks = $lastWriteUtcTicks
        MaxLastWriteUtcTicks = $maxLastWriteUtcTicks; VolumeSerialNumber = $volumeSerial; FileIndex = $fileIndex
        Identity = $identity; Reason = $reason; Warning = $Candidate.Warning
        Ownership = if ($Candidate.Decision -eq 'ReviewOnly' -or $status -eq 'Blocked') { 'Suspected / mixed' } else { 'Confirmed Claude path or registration' }
    }
}

function Get-Inventory {
    $records = New-Object 'System.Collections.Generic.List[object]'
    foreach ($candidate in (Get-CurrentCandidates)) {
        $record = Get-ArtifactRecord $candidate
        if ($record) { $records.Add($record) }
    }
    return $records.ToArray()
}

function Get-ClaudeParentProcessId {
    param([int]$TargetPid)
    if ($TargetPid -le 0) { return 0 }
    try {
        $procCim = Get-CimInstance -ClassName Win32_Process -Filter ("ProcessId = $TargetPid") -ErrorAction Stop
        if ($null -ne $procCim -and $null -ne $procCim.ParentProcessId) {
            return [int]$procCim.ParentProcessId
        }
    } catch {}
    return 0
}

function Get-ClaudeProcess {
    param(
        [AllowNull()][object[]]$ProcessesOverride = $null,
        [int]$SelfPid = $PID,
        [int]$ParentPidOverride = -1,
        [int]$GrandParentPidOverride = -1
    )

    $excludedPids = New-Object 'System.Collections.Generic.HashSet[int]'
    if ($SelfPid -gt 0) { [void]$excludedPids.Add($SelfPid) }
    $parentPid = if ($ParentPidOverride -ge 0) { $ParentPidOverride } else { Get-ClaudeParentProcessId -TargetPid $SelfPid }
    if ($parentPid -gt 0) {
        [void]$excludedPids.Add($parentPid)
        $grandParentPid = if ($GrandParentPidOverride -ge 0) { $GrandParentPidOverride } else { Get-ClaudeParentProcessId -TargetPid $parentPid }
        if ($grandParentPid -gt 0) { [void]$excludedPids.Add($grandParentPid) }
    }

    $rawList = if ($null -ne $ProcessesOverride) {
        @($ProcessesOverride)
    } else {
        @(Get-Process -ErrorAction SilentlyContinue)
    }

    $projRootNorm = ''
    if (-not [string]::IsNullOrWhiteSpace($script:ProjectRoot)) {
        try { $projRootNorm = [IO.Path]::GetFullPath($script:ProjectRoot).TrimEnd('\', '/') + '\' } catch {}
    }

    $cimNativeHostsByPid = @{}
    if ($null -eq $ProcessesOverride) {
        try {
            foreach ($cimRow in @(Get-CimInstance -ClassName Win32_Process -Filter "Name = 'chrome-native-host.exe'" -ErrorAction Stop)) {
                if ($null -ne $cimRow -and $null -ne $cimRow.ProcessId) {
                    $cimNativeHostsByPid[[int]$cimRow.ProcessId] = $cimRow
                }
            }
        } catch {}
    }

    $matched = New-Object 'System.Collections.Generic.List[object]'
    foreach ($p in $rawList) {
        if ($null -eq $p) { continue }
        $procId = 0
        if ($p.PSObject.Properties['Id'] -and $null -ne $p.Id) { $procId = [int]$p.Id }
        if ($procId -gt 0 -and $excludedPids.Contains($procId)) { continue }

        $procName = if ($p.PSObject.Properties['ProcessName'] -and $null -ne $p.ProcessName) { [string]$p.ProcessName } else { '' }
        if ([string]::IsNullOrWhiteSpace($procName)) { continue }

        # Strictly exclude self/cleaner executables even if their names contain "claude"
        if ($procName -match '(?i)^(?:claude-residual-id-cleaner(?:-setup)?|claudecleanup(?:launcher|gui)?|claude-cleanup)(?:\.exe)?$' -or
            $procName -match '(?i)residual-id-cleaner|claudecleanup') {
            continue
        }

        $isDirectClaude = ($procName -match '^(?i:claude|claude desktop|claude-desktop|claude-code|claude-helper|claude-sandbox|anthropic-claude)$')
        $isNativeHost = ($procName -match '^(?i:chrome-native-host)(?:\.exe)?$')
        if (-not $isDirectClaude -and -not $isNativeHost) {
            continue
        }

        $procPath = ''
        try {
            if ($p.PSObject.Properties['Path'] -and $null -ne $p.Path) {
                $procPath = [string]$p.Path
            } elseif ($p.PSObject.Properties['ExecutablePath'] -and $null -ne $p.ExecutablePath) {
                $procPath = [string]$p.ExecutablePath
            }
        } catch {
            $procPath = ''
        }

        $procCmd = ''
        try {
            if ($p.PSObject.Properties['CommandLine'] -and $null -ne $p.CommandLine) {
                $procCmd = [string]$p.CommandLine
            }
        } catch {
            $procCmd = ''
        }

        if ($isNativeHost) {
            if ($null -eq $ProcessesOverride -and $procId -gt 0 -and ([string]::IsNullOrWhiteSpace($procPath) -or [string]::IsNullOrWhiteSpace($procCmd))) {
                $cimProc = $null
                if ($cimNativeHostsByPid.ContainsKey($procId)) {
                    $cimProc = $cimNativeHostsByPid[$procId]
                } else {
                    try { $cimProc = Get-CimInstance -ClassName Win32_Process -Filter ("ProcessId = $procId") -ErrorAction Stop } catch {}
                }
                if ($null -ne $cimProc) {
                    if ([string]::IsNullOrWhiteSpace($procPath) -and $null -ne $cimProc.ExecutablePath) {
                        $procPath = [string]$cimProc.ExecutablePath
                    }
                    if ([string]::IsNullOrWhiteSpace($procCmd) -and $null -ne $cimProc.CommandLine) {
                        $procCmd = [string]$cimProc.CommandLine
                    }
                }
            }
            $matchesClaudeHost = ($procPath -match '(?i)(?:\\AnthropicClaude\\|\\Anthropic[^\\]*\\|\\Claude\\|\\WindowsApps\\Claude_|[\\/]Claude[\\/])') -or
                ($procCmd -match '(?i)(?:com\.anthropic\.claude_browser_extension|com\.anthropic\.claude|AnthropicClaude|Anthropic[^\\/]*[\\/]Claude|WindowsApps[\\/]Claude_|[\\/]Claude[\\/])')
            if (-not $matchesClaudeHost) {
                continue
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($procPath)) {
            $leaf = ''
            try { $leaf = [IO.Path]::GetFileName($procPath) } catch {}
            if ($leaf -match '(?i)^(?:claude-residual-id-cleaner(?:-setup)?|claudecleanup(?:launcher|gui)?)(?:\.exe)?$') {
                continue
            }
            if (-not [string]::IsNullOrEmpty($projRootNorm)) {
                try {
                    $fullProcPath = [IO.Path]::GetFullPath($procPath)
                    if ($fullProcPath.StartsWith($projRootNorm, [StringComparison]::OrdinalIgnoreCase)) {
                        continue
                    }
                } catch {}
            }
        }

        $matched.Add([pscustomobject]@{
            Id          = $procId
            ProcessName = $procName
            Path        = $procPath
        })
    }
    return @($matched.ToArray())
}

function Get-EnvironmentReport {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('Windows user: ' + [Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $lines.Add('PowerShell: ' + $PSVersionTable.PSVersion.ToString())
    $resolved = Get-Command claude -All -ErrorAction SilentlyContinue
    foreach ($command in $resolved) { $lines.Add('Claude command: ' + $command.Source) }
    $nativePath = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if ((Get-TargetPresenceState $nativePath).State -eq 'Present') {
        $native = Get-Item -LiteralPath $nativePath -ErrorAction SilentlyContinue
        if ($native) {
            $signature = Get-AuthenticodeSignature -LiteralPath $native.FullName
            $lines.Add(('Native executable: {0}; version={1}; signature={2}; company={3}' -f
                $native.FullName, $native.VersionInfo.FileVersion, $signature.Status, $native.VersionInfo.CompanyName))
        }
    }
    $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if ($npm) {
        $lines.Add('npm command: ' + $npm.Source)
        $npmPrefix = [Environment]::GetEnvironmentVariable('NPM_CONFIG_PREFIX')
        if ($npmPrefix) { $lines.Add('npm prefix override (not independently validated): ' + $npmPrefix) }
        else { $lines.Add('npm global prefix: unverified; known default package locations checked without invoking npm') }
        $npmRoots = @((Join-Path $env:APPDATA 'npm\node_modules\@anthropic-ai\claude-code'),
            (Join-Path $env:ProgramFiles 'nodejs\node_modules\@anthropic-ai\claude-code'))
        foreach ($npmRoot in $npmRoots) {
            if ((Get-TargetPresenceState $npmRoot).State -eq 'Present') { $lines.Add('npm Claude package candidate: ' + $npmRoot) }
        }
    }
    foreach ($scope in @('User', 'Machine')) {
        $pathValue = [Environment]::GetEnvironmentVariable('PATH', $scope)
        foreach ($entry in @($pathValue -split ';')) {
            if ($entry -match '(?i)claude|anthropic|[\\/]\.local[\\/]bin$') { $lines.Add("$scope PATH entry: $entry") }
        }
    }
    $running = @(Get-ClaudeProcess)
    $lines.Add('Claude-named running processes: ' + $running.Count)
    $lines.Add('Node-based Claude processes cannot be attributed without reading command lines; close Claude normally before Apply.')
    foreach ($process in $running) { $lines.Add(('Process: {0} PID={1}' -f $process.ProcessName, $process.Id)) }
    foreach ($scope in @('User', 'Machine')) {
        foreach ($name in [Environment]::GetEnvironmentVariables($scope).Keys) {
            if ($name -match '(?i)claude|anthropic') { $lines.Add("$scope environment variable name: $name") }
        }
    }
    foreach ($name in @('CLAUDE_CONFIG_DIR', 'CLAUDE_USER_DATA_DIR')) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if ($value) { $lines.Add("Custom path override $name`: $value (report only)") }
    }
    $credentialTargets = @(cmdkey.exe /list 2>$null | Where-Object { $_ -match '(?i)^\s*Target:.*(claude|anthropic)' })
    $lines.Add('Credential Manager Claude-named target count: ' + $credentialTargets.Count + ' (values not read)')
    foreach ($name in @('skills', 'plugins', 'projects', 'sessions', 'history.jsonl', 'settings.json',
        'settings.local.json', 'backups', 'daemon', '.credentials.json')) {
        if ((Get-TargetPresenceState (Join-Path $env:USERPROFILE ('.claude\' + $name))).State -eq 'Present') {
            $lines.Add('Claude Code content category present: ' + $name)
        }
    }
    foreach ($name in @('local-agent-mode-sessions', 'claude-code-sessions', 'claude-code-vm',
        'vm_bundles', 'Claude Extensions', 'Local Storage', 'IndexedDB', 'Network', 'logs')) {
        if ((Get-TargetPresenceState (Join-Path $env:APPDATA ('Claude\' + $name))).State -eq 'Present') {
            $lines.Add('Claude Desktop content category present: ' + $name)
        }
    }
    $obsolete = Join-Path $env:USERPROFILE '.vscode\extensions\.obsolete'
    if ((Get-TargetPresenceState $obsolete).State -eq 'Present') {
        $obsoleteText = Get-Content -LiteralPath $obsolete -Raw -ErrorAction SilentlyContinue
        if ($obsoleteText -match '(?i)anthropic\.claude-code') {
            $lines.Add('VS Code shared .obsolete file references Claude extension; report only')
        }
    }
    $uninstallRoots = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach ($root in $uninstallRoots) {
        foreach ($key in (Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
            $value = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if (-not $value -or -not $value.PSObject.Properties['DisplayName'] -or
                -not $value.PSObject.Properties['Publisher']) { continue }
            if ($value.DisplayName -match '(?i)^Claude( Code| Desktop)?$' -and $value.Publisher -match 'Anthropic') {
                $lines.Add('Uninstall registration: ' + $key.Name)
            }
        }
    }
    $lines.Add('Machine-level MSIX provisioning: unverified without an elevated or management-scope query')
    try {
        foreach ($service in (Get-CimInstance Win32_Service -ErrorAction Stop | Where-Object {
            $_.PathName -match 'WindowsApps\\Claude_[^\\]+\\' -or ($_.Name -eq 'CoworkVMService' -and $_.DisplayName -eq 'Claude')
        })) {
            $lines.Add(('Service: {0} ({1})' -f $service.Name, $service.State))
        }
    } catch {
        $lines.Add('Service inspection unavailable: ' + $_.Exception.Message)
    }
    try {
        foreach ($pkg in (Get-ClaudeAppxPackage | Where-Object { $_.Publisher -match 'Anthropic' })) {
            $lines.Add(('MSIX: {0}; family={1}; install={2}' -f $pkg.PackageFullName, $pkg.PackageFamilyName, $pkg.InstallLocation))
            $packageData = Join-Path $env:LOCALAPPDATA ('Packages\' + $pkg.PackageFamilyName)
            if ((Get-TargetPresenceState $packageData).State -eq 'Present') {
                foreach ($child in (Get-ChildItem -LiteralPath $packageData -Force -ErrorAction SilentlyContinue | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 })) {
                    $linkTarget = 'target unavailable in this PowerShell version'
                    if ($child.PSObject.Properties['LinkTarget']) { $linkTarget = [string]$child.LinkTarget }
                    elseif ($child.PSObject.Properties['Target']) { $linkTarget = [string]$child.Target }
                    $lines.Add(('MSIX data junction (never direct-delete): {0} -> {1}' -f $child.FullName, $linkTarget))
                }
            }
        }
    } catch {
        $lines.Add('MSIX package inspection unavailable: ' + $_.Exception.Message)
    }
    $pivot = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^0_https___pivot\.claude\.ai' }
    foreach ($item in $pivot) { $lines.Add('Suspected Claude-related package data; ownership unverified: ' + $item.FullName) }
    try {
        $scheduledTasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue)
        foreach ($task in $scheduledTasks) {
            $claudeAction = @($task.Actions | Where-Object {
                $_.PSObject.Properties['Execute'] -and
                ($_.Execute -match '(?i)(^|[\\/])claude(\.exe)?$' -or $_.Execute -match '(?i)WindowsApps[\\/]Claude_')
            }).Count -gt 0
            if ($task.TaskName -match '(?i)^Claude' -or $claudeAction) {
                $lines.Add('Scheduled task candidate: ' + $task.TaskPath + $task.TaskName)
            }
        }
    } catch {
        $lines.Add('Scheduled task inspection unavailable: ' + $_.Exception.Message)
    }
    $summary = Get-WindowsResidualSummary
    foreach ($npmItem in $summary.NpmClaudePackages) {
        $lines.Add(('npm Claude package candidate: {0}; version={1}; prefix={2}; safe={3}' -f
            $npmItem.PackagePath, $npmItem.Version, $npmItem.PrefixPath, $npmItem.SafeToUninstall))
    }
    foreach ($sc in $summary.Shortcuts) {
        $lines.Add(('Shortcut candidate (report only): {0} -> {1}' -f $sc.ShortcutPath, $sc.TargetPath))
    }
    foreach ($proto in $summary.ProtocolKeys) {
        $lines.Add('Protocol registration candidate (report only): ' + $proto)
    }
    foreach ($acl in $summary.AclDiagnostics) {
        if ($acl.State -eq 'Absent') { continue }
        $lines.Add(('ACL diagnostic (read-only): {0}; status={1}; owner={2}; currentUserOwner={3}' -f
            $acl.Path, $acl.Status, $acl.Owner, $acl.IsCurrentUserOwner))
    }
    $accountIds = @()
    if ($summary.PSObject.Properties['ResidualAccountIds'] -and $null -ne $summary.ResidualAccountIds) {
        $accountIds = @($summary.ResidualAccountIds)
    }
    if ($accountIds.Count -gt 0) {
        foreach ($aid in $accountIds) {
            $lines.Add(('Residual account/device ID (non-secret; {0}): {1}={2} ({3})' -f
                $aid.Source, $aid.Field, $aid.Value, $aid.ConfigPath))
        }
    } else {
        $lines.Add('Residual account/device ID count (non-secret metadata): 0')
    }
    try {
        $wslRaw = (wsl.exe --list --verbose 2>&1 | Out-String)
        $wslExit = $LASTEXITCODE
        $wsl = [regex]::Replace($wslRaw, '\x00', '')
        $lines.Add('WSL distributions (read-only report; never apply):')
        if ($wslExit -ne 0) {
            $lines.Add("  WSL listing returned exit code $wslExit (unavailable or access denied)")
        } else {
            foreach ($line in ($wsl -split "`r?`n")) {
                if (-not $line.Trim()) { continue }
                $lines.Add('  ' + $line.Trim())
                if ($line -match '^\s*\*?\s*([A-Za-z0-9._-]+)\s+(Running|Stopped)\s+\d+' -and
                    $matches[1] -ne 'docker-desktop') {
                    $distro = $matches[1]
                    if ($matches[2] -eq 'Stopped') { $lines.Add("  $distro`: paths not inspected because distribution is stopped"); continue }
                    $linuxCommand = 'for p in "$HOME/.claude" "$HOME/.claude.json" "$HOME/.local/bin/claude"; do if [ -e "$p" ] || [ -L "$p" ]; then stat -c "%n|%F|%s" "$p"; fi; done'
                    try {
                        foreach ($result in (& wsl.exe -d $distro --exec /bin/sh -c $linuxCommand 2>$null)) {
                            if ($result) { $lines.Add("  $distro`: $result") }
                        }
                    } catch { $lines.Add("  $distro`: path inspection failed") }
                }
            }
        }
    } catch { $lines.Add('WSL listing unavailable: ' + $_.Exception.Message) }
    return $lines.ToArray()
}

function Write-AuditReportDocument {
    param(
        [string]$AuditPath = $script:AuditPath,
        [string]$Lang = $script:ActiveLanguage,
        [AllowNull()][object]$StructuredReport = $null
    )
    $report = if ($null -ne $StructuredReport) { $StructuredReport } else { Get-StructuredAuditReport }
    $isZh = ($Lang -eq 'zh-CN')
    $title = Get-LocalizedUiText -Key 'AuditTitle' -Lang $Lang
    $tagline = Get-LocalizedUiText -Key 'PositioningTagline' -Lang $Lang
    $safety = Get-LocalizedUiText -Key 'SafetyDisclaimer' -Lang $Lang
    $body = New-Object 'System.Collections.Generic.List[string]'
    $body.Add($title)
    $body.Add('')
    $body.Add('> ' + $tagline)
    $body.Add('> ' + $safety)
    $body.Add('')
    if ($isZh) {
        $body.Add('生成时间 (UTC): ' + $report.GeneratedUtc)
        $body.Add('PowerShell 版本: ' + $report.PowerShellVersion)
        $body.Add('环境变量值策略: 仅列出 Scope 与 Name，绝不读取或保存环境变量秘密值或 Credential Manager 密码。')
        $body.Add('')
        $body.Add('## 环境与残留核查摘要')
    } else {
        $body.Add('Generated (UTC): ' + $report.GeneratedUtc)
        $body.Add('PowerShell Version: ' + $report.PowerShellVersion)
        $body.Add('Secret Handling: Environment variables list Scope and Name only; secret values and Credential Manager secrets are never read or saved.')
        $body.Add('')
        $body.Add('## Environment & Residual Summary')
    }
    foreach ($line in @($report.EnvironmentLines)) {
        $body.Add('- ' + [string]$line)
    }
    $body.Add('')
    $accountIds = @()
    if ($report -and $report.PSObject.Properties['Summary'] -and $null -ne $report.Summary -and $report.Summary.PSObject.Properties['ResidualAccountIds'] -and $null -ne $report.Summary.ResidualAccountIds) {
        $accountIds = @($report.Summary.ResidualAccountIds)
    }
    $idHeading = if ($isZh) { '## 已识别残余账号 / 设备 ID（仅非敏感 UUID 元数据）' } else { '## Detected Residual Account / Device IDs (Non-Secret UUID Metadata Only)' }
    $idNote = if ($isZh) {
        '说明：以下仅提取本地非敏感 `accountUuid`、`organizationUuid`、`userId` 与设备/安装 ID 供与网页控制台核对；严禁读取或导出 OAuth Access/Refresh Token、`sessionKey` 或任何秘密凭据。'
    } else {
        'Note: Extracts only non-secret `accountUuid`, `organizationUuid`, `userId`, and device/installation identifiers for user verification against the Claude web console; OAuth access/refresh tokens, `sessionKey`, and secrets are strictly never read or exported.'
    }
    $idEmpty = if ($isZh) { '- 未在可安全读取的本地配置文件中检测到残余账号/设备 ID。' } else { '- No residual account or device identifiers were found in safe readable local config files.' }
    $idHeader = if ($isZh) { '| 来源 | ID 类型 | 字段名 | 识别值 | 配置文件 |' } else { '| Source | ID Type | Field | Value | Config File |' }
    $body.Add($idHeading)
    $body.Add('')
    $body.Add($idNote)
    $body.Add('')
    if ($accountIds.Count -eq 0) {
        $body.Add($idEmpty)
    } else {
        $body.Add($idHeader)
        $body.Add('| :--- | :--- | :--- | :--- | :--- |')
        foreach ($aid in $accountIds) {
            $body.Add(('| {0} | {1} | `{2}` | `{3}` | `{4}` |' -f
                ([string]$aid.Source).Replace('|', '\|'),
                ([string]$aid.IdType).Replace('|', '\|'),
                ([string]$aid.Field).Replace('|', '\|'),
                ([string]$aid.Value).Replace('|', '\|'),
                ([string]$aid.ConfigPath).Replace('|', '\|')))
        }
    }
    $body.Add('')
    if ($isZh) {
        $body.Add('## 候选清理项列表')
        $body.Add('')
        $body.Add('| 策略 | 类别 | 目标路径或包名 | 类型 | 大小(字节) | 决策 | 说明 |')
        $body.Add('| :--- | :--- | :--- | :--- | ---: | :--- | :--- |')
    } else {
        $body.Add('## Candidate Inventory')
        $body.Add('')
        $body.Add('| Policy | Category | Path or package | Kind | Size (bytes) | Decision | Reason |')
        $body.Add('| :--- | :--- | :--- | :--- | ---: | :--- | :--- |')
    }
    foreach ($item in @($report.Inventory)) {
        $sz = if ($null -eq $item.PSObject.Properties['SizeBytes'] -or $null -eq $item.SizeBytes) { 'unknown' } else { [string]$item.SizeBytes }
        $reasonText = if ($item.PSObject.Properties['Reason']) { ([string]$item.Reason).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ') } else { '' }
        $body.Add(('| {0} | {1} | `{2}` | {3} | {4} | {5} | {6} |' -f $item.Policy, $item.Category, ([string]$item.Path).Replace('|', '\|'), $item.Kind, $sz, $item.Decision, $reasonText))
    }
    $parentDir = Split-Path -Parent $AuditPath
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    [IO.File]::WriteAllLines($AuditPath, [string[]]$body.ToArray(), (New-Object System.Text.UTF8Encoding($false)))
    return (Get-Sha256 -Path $AuditPath)
}

function Write-PlanDocument {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Records,
        [string]$PlanPath = $script:PlanPath,
        [string]$Lang = $script:ActiveLanguage
    )
    $manifest = [pscustomobject]@{
        SchemaVersion = 3
        PlanId = [Guid]::NewGuid().ToString('D')
        GeneratedUtc = [DateTime]::UtcNow.ToString('o')
        UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        UserProfile = $env:USERPROFILE
        Records = @($Records)
    }
    $json = ConvertTo-Json -InputObject $manifest -Depth 12
    $body = @(
        (Get-LocalizedUiText -Key 'PlanTitle' -Lang $Lang),
        '',
        ((Get-LocalizedUiText -Key 'PlanIdPrefix' -Lang $Lang) + $manifest.PlanId),
        ((Get-LocalizedUiText -Key 'PlanGeneratedPrefix' -Lang $Lang) + $manifest.GeneratedUtc),
        ('> ' + (Get-LocalizedUiText -Key 'PositioningTagline' -Lang $Lang)),
        (Get-LocalizedUiText -Key 'PlanRule1' -Lang $Lang),
        (Get-LocalizedUiText -Key 'PlanRule2' -Lang $Lang),
        '',
        (Get-LocalizedUiText -Key 'PlanTableHeader' -Lang $Lang),
        '| --- | --- | --- | --- | ---: | --- | --- |'
    )
    foreach ($record in @($Records)) {
        $sizeText = if ($null -eq $record.SizeBytes) { 'unknown' } else { [string]$record.SizeBytes }
        $note = ($record.Reason + ' ' + $record.Warning).Trim().Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
        $body += ('| {0} | {1} | {2} | `{3}` | {4} | {5} | {6} |' -f $record.Policy, $record.Id,
            $record.Category, $record.Path.Replace('|', '\|'), $sizeText, $record.Decision, $note)
    }
    $body += @('', '<!-- MANIFEST-JSON-BEGIN -->', $json, '<!-- MANIFEST-JSON-END -->', '')
    $parentDir = Split-Path -Parent $PlanPath
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    [IO.File]::WriteAllLines($PlanPath, [string[]]$body, (New-Object System.Text.UTF8Encoding($false)))
    return (Get-Sha256 -Path $PlanPath)
}

function Read-AuthorizedPlanDocument {
    param(
        [Parameter(Mandatory = $true)][string]$PlanPath,
        [AllowNull()][string]$ApprovedHash = $null
    )
    if (-not (Test-Path -LiteralPath $PlanPath)) { throw "Plan file not found: $PlanPath" }
    $bytes = [IO.File]::ReadAllBytes($PlanPath)
    $actualHash = Get-Sha256FromBytes -Bytes $bytes
    if ($null -ne $ApprovedHash -and $ApprovedHash -ne '') {
        if ($ApprovedHash -notmatch '^[A-Fa-f0-9]{64}$') { throw 'An approved SHA-256 manifest hash is required.' }
        if (-not $actualHash.Equals($ApprovedHash, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Manifest hash does not match approval.'
        }
    }
    $content = [Text.Encoding]::UTF8.GetString($bytes)
    $beginCount = ([regex]::Matches($content, '<!-- MANIFEST-JSON-BEGIN -->')).Count
    $endCount = ([regex]::Matches($content, '<!-- MANIFEST-JSON-END -->')).Count
    $matches = [regex]::Matches($content, '(?s)<!-- MANIFEST-JSON-BEGIN -->\s*(.*?)\s*<!-- MANIFEST-JSON-END -->')
    if ($beginCount -ne 1 -or $endCount -ne 1 -or $matches.Count -ne 1) {
        throw 'Manifest JSON block is missing, duplicated, or malformed.'
    }
    $manifest = ConvertFrom-Json -InputObject $matches[0].Groups[1].Value
    if (-not $manifest.PSObject.Properties['SchemaVersion'] -or $manifest.SchemaVersion -ne 3) {
        throw 'Unsupported manifest schema version (SchemaVersion 3 required).'
    }
    if (-not $manifest.PSObject.Properties['PlanId'] -or [string]::IsNullOrWhiteSpace([string]$manifest.PlanId)) {
        throw 'Manifest PlanId is missing.'
    }
    [Guid]::Parse([string]$manifest.PlanId) | Out-Null
    if ($manifest.UserSid -ne [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) {
        throw 'Manifest belongs to another user.'
    }
    if ($manifest.UserProfile -ne $env:USERPROFILE) {
        throw 'Manifest belongs to another profile.'
    }
    $records = if ($null -eq $manifest.Records) { @() } else { @($manifest.Records) }
    $seenKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($rec in $records) {
        if ($rec.Policy -notin @('AccountData', 'FullRemoval')) { throw "Invalid manifest policy: $($rec.Policy)" }
        if ($rec.Kind -notin @('Filesystem', 'AppxPackage', 'RegistryKey', 'NpmPackage', 'VsCodeExtension')) { throw "Invalid manifest kind: $($rec.Kind)" }
        if ($rec.Decision -notin @('Ready', 'ReviewOnly', 'Blocked')) { throw "Invalid manifest decision: $($rec.Decision)" }
        $key = "$($rec.Policy)|$($rec.Id)"
        if (-not $seenKeys.Add($key)) { throw "Duplicate manifest entry: $key" }
    }
    return [pscustomobject]@{
        Manifest = $manifest
        ManifestSha256 = $actualHash
        Records = $records
    }
}

function Read-PlanDocument {
    param([string]$PlanPath = $script:PlanPath)
    return (Read-AuthorizedPlanDocument -PlanPath $PlanPath).Manifest
}

function Get-ExecutionLedgerEntries {
    param([Parameter(Mandatory = $true)][string]$VerificationPath)
    if (-not (Test-Path -LiteralPath $VerificationPath)) { return @() }
    $text = [IO.File]::ReadAllText($VerificationPath, [Text.Encoding]::UTF8)
    $beginCount = ([regex]::Matches($text, '<!-- EXECUTION-LEDGER-BEGIN -->')).Count
    $endCount = ([regex]::Matches($text, '<!-- EXECUTION-LEDGER-END -->')).Count
    if ($beginCount -eq 0 -and $endCount -eq 0) {
        if ($text -match 'EXECUTION-LEDGER' -or $text -match '(?m)^# (?:Execution verification log|执行核验报告与账本)\b') {
            throw 'Execution ledger appears truncated or corrupted.'
        }
        return @()
    }
    $matches = [regex]::Matches($text, '(?s)<!-- EXECUTION-LEDGER-BEGIN -->\s*(.*?)\s*<!-- EXECUTION-LEDGER-END -->')
    if ($beginCount -ne 1 -or $endCount -ne 1 -or $matches.Count -ne 1) {
        throw 'Execution ledger block is duplicated or corrupted.'
    }
    try {
        $parsed = ConvertFrom-Json -InputObject $matches[0].Groups[1].Value -ErrorAction Stop
    } catch {
        throw ('Execution ledger JSON is corrupted: ' + $_.Exception.Message)
    }
    if ($null -eq $parsed) { return @() }
    $entries = @($parsed)
    foreach ($entry in $entries) {
        if (-not $entry.PSObject.Properties['PlanId'] -or
            -not $entry.PSObject.Properties['ManifestSha256'] -or
            -not $entry.PSObject.Properties['Policy'] -or
            -not $entry.PSObject.Properties['Outcome']) {
            throw 'Execution ledger entry is malformed or missing required fields.'
        }
        try { [Guid]::Parse([string]$entry.PlanId) | Out-Null }
        catch { throw 'Execution ledger entry has invalid PlanId.' }
        if ([string]$entry.ManifestSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
            throw 'Execution ledger entry has invalid ManifestSha256.'
        }
        if ($entry.Policy -notin @('AccountData', 'FullRemoval')) {
            throw 'Execution ledger entry has invalid Policy.'
        }
        if ($entry.Outcome -notin @('Started', 'Succeeded', 'PartialFailure', 'Failed')) {
            throw 'Execution ledger entry has invalid Outcome.'
        }
    }
    return $entries
}

function Save-ExecutionLedgerEntry {
    param(
        [Parameter(Mandatory = $true)][string]$VerificationPath,
        [Parameter(Mandatory = $true)][object]$Entry,
        [switch]$UpdateExisting
    )
    $existing = @(Get-ExecutionLedgerEntries -VerificationPath $VerificationPath)
    $list = New-Object 'System.Collections.Generic.List[object]'
    $updated = $false
    foreach ($item in $existing) {
        if ($UpdateExisting -and $item.PlanId -eq $Entry.PlanId -and $item.ManifestSha256 -eq $Entry.ManifestSha256) {
            $list.Add($Entry)
            $updated = $true
        } else {
            $list.Add($item)
        }
    }
    if (-not $updated) { $list.Add($Entry) }

    $baseContent = ''
    if (Test-Path -LiteralPath $VerificationPath) {
        $baseContent = [IO.File]::ReadAllText($VerificationPath, [Text.Encoding]::UTF8)
        $baseContent = [regex]::Replace($baseContent, '(?s)\r?\n?<!-- EXECUTION-LEDGER-BEGIN -->.*?<!-- EXECUTION-LEDGER-END -->\r?\n?', '')
        $baseContent = $baseContent.TrimEnd()
    } else {
        $baseContent = (Get-LocalizedUiText -Key 'VerificationTitle' -Lang $script:ActiveLanguage)
    }

    $ledgerJson = ConvertTo-Json -InputObject @($list.ToArray()) -Depth 12
    if ($list.Count -eq 1 -and -not $ledgerJson.TrimStart().StartsWith('[')) {
        $ledgerJson = "[$ledgerJson]"
    }
    $newContent = $baseContent + "`r`n`r`n<!-- EXECUTION-LEDGER-BEGIN -->`r`n" + $ledgerJson + "`r`n<!-- EXECUTION-LEDGER-END -->`r`n"
    $parentDir = Split-Path -Parent $VerificationPath
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $nonce = [Guid]::NewGuid().ToString('N')
    $tmpPath = "$VerificationPath.tmp.$nonce"
    $bakPath = "$VerificationPath.bak.$nonce"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $bytes = $utf8NoBom.GetBytes($newContent)
    try {
        $fs = [IO.File]::Open($tmpPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $fs.Write($bytes, 0, $bytes.Length)
            $fs.Flush($true)
        } finally {
            $fs.Dispose()
        }
        if (Test-Path -LiteralPath $VerificationPath) {
            [IO.File]::Replace($tmpPath, $VerificationPath, $bakPath, $true)
            if (Test-Path -LiteralPath $bakPath) {
                [IO.File]::Delete($bakPath)
            }
        } else {
            [IO.File]::Move($tmpPath, $VerificationPath)
        }
    } finally {
        if (Test-Path -LiteralPath $tmpPath) {
            try { [IO.File]::Delete($tmpPath) } catch {}
        }
    }
}

function Assert-PlanAuthorizationNotConsumed {
    param(
        [Parameter(Mandatory = $true)][string]$VerificationPath,
        [Parameter(Mandatory = $true)][string]$PlanId,
        [Parameter(Mandatory = $true)][string]$ManifestSha256
    )
    foreach ($entry in (Get-ExecutionLedgerEntries -VerificationPath $VerificationPath)) {
        if ($entry.PlanId -eq $PlanId -or $entry.ManifestSha256.Equals($ManifestSha256, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Manifest authorization has already been consumed (PlanId=$($entry.PlanId), Policy=$($entry.Policy), Outcome=$($entry.Outcome)). Re-run -Plan and obtain fresh approval."
        }
    }
}

function Get-RecordPresenceState {
    param([Parameter(Mandatory = $true)][object]$Record)
    if ($Record.Kind -eq 'Filesystem' -or $Record.Kind -eq 'RegistryKey') {
        return (Get-TargetPresenceState $Record.Path)
    }
    if ($Record.Kind -eq 'NpmPackage') {
        return (Get-TargetPresenceState (Join-Path $Record.Path 'package.json'))
    }
    if ($Record.Kind -eq 'VsCodeExtension') {
        $extRoot = [string]$Record.Identity
        if ([string]::IsNullOrWhiteSpace($extRoot)) {
            return [pscustomobject]@{ State = 'Unknown'; Error = 'Missing VS Code extensions root identity.' }
        }
        $rootState = Get-TargetPresenceState $extRoot
        if ($rootState.State -ne 'Present') { return $rootState }
        try {
            $found = $false
            foreach ($dir in (Get-ChildItem -LiteralPath $extRoot -Directory -Force -ErrorAction Stop | Where-Object { $_.Name -match '^anthropic\.claude-code-[0-9]' })) {
                $metaPath = Join-Path $dir.FullName 'package.json'
                if ((Get-TargetPresenceState $metaPath).State -eq 'Present') {
                    $pkg = Get-Content -LiteralPath $metaPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                    if ($pkg.publisher -eq 'anthropic' -and $pkg.name -eq 'claude-code') { $found = $true; break }
                }
            }
            $st = if ($found) { 'Present' } else { 'Absent' }
            return [pscustomobject]@{ State = $st; Error = '' }
        } catch {
            return [pscustomobject]@{ State = 'Unknown'; Error = $_.Exception.Message }
        }
    }
    if ($Record.Kind -eq 'AppxPackage') {
        try {
            $found = [bool](Get-ClaudeAppxPackage | Where-Object {
                $_.PackageFullName -eq $Record.Path -and $_.PackageFamilyName -eq 'Claude_pzs8sxrjxfjjc' -and $_.Publisher -match 'Anthropic'
            })
            $st = if ($found) { 'Present' } else { 'Absent' }
            return [pscustomobject]@{ State = $st; Error = '' }
        } catch {
            return [pscustomobject]@{ State = 'Unknown'; Error = $_.Exception.Message }
        }
    }
    return [pscustomobject]@{ State = 'Unknown'; Error = "Unsupported record kind: $($Record.Kind)" }
}

function Invoke-RegistryLeafKeyDeletion {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ExpectedDefaultValue
    )
    if ($Path -notmatch '^HKCU:\\Software\\(Google\\Chrome|Microsoft\\Edge)\\NativeMessagingHosts\\com\.anthropic\.claude_browser_extension$') {
        throw "Registry key is outside allowlist: $Path"
    }
    $subKey = $Path.Substring(6)
    [ClaudeCleanup.NativeFs]::DeleteHkcuLeafKeySafely($subKey, $ExpectedDefaultValue)
}

function Assert-CurrentRecord {
    param([object]$Record, [object[]]$Candidates)
    $matching = @($Candidates | Where-Object { $_.Id -eq $Record.Id -and $_.Policy -eq $Record.Policy })
    if ($matching.Count -ne 1 -or $matching[0].Path -ne $Record.Path -or $matching[0].Kind -ne $Record.Kind) {
        throw "Manifest entry is not a current exact candidate: $($Record.Id)"
    }
    if ($matching[0].Decision -ne 'Ready' -or $Record.Decision -ne 'Ready') {
        throw "Entry is not approved for automatic application: $($Record.Id)"
    }
    if ($Record.Kind -eq 'Filesystem') {
        $full = Assert-AuthorizedPath -Path $Record.Path -AllowedRoots @($matching[0].Path)
        $expectedFull = Get-NormalPath $matching[0].Path
        if (-not $full.Equals($expectedFull, [StringComparison]::OrdinalIgnoreCase)) { throw "Path changed: $($Record.Id)" }
        $fsPres = Get-TargetPresenceState $full
        if ($fsPres.State -eq 'Unknown') { throw "Cannot inspect target state (Unknown): $($Record.Id) ($($fsPres.Error))" }
        if ($fsPres.State -eq 'Absent') { throw "Target disappeared after planning: $($Record.Id)" }
        $snap = Get-SafeTreeSnapshot -Path $full
        if ($null -eq $Record.SizeBytes -or $null -eq $Record.Entries -or
            $null -eq $Record.LastWriteUtcTicks -or $null -eq $Record.MaxLastWriteUtcTicks -or
            $null -eq $Record.VolumeSerialNumber -or $null -eq $Record.FileIndex -or
            [long]$Record.SizeBytes -ne $snap.Bytes -or
            [int]$Record.Entries -ne $snap.Entries -or
            [long]$Record.LastWriteUtcTicks -ne $snap.LastWriteUtcTicks -or
            [long]$Record.MaxLastWriteUtcTicks -ne $snap.MaxLastWriteUtcTicks -or
            [uint32]$Record.VolumeSerialNumber -ne $snap.VolumeSerialNumber -or
            [string]$Record.FileIndex -ne [string]$snap.FileIndex) {
            throw "Target identity or metadata changed after planning: $($Record.Id)"
        }
    } elseif ($Record.Kind -eq 'AppxPackage') {
        $present = Get-ClaudeAppxPackage | Where-Object {
            $_.PackageFullName -eq $Record.Path -and $_.PackageFamilyName -eq 'Claude_pzs8sxrjxfjjc' -and $_.Publisher -match 'Anthropic'
        }
        if (-not $present) { throw "Package registration changed: $($Record.Id)" }
    } elseif ($Record.Kind -eq 'RegistryKey') {
        if ($Record.Path -notmatch '^HKCU:\\Software\\(Google\\Chrome|Microsoft\\Edge)\\NativeMessagingHosts\\com\.anthropic\.claude_browser_extension$') {
            throw 'Registry key is outside allowlist.'
        }
        $regPres = Get-TargetPresenceState $Record.Path
        if ($regPres.State -eq 'Unknown') { throw "Cannot inspect registry key state (Unknown): $($Record.Id) ($($regPres.Error))" }
        if ($regPres.State -eq 'Absent') { throw "Registry key disappeared after planning: $($Record.Id)" }
        $regItem = Get-Item -LiteralPath $Record.Path -ErrorAction Stop
        if ($regItem.SubKeyCount -ne 0) { throw "Registry key unexpectedly contains subkeys: $($Record.Id)" }
        $currentValue = [string]$regItem.GetValue('')
        if ($currentValue -ne [string]$Record.Identity) { throw "Registry value changed after planning: $($Record.Id)" }
    } elseif ($Record.Kind -eq 'NpmPackage') {
        $null = Assert-AuthorizedPath -Path $Record.Path -AllowedRoots @($matching[0].Path)
        $pkgJson = Join-Path $Record.Path 'package.json'
        $pkgPres = Get-TargetPresenceState $pkgJson
        if ($pkgPres.State -ne 'Present') { throw "npm Claude package is missing or inaccessible: $($Record.Id)" }
        $pkgObj = Get-Content -LiteralPath $pkgJson -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($pkgObj.name -ne '@anthropic-ai/claude-code') { throw "Unexpected npm package identity: $($pkgObj.name)" }
        if ([string]::IsNullOrWhiteSpace([string]$Record.Identity)) { throw "Missing npm prefix identity: $($Record.Id)" }
        $null = Get-NpmCommand
    } elseif ($Record.Kind -eq 'VsCodeExtension') {
        if ($Record.Path -ne 'anthropic.claude-code') { throw "Unexpected VS Code extension ID: $($Record.Path)" }
        if ([string]::IsNullOrWhiteSpace([string]$Record.Identity)) { throw "Missing VS Code extensions root identity: $($Record.Id)" }
        $null = Assert-AuthorizedPath -Path ([string]$Record.Identity) -AllowedRoots @([string]$Record.Identity)
        $null = Get-VsCodeCliCommand
        $extPres = Get-RecordPresenceState -Record $Record
        if ($extPres.State -ne 'Present') { throw "VS Code extension is missing or inaccessible: $($Record.Id)" }
    } else {
        throw "Unsupported action kind: $($Record.Kind)"
    }
}

function Invoke-CleanupPlan {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$PlanPath = $script:PlanPath,
        [AllowNull()][object[]]$CandidatesOverride = $null
    )
    $sourceCandidates = if ($null -ne $CandidatesOverride) { @($CandidatesOverride) } else { @(Get-CurrentCandidates) }
    $records = New-Object 'System.Collections.Generic.List[object]'
    foreach ($candidate in $sourceCandidates) {
        $rec = Get-ArtifactRecord $candidate
        if ($rec) { $records.Add($rec) }
    }
    $recordArray = $records.ToArray()
    if ($WhatIfPreference) {
        return [pscustomobject]@{
            PlanPath = $PlanPath
            Sha256 = $null
            Entries = $recordArray.Count
            Ready = @($recordArray | Where-Object { $_.Decision -eq 'Ready' }).Count
            NonReady = @($recordArray | Where-Object { $_.Decision -ne 'Ready' }).Count
            WhatIf = $true
        }
    }
    $hash = Write-PlanDocument -Records $recordArray -PlanPath $PlanPath
    return [pscustomobject]@{
        PlanPath = $PlanPath
        Sha256 = $hash
        Entries = $recordArray.Count
        Ready = @($recordArray | Where-Object { $_.Decision -eq 'Ready' }).Count
        NonReady = @($recordArray | Where-Object { $_.Decision -ne 'Ready' }).Count
        WhatIf = $false
    }
}

function Write-CleanupProgressEvent {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][int]$Total,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Status = '',
        [string]$Error = ''
    )
    if ($Phase -eq 'Cleaning') {
        $payload = [pscustomobject]@{
            Phase = 'Cleaning'
            Index = $Index
            Total = $Total
            Id = $Id
            Path = $Path
        }
    } else {
        $payload = [pscustomobject]@{
            Phase = $Phase
            Index = $Index
            Total = $Total
            Id = $Id
            Path = $Path
            Status = $Status
            Error = $Error
        }
    }
    [Console]::Error.WriteLine('@@PROGRESS@@' + ($payload | ConvertTo-Json -Compress))
}

function Invoke-VerifiedNonFsRemoval {
    param(
        [Parameter(Mandatory = $true)]$Record
    )
    $label = switch ($Record.Kind) {
        'AppxPackage' {
            Invoke-ClaudeAppxUninstall -PackageFullName $Record.Path
            'Appx package post-removal'
        }
        'RegistryKey' {
            Invoke-RegistryLeafKeyDeletion -Path $Record.Path -ExpectedDefaultValue ([string]$Record.Identity)
            'Registry key post-deletion'
        }
        'NpmPackage' {
            Invoke-NpmClaudeUninstall -PackageName '@anthropic-ai/claude-code' -PrefixPath ([string]$Record.Identity)
            'npm package post-uninstall'
        }
        'VsCodeExtension' {
            Invoke-VsCodeExtensionUninstall -ExtensionId $Record.Path
            'VS Code extension post-uninstall'
        }
        default { throw "Unsupported non-filesystem cleanup kind: $($Record.Kind)" }
    }
    $pres = Get-RecordPresenceState -Record $Record
    if ($pres.State -ne 'Absent') {
        throw "$label verification failed (PresenceState=$($pres.State)): $($Record.Path) $($pres.Error)"
    }
    return [pscustomobject]@{
        Id = $Record.Id; Policy = $Record.Policy; Kind = $Record.Kind; Path = $Record.Path
        Status = 'Removed'; ItemsRemoved = 1; ItemsFailed = 0; PartialRemoval = $false
        RemainingExists = $false; PresenceState = 'Absent'; VerifiedAbsent = $true; Error = ''
    }
}

function Invoke-CleanupApply {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('AccountData', 'FullRemoval')][string]$Policy,
        [Parameter(Mandatory = $true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ApprovedManifestSha256,
        [string]$PlanPath = $script:PlanPath,
        [string]$VerificationPath = $script:VerificationPath,
        [AllowNull()][object[]]$CandidatesOverride = $null,
        [switch]$CloseRunningProcesses,
        [AllowNull()][object[]]$ProcessesOverride = $null,
        [AllowNull()][scriptblock]$StopProcessAction = $null,
        [switch]$EmitProgress
    )
    $auth = Read-AuthorizedPlanDocument -PlanPath $PlanPath -ApprovedHash $ApprovedManifestSha256
    $manifest = $auth.Manifest
    $all = if ($null -ne $CandidatesOverride) { @($CandidatesOverride) } else { @(Get-CurrentCandidates) }

    $policyRecords = @($auth.Records | Where-Object { $_.Policy -eq $Policy })
    $selected = @($policyRecords | Where-Object { $_.Decision -eq 'Ready' })
    $skippedRecords = @($policyRecords | Where-Object { $_.Decision -ne 'Ready' })
    if ($selected.Count -eq 0) { throw "No Ready entries for policy $Policy." }

    $runningClaudeProcesses = @()
    if ($null -eq $CandidatesOverride -or $null -ne $ProcessesOverride) {
        $runningClaudeProcesses = @(Get-ClaudeProcess -ProcessesOverride $ProcessesOverride)
        if ($runningClaudeProcesses.Count -gt 0 -and -not $CloseRunningProcesses) {
            $procSummary = ($runningClaudeProcesses | ForEach-Object { "$($_.ProcessName) (PID=$($_.Id))" }) -join ', '
            throw "Claude is running. Processes: $procSummary. Shut it down normally and retry."
        }
        if ($null -eq $CandidatesOverride -and $Policy -eq 'FullRemoval' -and @($selected | Where-Object { $_.Id -like 'vscode-*' -or $_.Kind -eq 'VsCodeExtension' }).Count -gt 0) {
            $vscode = @(Get-Process -Name Code -ErrorAction SilentlyContinue)
            if ($vscode.Count -gt 0) { throw 'VS Code is running. Shut it down normally before removing its Claude extension.' }
        }
    }

    Assert-PlanAuthorizationNotConsumed -VerificationPath $VerificationPath -PlanId $manifest.PlanId -ManifestSha256 $auth.ManifestSha256
    foreach ($record in $selected) {
        if ($null -eq $CandidatesOverride -and $record.Kind -eq 'Filesystem') {
            $projBase = Get-NormalPath $script:ProjectRoot
            if (Test-PathWithin (Get-NormalPath $record.Path) $projBase) {
                throw "Project directory cannot be targeted in production apply: $($record.Path)"
            }
        }
        Assert-CurrentRecord -Record $record -Candidates $all
    }
    Assert-NoOverlappingTargets -Records $selected

    $seenNonFs = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($record in ($selected | Where-Object { $_.Kind -ne 'Filesystem' })) {
        $k = "$($record.Kind)|$($record.Path)"
        if (-not $seenNonFs.Add($k)) { throw "Duplicate non-filesystem target: $k" }
    }

    $results = New-Object 'System.Collections.Generic.List[object]'
    foreach ($sk in $skippedRecords) {
        $results.Add([pscustomobject]@{
            Id = $sk.Id; Policy = $sk.Policy; Kind = $sk.Kind; Path = $sk.Path
            Status = if ($sk.Decision -eq 'Blocked') { 'Blocked' } else { 'Skipped' }
            ItemsRemoved = 0; ItemsFailed = 0; PartialRemoval = $false
            RemainingExists = $null; PresenceState = 'Unchecked'; VerifiedAbsent = $false; Error = $sk.Reason
        })
    }

    $description = "Policy=$Policy; targets=$($selected.Count); manifest=$($auth.ManifestSha256)"
    if (-not $PSCmdlet.ShouldProcess($description, 'Apply permanent Claude cleanup')) {
        foreach ($record in $selected) {
            $results.Add([pscustomobject]@{
                Id = $record.Id; Policy = $record.Policy; Kind = $record.Kind; Path = $record.Path
                Status = 'PreviewOnly'; ItemsRemoved = 0; ItemsFailed = 0; PartialRemoval = $false
                RemainingExists = $true; PresenceState = 'Present'; VerifiedAbsent = $false; Error = ''
            })
        }
        return [pscustomobject]@{
            PlanId = $manifest.PlanId
            ManifestSha256 = $auth.ManifestSha256
            Policy = $Policy
            Outcome = 'PreviewOnly'
            Results = $results.ToArray()
        }
    }

    if ($CloseRunningProcesses -and $runningClaudeProcesses.Count -gt 0) {
        # Terminate main Claude desktop/CLI processes before native host helpers to prevent respawns
        $orderedProcs = @(
            $runningClaudeProcesses | Sort-Object { if ($_.ProcessName -match '(?i)^chrome-native-host') { 1 } else { 0 } }
        )
        $stopOneProc = {
            param($targetProc)
            if ($null -ne $StopProcessAction) {
                & $StopProcessAction $targetProc
            } elseif ($targetProc.Id -gt 0) {
                Stop-Process -Id $targetProc.Id -Force -ErrorAction SilentlyContinue
            }
        }
        foreach ($proc in $orderedProcs) {
            & $stopOneProc $proc
        }
        if ($null -eq $ProcessesOverride) {
            for ($waitStep = 0; $waitStep -lt 10; $waitStep++) {
                Start-Sleep -Milliseconds 250
                $remainingProcs = @(Get-ClaudeProcess)
                if ($remainingProcs.Count -eq 0) { break }
                foreach ($remProc in $remainingProcs) {
                    & $stopOneProc $remProc
                }
            }
            $stillRunning = @(Get-ClaudeProcess)
            if ($stillRunning.Count -gt 0) {
                $stillSummary = ($stillRunning | ForEach-Object { "$($_.ProcessName) (PID=$($_.Id))" }) -join ', '
                throw "Claude is running. Processes: $stillSummary. Unable to close automatically; shut it down normally and retry."
            }
        }
    }

    $startedUtc = [DateTime]::UtcNow.ToString('o')
    $ledgerEntry = [pscustomobject]@{
        PlanId = $manifest.PlanId
        ManifestSha256 = $auth.ManifestSha256
        Policy = $Policy
        StartedUtc = $startedUtc
        CompletedUtc = $null
        Outcome = 'Started'
        Results = @()
    }
    Save-ExecutionLedgerEntry -VerificationPath $VerificationPath -Entry $ledgerEntry

    $failed = $false
    $failedMessages = New-Object 'System.Collections.Generic.List[string]'
    $succeededCount = 0

    for ($idx = 0; $idx -lt $selected.Count; $idx++) {
        $record = $selected[$idx]

        if ($EmitProgress) {
            Write-CleanupProgressEvent -Phase 'Cleaning' -Index ($idx + 1) -Total $selected.Count -Id $record.Id -Path $record.Path
        }
        $emitStatus = 'Removed'
        $emitError = ''
        try {
            Assert-CurrentRecord -Record $record -Candidates $all
            if ($record.Kind -eq 'Filesystem') {
                $expFileIdx = [Nullable[uint64]][uint64]$record.FileIndex
                $expVol = [Nullable[uint32]][uint32]$record.VolumeSerialNumber
                $res = Invoke-SafeFileRemoval -Path $record.Path -AllowedRoots @($record.Path) -ExpectedFileIndex $expFileIdx -ExpectedVolumeSerial $expVol -ReturnFailureResult -Confirm:$false
                if ($res.Status -eq 'Failed') {
                    $failed = $true
                    $failedMessages.Add("Target $($record.Id) failed: $($res.Error)")
                    $emitStatus = 'Failed'
                    $emitError = [string]$res.Error
                    $results.Add([pscustomobject]@{
                        Id = $record.Id; Policy = $record.Policy; Kind = $record.Kind; Path = $record.Path
                        Status = 'Failed'; ItemsRemoved = $res.ItemsRemoved; ItemsFailed = $res.ItemsFailed
                        PartialRemoval = $res.PartialRemoval; RemainingExists = $res.RemainingExists
                        PresenceState = $res.PresenceState; VerifiedAbsent = $false; Error = $res.Error
                    })
                } else {
                    $pres = Get-RecordPresenceState -Record $record
                    if ($pres.State -ne 'Absent') {
                        throw "Post-deletion verification failed (PresenceState=$($pres.State)): $($pres.Error)"
                    }
                    $succeededCount++
                    $emitStatus = [string]$res.Status
                    $results.Add([pscustomobject]@{
                        Id = $record.Id; Policy = $record.Policy; Kind = $record.Kind; Path = $record.Path
                        Status = $res.Status; ItemsRemoved = $res.ItemsRemoved; ItemsFailed = 0
                        PartialRemoval = $false; RemainingExists = $false
                        PresenceState = 'Absent'; VerifiedAbsent = $true; Error = ''
                    })
                }
            } elseif ($record.Kind -in @('AppxPackage', 'RegistryKey', 'NpmPackage', 'VsCodeExtension')) {
                $results.Add((Invoke-VerifiedNonFsRemoval -Record $record))
                $succeededCount++
            }
        } catch {
            $failed = $true
            $failedMessages.Add("Target $($record.Id) failed: $($_.Exception.Message)")
            $emitStatus = 'Failed'
            $emitError = [string]$_.Exception.Message
            $pres = Get-RecordPresenceState -Record $record
            $rem = if ($pres.State -eq 'Present') { $true } elseif ($pres.State -eq 'Absent') { $false } else { $null }
            $results.Add([pscustomobject]@{
                Id = $record.Id; Policy = $record.Policy; Kind = $record.Kind; Path = $record.Path
                Status = 'Failed'; ItemsRemoved = 0; ItemsFailed = 1; PartialRemoval = $false
                RemainingExists = $rem; PresenceState = $pres.State
                VerifiedAbsent = ($pres.State -eq 'Absent'); Error = $_.Exception.Message
            })
        }
        if ($EmitProgress) {
            Write-CleanupProgressEvent -Phase 'Result' -Index ($idx + 1) -Total $selected.Count -Id $record.Id -Path $record.Path -Status $emitStatus -Error $emitError
        }
    }

    $hasPartial = (@($results | Where-Object { $_.PartialRemoval }).Count -gt 0) -or ($failed -and $succeededCount -gt 0)
    $outcome = if (-not $failed) { 'Succeeded' } elseif ($hasPartial) { 'PartialFailure' } else { 'Failed' }
    $failureMessage = $failedMessages -join '; '

    $finalEntry = [pscustomobject]@{
        PlanId = $manifest.PlanId
        ManifestSha256 = $auth.ManifestSha256
        Policy = $Policy
        StartedUtc = $startedUtc
        CompletedUtc = [DateTime]::UtcNow.ToString('o')
        Outcome = $outcome
        Results = $results.ToArray()
    }
    try {
        Save-ExecutionLedgerEntry -VerificationPath $VerificationPath -Entry $finalEntry -UpdateExisting
    } catch {
        throw (New-Object System.IO.IOException("Cleanup apply ran (provisional outcome '$outcome'), but durable verification ledger commit failed: $($_.Exception.Message)", $_.Exception))
    }

    if ($failed) {
        $ex = New-Object System.InvalidOperationException("Cleanup apply finished with outcome '$outcome': $failureMessage")
        $ex.Data['ApplyResult'] = $finalEntry
        throw $ex
    }
    return $finalEntry
}

function Invoke-CleanupVerify {
    param(
        [string]$PlanPath = $script:PlanPath,
        [string]$VerificationPath = $script:VerificationPath,
        [AllowNull()][object[]]$CandidatesOverride = $null
    )
    $sourceCandidates = if ($null -ne $CandidatesOverride) { @($CandidatesOverride) } else { @(Get-CurrentCandidates) }
    $currentRecords = New-Object 'System.Collections.Generic.List[object]'
    foreach ($c in $sourceCandidates) {
        $rec = Get-ArtifactRecord $c
        if ($rec) { $currentRecords.Add($rec) }
    }
    $planChecks = New-Object 'System.Collections.Generic.List[object]'
    $planSha = $null
    $planId = $null
    $planError = ''
    if (Test-Path -LiteralPath $PlanPath) {
        $bytes = [IO.File]::ReadAllBytes($PlanPath)
        $planSha = Get-Sha256FromBytes -Bytes $bytes
        try {
            $parsed = Read-AuthorizedPlanDocument -PlanPath $PlanPath
            $planId = $parsed.Manifest.PlanId
            foreach ($record in $parsed.Records) {
                $pres = Get-RecordPresenceState -Record $record
                $presentVal = if ($pres.State -eq 'Present') { $true } elseif ($pres.State -eq 'Absent') { $false } else { $null }
                $planChecks.Add([pscustomobject]@{
                    Policy = $record.Policy
                    Id = $record.Id
                    Decision = $record.Decision
                    Kind = $record.Kind
                    Path = $record.Path
                    Present = $presentVal
                    PresenceState = $pres.State
                    PresenceError = $pres.Error
                })
            }
        } catch {
            $planError = $_.Exception.Message
        }
    }
    $ledger = @()
    $ledgerError = ''
    try {
        $ledger = @(Get-ExecutionLedgerEntries -VerificationPath $VerificationPath)
    } catch {
        $ledgerError = $_.Exception.Message
    }
    return [pscustomobject]@{
        PlanId = $planId
        PlanSha256 = $planSha
        PlanError = $planError
        CurrentInventory = $currentRecords.ToArray()
        RemainingAccountIds = @(Get-ClaudeResidualAccountMetadata)
        PlanChecks = $planChecks.ToArray()
        LedgerEntries = $ledger
        LedgerError = $ledgerError
    }
}

function Get-StructuredAuditReport {
    return [pscustomobject]@{
        SchemaVersion = 3
        Mode = 'Audit'
        GeneratedUtc = [DateTime]::UtcNow.ToString('o')
        WindowsUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Summary = (Get-WindowsResidualSummary)
        EnvironmentLines = @(Get-EnvironmentReport)
        Inventory = @(Get-Inventory)
    }
}

function Show-Help {
    param([string]$Lang = $script:ActiveLanguage)

    if ($Lang -eq 'zh-CN') {
        @'
ClaudeCleanup.ps1 - Windows Claude 账号封号残余 ID 与缓存安全清理工具

  .\ClaudeCleanup.ps1 -Audit [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json] [-SaveAuditReport]
  .\ClaudeCleanup.ps1 -Plan [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
  .\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64位哈希> -WhatIf
  .\ClaudeCleanup.ps1 -Apply -Policy FullRemoval -ApprovedManifestSha256 <64位哈希> [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
  .\ClaudeCleanup.ps1 -Verify [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
  .\ClaudeCleanup.ps1 -Help [-Language Auto|zh-CN|en-US]

产品定位与安全边界:
  专用于扫描并安全清理 Claude 账号封禁后遗留的本地账号/设备元数据、授权缓存、会话缓存、扩展及残留注册项，
  绝不改动或损害 Windows 操作系统本身。默认模式严格为只读审计（-Audit）。
  -Plan 仅生成本地 CLEANUP-PLAN.md。-Apply 必须由用户明确批准精确的 64 位 SHA-256 哈希与单一清理策略
  （AccountData 或 FullRemoval），且每份已批清单最多可执行一次真实删除（-WhatIf 预览不消耗授权）。
  不会修改 WSL、浏览器站点数据、系统硬件/设备 ID、系统遥测、代理设置或无关软件，亦无自动备份/回收站。
'@ | Write-Output
        return
    }
    @'
ClaudeCleanup.ps1 - Windows Claude Banned-Account Residual ID & Cache Cleanup Utility

  .\ClaudeCleanup.ps1 -Audit [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json] [-SaveAuditReport]
  .\ClaudeCleanup.ps1 -Plan [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
  .\ClaudeCleanup.ps1 -Apply -Policy AccountData -ApprovedManifestSha256 <64-hex-hash> -WhatIf
  .\ClaudeCleanup.ps1 -Apply -Policy FullRemoval -ApprovedManifestSha256 <64-hex-hash> [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
  .\ClaudeCleanup.ps1 -Verify [-Language Auto|zh-CN|en-US] [-OutputFormat Text|Json]
  .\ClaudeCleanup.ps1 -Help [-Language Auto|zh-CN|en-US]

Product Positioning & Safety Boundaries:
  Specifically designed as a non-destructive Windows utility to scan and safely clean residual Claude
  account/device metadata, auth caches, session storage, extensions, and leftover registrations after
  a Claude account ban — strictly without altering or harming the Windows OS itself.
  Audit and Verify inspect without deleting (read-only default). Plan writes only CLEANUP-PLAN.md.
  Apply requires a separately approved, unchanged SchemaVersion 3 plan hash and one policy; each
  approved manifest hash can be applied at most once (preview with -WhatIf does not consume it).
  It does not modify WSL, browser profiles, OS hardware/device IDs, telemetry, proxy settings,
  or unrelated software. Credential Manager entries are audited by target count only. No backup is made.
'@ | Write-Output
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-Utf8ConsoleEncoding
    $script:ActiveLanguage = Resolve-UiLanguage -RequestedLanguage $Language
    $isZh = ($script:ActiveLanguage -eq 'zh-CN')
    $modeCount = @($Audit, $Plan, $Apply, $Verify, $Help | Where-Object { $_ }).Count
    if ($modeCount -ne 1) {
        if ($isZh) { throw '请仅选择一个运行模式: -Audit、-Plan、-Apply、-Verify 或 -Help。' }
        throw 'Choose exactly one mode: -Audit, -Plan, -Apply, -Verify, or -Help.'
    }
    if ($Help) { Show-Help -Lang $script:ActiveLanguage; return }
    if ($Audit) {
        $auditReport = Get-StructuredAuditReport
        if ($SaveAuditReport) {
            $targetAuditPath = $script:AuditPath
            if (-not [string]::IsNullOrWhiteSpace($AuditOutputPath)) {
                $fullOut = [IO.Path]::GetFullPath($AuditOutputPath)
                if ((Get-TargetPresenceState -Path $fullOut).State -eq 'Present') {
                    $itemOut = Get-Item -LiteralPath $fullOut -Force -ErrorAction Stop
                    if ($itemOut.PSIsContainer -or (($itemOut.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                        throw "Refusing unsafe -AuditOutputPath target: $fullOut"
                    }
                }
                $targetAuditPath = $fullOut
            }
            $null = Write-AuditReportDocument -AuditPath $targetAuditPath -Lang $script:ActiveLanguage -StructuredReport $auditReport
        }
        if ($OutputFormat -eq 'Json') {
            $auditReport | ConvertTo-Json -Depth 10 | Write-Output
            return
        }
        Write-Output (Get-LocalizedUiText -Key 'PositioningTagline' -Lang $script:ActiveLanguage)
        Write-Output (Get-LocalizedUiText -Key 'SafetyDisclaimer' -Lang $script:ActiveLanguage)
        Write-Output ''
        Get-EnvironmentReport | Write-Output
        $auditReport.Inventory | Format-Table Policy, Category, Path, SizeBytes, Ownership, Decision, Reason -AutoSize | Out-String -Width 260 | Write-Output
        return
    }
    if ($Plan) {
        $planResult = Invoke-CleanupPlan -PlanPath $script:PlanPath -WhatIf:$WhatIfPreference
        if ($OutputFormat -eq 'Json') {
            $planResult | ConvertTo-Json -Depth 6 | Write-Output
            return
        }
        if ($planResult.WhatIf) {
            if ($isZh) { Write-Output "WhatIf 预览: 将写入 $($planResult.PlanPath)，共 $($planResult.Entries) 个候选项。" }
            else { Write-Output "WhatIf: would write $($planResult.PlanPath) with $($planResult.Entries) candidate entries." }
            return
        }
        if ($isZh) {
            Write-Output "清理方案已生成: $($planResult.PlanPath)"
            Write-Output "SHA256: $($planResult.Sha256)"
            Write-Output "条目统计: 共 $($planResult.Entries) 项；Ready(可执行): $($planResult.Ready)；ReviewOnly/Blocked(受保护/跳过): $($planResult.NonReady)"
        } else {
            Write-Output "Plan: $($planResult.PlanPath)"
            Write-Output "SHA256: $($planResult.Sha256)"
            Write-Output "Entries: $($planResult.Entries); Ready: $($planResult.Ready); ReviewOnly/Blocked: $($planResult.NonReady)"
        }
        return
    }
    if ($Verify) {
        $ver = Invoke-CleanupVerify -PlanPath $script:PlanPath -VerificationPath $script:VerificationPath
        if ($OutputFormat -eq 'Json') {
            [pscustomobject]@{
                SchemaVersion = 3
                Mode = 'Verify'
                Language = $script:ActiveLanguage
                GeneratedUtc = [DateTime]::UtcNow.ToString('o')
                Summary = (Get-WindowsResidualSummary)
                EnvironmentLines = @(Get-EnvironmentReport)
                Verify = $ver
            } | ConvertTo-Json -Depth 10 | Write-Output
            return
        }
        Write-Output (Get-LocalizedUiText -Key 'PositioningTagline' -Lang $script:ActiveLanguage)
        Write-Output ''
        Get-EnvironmentReport | Write-Output
        if ($isZh) { Write-Output '当前 Claude 残余候选项（只读检测）:' }
        else { Write-Output 'Current Claude candidate inventory (read-only):' }
        $ver.CurrentInventory | Format-Table Policy, Category, Path, Decision -AutoSize | Out-String -Width 240 | Write-Output
        if ($ver.PlanError) {
            if ($isZh) { Write-Output ("清单警告 (SHA256={0}): {1} 请重新运行 -Plan 生成 SchemaVersion 3 清单。" -f $ver.PlanSha256, $ver.PlanError) }
            else { Write-Output ("Plan warning (SHA256={0}): {1} Re-run -Plan to generate a SchemaVersion 3 manifest." -f $ver.PlanSha256, $ver.PlanError) }
        } elseif ($ver.PlanChecks.Count -gt 0) {
            if ($isZh) { Write-Output "清单状态核验 (PlanId=$($ver.PlanId); SHA256=$($ver.PlanSha256)):" }
            else { Write-Output "Plan check (PlanId=$($ver.PlanId); SHA256=$($ver.PlanSha256)):" }
            foreach ($chk in $ver.PlanChecks) {
                Write-Output ("{0}: {1} [{2}] state={3} present={4}" -f $chk.Policy, $chk.Id, $chk.Decision, $chk.PresenceState, $chk.Present)
            }
        }
        if ($ver.LedgerError) {
            if ($isZh) { Write-Output ("执行账本警告: {0}" -f $ver.LedgerError) }
            else { Write-Output ("Ledger error: {0}" -f $ver.LedgerError) }
        } elseif ($ver.LedgerEntries.Count -gt 0) {
            if ($isZh) { Write-Output "执行账本记录数: $($ver.LedgerEntries.Count)" }
            else { Write-Output "Execution ledger entries: $($ver.LedgerEntries.Count)" }
            foreach ($le in $ver.LedgerEntries) {
                Write-Output ("Ledger: PlanId={0} Policy={1} Outcome={2} Started={3}" -f $le.PlanId, $le.Policy, $le.Outcome, $le.StartedUtc)
            }
        }
        return
    }
    if ($Apply) {
        if (-not $Policy -or -not $ApprovedManifestSha256) {
            if ($isZh) { throw '-Apply 需要同时提供 -Policy 与 -ApprovedManifestSha256。' }
            throw '-Apply requires -Policy and -ApprovedManifestSha256.'
        }
        $authPreview = Read-AuthorizedPlanDocument -PlanPath $script:PlanPath -ApprovedHash $ApprovedManifestSha256
        $previewTargets = @($authPreview.Records | Where-Object { $_.Policy -eq $Policy -and $_.Decision -eq 'Ready' })
        if ($OutputFormat -ne 'Json') {
            foreach ($record in $previewTargets) {
                Write-Output ("Target: {0}; category={1}; kind={2}; path={3}" -f $record.Id, $record.Category, $record.Kind, $record.Path)
            }
        }
        $applyResult = $null
        $applyPartialOrFailed = $false
        try {
            $applyResult = Invoke-CleanupApply -Policy $Policy -ApprovedManifestSha256 $ApprovedManifestSha256 -PlanPath $script:PlanPath -VerificationPath $script:VerificationPath -CloseRunningProcesses:$CloseRunningProcesses -EmitProgress:$EmitProgress -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
        } catch {
            if ($null -ne $_.Exception.Data -and $_.Exception.Data.Contains('ApplyResult') -and $null -ne $_.Exception.Data['ApplyResult']) {
                $applyResult = $_.Exception.Data['ApplyResult']
                $applyPartialOrFailed = $true
            } else {
                throw
            }
        }
        if ($OutputFormat -eq 'Json') {
            $applyResult | ConvertTo-Json -Depth 10 | Write-Output
            if ($applyPartialOrFailed) { exit 2 }
            return
        }
        if ($applyResult.Outcome -eq 'PreviewOnly') {
            if ($isZh) { Write-Output '仅预览（WhatIf），未执行任何实际删除。' }
            else { Write-Output 'Preview only; no deletion performed.' }
            return
        }
        $applyResult.Results | Format-Table Id, Policy, Status, ItemsRemoved, ItemsFailed, PartialRemoval, PresenceState, RemainingExists, VerifiedAbsent -AutoSize | Out-String -Width 260 | Write-Output
        if ($isZh) { Write-Output "执行结果: $($applyResult.Outcome)。请独立运行 -Verify 核验残余；本地清理不影响远端服务器账号状态。" }
        else { Write-Output "Apply outcome: $($applyResult.Outcome). Run -Verify independently; do not infer remote account changes." }
        if ($applyPartialOrFailed) { exit 2 }
    }
}
