using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Microsoft.Win32;

namespace ClaudeResidualIdCleaner
{
    public sealed class ResidualGridRow : INotifyPropertyChanged
    {
        private bool _selected;
        private string _status;
        private string _statusTone;
        private string _details;

        public event PropertyChangedEventHandler PropertyChanged;

        private void Notify(string name)
        {
            PropertyChangedEventHandler handler = PropertyChanged;
            if (handler != null)
            {
                handler(this, new PropertyChangedEventArgs(name));
            }
        }

        public bool Selected
        {
            get { return _selected; }
            set
            {
                if (_selected != value)
                {
                    _selected = value;
                    Notify("Selected");
                }
            }
        }

        public bool CanSelect { get; set; }
        public bool IsClearedItem { get; set; }
        public string ScopeKey { get; set; }
        public string Policy { get; set; }
        public string ItemId { get; set; }
        public string Kind { get; set; }
        public string Category { get; set; }
        public string PathOrPackage { get; set; }

        public string Status
        {
            get { return _status; }
            set
            {
                if (_status != value)
                {
                    _status = value;
                    Notify("Status");
                }
            }
        }

        public string StatusTone
        {
            get { return _statusTone; }
            set
            {
                if (_statusTone != value)
                {
                    _statusTone = value;
                    Notify("StatusTone");
                    Notify("StatusBg");
                    Notify("StatusBorder");
                    Notify("StatusFg");
                }
            }
        }

        public string Decision { get; set; }

        public string Details
        {
            get { return _details; }
            set
            {
                if (_details != value)
                {
                    _details = value;
                    Notify("Details");
                }
            }
        }

        public long SizeBytes { get; set; }

        public Brush StatusBg
        {
            get
            {
                if (StatusTone == "Ready") return MainWindow.BrushBadgeReadyBg;
                if (StatusTone == "Cleaning") return MainWindow.BrushBadgeCleaningBg;
                if (StatusTone == "Locked") return MainWindow.BrushBadgeLockedBg;
                if (StatusTone == "ReadOnly") return MainWindow.BrushBadgeReadOnlyBg;
                if (StatusTone == "Clean") return MainWindow.BrushBadgeCleanBg;
                if (StatusTone == "Excluded") return MainWindow.BrushBadgeExcludedBg;
                if (StatusTone == "Review") return MainWindow.BrushBadgeReviewBg;
                return MainWindow.BrushBadgeProtectedBg;
            }
        }

        public Brush StatusBorder
        {
            get
            {
                if (StatusTone == "Ready") return MainWindow.BrushBadgeReadyBorder;
                if (StatusTone == "Cleaning") return MainWindow.BrushBadgeCleaningBorder;
                if (StatusTone == "Locked") return MainWindow.BrushBadgeLockedBorder;
                if (StatusTone == "ReadOnly") return MainWindow.BrushBadgeReadOnlyBorder;
                if (StatusTone == "Clean") return MainWindow.BrushBadgeCleanBorder;
                if (StatusTone == "Excluded") return MainWindow.BrushBadgeExcludedBorder;
                if (StatusTone == "Review") return MainWindow.BrushBadgeReviewBorder;
                return MainWindow.BrushBadgeProtectedBorder;
            }
        }

        public Brush StatusFg
        {
            get
            {
                if (StatusTone == "Ready") return MainWindow.BrushBadgeReadyFg;
                if (StatusTone == "Cleaning") return MainWindow.BrushBadgeCleaningFg;
                if (StatusTone == "Locked") return MainWindow.BrushBadgeLockedFg;
                if (StatusTone == "ReadOnly") return MainWindow.BrushBadgeReadOnlyFg;
                if (StatusTone == "Clean") return MainWindow.BrushBadgeCleanFg;
                if (StatusTone == "Excluded") return MainWindow.BrushBadgeExcludedFg;
                if (StatusTone == "Review") return MainWindow.BrushBadgeReviewFg;
                return MainWindow.BrushBadgeProtectedFg;
            }
        }
    }

    internal sealed class ResidualAccountIdRecord
    {
        public string Source;
        public string IdType;
        public string Field;
        public string Value;
        public string ConfigPath;
    }

    internal sealed class BackendRunResult
    {
        public int ExitCode;
        public string StdOut;
        public string StdErr;
    }

    internal sealed class SelfTestReport
    {
        public bool AppInstantiated;
        public string InitialLanguage;
        public string ToggledLanguage;
        public string InitialHeaderTitle;
        public string ToggledHeaderTitle;
        public string InitialSafetyPill;
        public string ToggledSafetyPill;
        public int ScopeCheckboxCount;
        public int DataGridColumnCount;
        public bool InitialCleanButtonEnabled;
        public bool BackendFound;
        public string ResolvedToolkitRoot;
        public bool DryRun;
        public int NavTabCount;
        public int MetricCardCount;
        public string ThemeStyle;
        public bool HasGridSplitter;
        public bool HasAccountIdCard;
        public bool HorizontalScrollEnabled;
        public int AccountIdCount;
        public bool HasWindowIcon;
        public bool IsElevated;
        public string PrivilegeBadgeText;
        public bool HasRestartAdminButton;
        public bool HasCleaningProgressPanel;
        public bool HasCompletionSummaryBanner;
        public bool HasReportsView;
        public bool CleaningProgressVisible;
        public bool CompletionBannerVisible;
    }

    public sealed class MainWindow : Window
    {
        // Modern Dark Studio Palette
        internal static readonly Brush BrushBgOuter = CreateBrush(24, 26, 31);          // #181A1F
        internal static readonly Brush BrushBgChrome = CreateBrush(29, 32, 38);         // #1D2026
        internal static readonly Brush BrushBgCard = CreateBrush(33, 37, 43);           // #21252B
        internal static readonly Brush BrushBgElevated = CreateBrush(40, 44, 52);       // #282C34
        internal static readonly Brush BrushBgLog = CreateBrush(20, 22, 26);            // #14161A
        internal static readonly Brush BrushBorderSubtle = CreateBrush(50, 56, 66);     // #323842
        internal static readonly Brush BrushAccent = CreateBrush(59, 130, 246);         // #3B82F6
        internal static readonly Brush BrushAccentBright = CreateBrush(96, 165, 250);   // #60A5FA
        internal static readonly Brush BrushTealAction = CreateBrush(14, 116, 144);     // #0E7490
        internal static readonly Brush BrushDangerAction = CreateBrush(185, 28, 28);    // #B91C1C
        internal static readonly Brush BrushNeutralAction = CreateBrush(40, 44, 52);    // #282C34
        internal static readonly Brush BrushSafetyBg = CreateBrush(16, 42, 28);         // #102A1C
        internal static readonly Brush BrushSafetyAction = CreateBrush(22, 163, 74);    // #16A34A
        internal static readonly Brush BrushSafetyBorder = CreateBrush(34, 197, 94);    // #22C55E
        internal static readonly Brush BrushSafetyFg = CreateBrush(134, 239, 172);      // #86EFAC
        internal static readonly Brush BrushTextPrimary = CreateBrush(243, 244, 246);   // #F3F4F6
        internal static readonly Brush BrushTextSecondary = CreateBrush(156, 163, 175); // #9CA3AF
        internal static readonly Brush BrushTextMuted = CreateBrush(107, 114, 128);     // #6B7280
        internal static readonly Brush BrushDemoBannerBg = CreateBrush(23, 37, 54);     // #172536
        internal static readonly Brush BrushDemoBannerBorder = CreateBrush(96, 165, 250); // #60A5FA

        internal static readonly Brush BrushBadgeReadyBg = CreateBrush(58, 36, 18);
        internal static readonly Brush BrushBadgeReadyBorder = CreateBrush(245, 158, 11);
        internal static readonly Brush BrushBadgeReadyFg = CreateBrush(253, 224, 71);
        internal static readonly Brush BrushBadgeCleaningBg = CreateBrush(23, 44, 77);
        internal static readonly Brush BrushBadgeCleaningBorder = CreateBrush(96, 165, 250);
        internal static readonly Brush BrushBadgeCleaningFg = CreateBrush(147, 197, 253);
        internal static readonly Brush BrushBadgeLockedBg = CreateBrush(69, 26, 26);
        internal static readonly Brush BrushBadgeLockedBorder = CreateBrush(239, 68, 68);
        internal static readonly Brush BrushBadgeLockedFg = CreateBrush(252, 165, 165);
        internal static readonly Brush BrushBadgeReadOnlyBg = CreateBrush(23, 37, 58);
        internal static readonly Brush BrushBadgeReadOnlyBorder = CreateBrush(59, 130, 246);
        internal static readonly Brush BrushBadgeReadOnlyFg = CreateBrush(147, 197, 253);
        internal static readonly Brush BrushBadgeCleanBg = CreateBrush(16, 42, 28);
        internal static readonly Brush BrushBadgeCleanBorder = CreateBrush(34, 197, 94);
        internal static readonly Brush BrushBadgeCleanFg = CreateBrush(134, 239, 172);
        internal static readonly Brush BrushBadgeExcludedBg = CreateBrush(44, 46, 54);
        internal static readonly Brush BrushBadgeExcludedBorder = CreateBrush(107, 114, 128);
        internal static readonly Brush BrushBadgeExcludedFg = CreateBrush(209, 213, 219);
        internal static readonly Brush BrushBadgeReviewBg = CreateBrush(48, 42, 32);
        internal static readonly Brush BrushBadgeReviewBorder = CreateBrush(180, 140, 68);
        internal static readonly Brush BrushBadgeReviewFg = CreateBrush(253, 230, 138);
        internal static readonly Brush BrushBadgeProtectedBg = CreateBrush(58, 28, 52);
        internal static readonly Brush BrushBadgeProtectedBorder = CreateBrush(217, 70, 239);
        internal static readonly Brush BrushBadgeProtectedFg = CreateBrush(245, 208, 254);

        private string _lang;
        private string _toolkitRoot;
        private readonly bool _dryRun;
        private readonly bool _demoAudit;
        private readonly bool _isElevated;
        private bool _hasWindowIcon;
        private int _activeNavIndex;
        private bool _logsExpanded;
        private double _lastLogHeight = 112.0;
        private bool _hasScanned;
        private bool _hasPlan;
        private string _planSha256 = string.Empty;
        private int _readyCount;
        private bool _suppressSelectAllSync;
        private int _busyDepth;

        // Real-time cleaning & completion state
        private bool _isDemoCleaning;
        private bool _isDemoVerified;
        private bool _cleaningInProgress;
        private int _cleaningCurrentIndex;
        private int _cleaningTotalCount;
        private string _cleaningCurrentPath = string.Empty;
        private bool _showCompletionBanner;
        private int _lastCleanedCount;
        private int _lastLockedCount;
        private int _lastRemainingCount;

        private readonly ObservableCollection<ResidualGridRow> _allRows = new ObservableCollection<ResidualGridRow>();
        private readonly ObservableCollection<ResidualGridRow> _visibleRows = new ObservableCollection<ResidualGridRow>();
        private readonly List<ResidualAccountIdRecord> _accountIdRecords = new List<ResidualAccountIdRecord>();

        private readonly List<Button> _navButtons = new List<Button>();
        private readonly List<Border> _navIndicators = new List<Border>();
        private readonly List<Border> _metricCards = new List<Border>();
        private readonly List<CheckBox> _scopeCheckboxes = new List<CheckBox>();

        private Border _brandPill;
        private TextBlock _lblBrandName;
        private TextBlock _lblHeaderTitle;
        private TextBlock _lblVersionBadge;
        private TextBlock _lblSafetyPill;
        private Border _privilegeBadgeBorder;
        private TextBlock _lblPrivilegeBadge;
        private TextBlock _lblPositioning;
        private Button _btnRestartAdmin;
        private Button _btnPolicyPill;
        private Button _btnLangToggle;
        private Button _btnAbout;

        private TextBlock _lblSidebarSection;
        private TextBlock _lblSidebarGuardTitle;
        private TextBlock _lblSidebarGuardBody;

        private Border _contextBannerBorder;
        private TextBlock _lblContextBanner;

        private Grid _workspacePanel;
        private ScrollViewer _reportsPanel;
        private ScrollViewer _aboutPanel;

        private Border _accountIdCard;
        private TextBlock _lblAccountIdCardTitle;
        private TextBlock _lblAccountIdCardSub;
        private TextBox _txtAccountIdValue;
        private Button _btnCopyAccountId;

        private TextBlock _lblMetricScannedTitle;
        private TextBlock _lblMetricScannedValue;
        private TextBlock _lblMetricScannedSub;
        private TextBlock _lblMetricFoundTitle;
        private TextBlock _lblMetricFoundValue;
        private TextBlock _lblMetricFoundSub;
        private TextBlock _lblMetricSizeTitle;
        private TextBlock _lblMetricSizeValue;
        private TextBlock _lblMetricSizeSub;
        private TextBlock _lblMetricSafetyTitle;
        private TextBlock _lblMetricSafetyValue;
        private TextBlock _lblMetricSafetySub;

        private TextBlock _lblScopeHeader;
        private CheckBox _chkCli;
        private CheckBox _chkDesktop;
        private CheckBox _chkVsCode;
        private CheckBox _chkCred;
        private CheckBox _chkEnv;

        private TextBlock _lblPolicyHeader;
        private RadioButton _rbAccountData;
        private RadioButton _rbFullRemoval;
        private TextBlock _lblPolicyAccountText;
        private TextBlock _lblPolicyFullText;

        private Button _btnScan;
        private Button _btnPlan;
        private Button _btnClean;
        private Button _btnVerify;
        private Button _btnOpenFolder;
        private Button _btnExportSummary;
        private Button _btnToggleLogs;

        private TextBlock _lblPresetLabel;
        private Button _btnPresetAccount;
        private Button _btnPresetFull;
        private Border _planGatePillBorder;
        private TextBlock _lblPlanGatePill;
        private CheckBox _chkSelectAll;

        // Real-Time Cleaning Progress Panel
        private Border _cleaningProgressCard;
        private TextBlock _lblCleanProgressTitle;
        private TextBlock _lblCleanProgressPercent;
        private TextBlock _lblCleanProgressBanner;
        private ProgressBar _cleanProgressBar;

        // Post-Verify Completion Summary Banner
        private Border _completionSummaryBanner;
        private TextBlock _lblCompletionTitle;
        private TextBlock _lblCompletionSub;
        private Button _btnCompletionViewReports;

        private DataGrid _gridResults;
        private DataGridCheckBoxColumn _colSelect;
        private DataGridTextColumn _colCategory;
        private DataGridTextColumn _colPath;
        private DataGridTemplateColumn _colStatus;
        private DataGridTextColumn _colDetails;
        private TextBlock _lblGridEmptyHint;

        private GridSplitter _logSplitter;
        private Border _logDrawerPanel;
        private RowDefinition _logDrawerRow;
        private TextBlock _lblLogDrawerTitle;
        private TextBox _txtLog;

        // View 1: Reports & Export
        private TextBlock _lblReportsViewTitle;
        private TextBlock _lblReportsViewSub;
        private Button _btnRefreshReports;
        private Button _btnReportsOpenFolder;
        private Button _btnReportsExportAudit;
        private Button _btnReportsVerify;

        private TextBlock _lblReportAuditTitle;
        private TextBlock _lblReportAuditMeta;
        private TextBox _txtReportAuditSummary;
        private Button _btnSaveAuditAs;
        private Button _btnOpenAuditFile;

        private TextBlock _lblReportPlanTitle;
        private TextBlock _lblReportPlanMeta;
        private TextBox _txtReportPlanSummary;
        private Button _btnSavePlanAs;
        private Button _btnOpenPlanFile;

        private TextBlock _lblReportVerifyTitle;
        private TextBlock _lblReportVerifyMeta;
        private TextBox _txtReportVerifySummary;
        private Button _btnSaveVerifyAs;
        private Button _btnOpenVerifyFile;

        // View 2: Safety & About
        private TextBlock _lblSafetyViewTitle;
        private TextBlock _lblSafetyViewSubtitle;
        private TextBlock _lblSafetyCard1Title;
        private TextBlock _lblSafetyCard1Body;
        private TextBlock _lblSafetyCard2Title;
        private TextBlock _lblSafetyCard2Body;
        private TextBlock _lblSafetyCard3Title;
        private TextBlock _lblSafetyCard3Body;
        private TextBlock _lblSafetyCard4Title;
        private TextBlock _lblSafetyCard4Body;
        private Button _btnBackToWorkspace;

        private TextBlock _lblStatusBar;
        private TextBlock _lblFooterBoundary;

        private static Brush CreateBrush(byte r, byte g, byte b)
        {
            var br = new SolidColorBrush(Color.FromRgb(r, g, b));
            br.Freeze();
            return br;
        }

        public MainWindow(string initialLanguage, string toolkitRootOverride, bool dryRun)
            : this(initialLanguage, toolkitRootOverride, dryRun, false, 0)
        {
        }

        public MainWindow(string initialLanguage, string toolkitRootOverride, bool dryRun, bool demoAudit, int initialNavIndex)
        {
            _lang = string.IsNullOrEmpty(initialLanguage)
                ? Localization.DetectDefaultLanguage()
                : initialLanguage;
            _dryRun = dryRun;
            _demoAudit = demoAudit;
            _isElevated = IsProcessElevated();
            _activeNavIndex = (initialNavIndex >= 0 && initialNavIndex <= 2) ? initialNavIndex : 0;
            _logsExpanded = demoAudit;
            _toolkitRoot = ResolveToolkitRoot(toolkitRootOverride);

            Width = 1360;
            Height = 920;
            MinWidth = 1040;
            MinHeight = 760;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = BrushBgOuter;
            Foreground = BrushTextPrimary;
            FontFamily = new FontFamily("Microsoft YaHei UI, Segoe UI");
            FontSize = 12.5;
            UseLayoutRounding = true;
            SnapsToDevicePixels = true;
            TextOptions.SetTextFormattingMode(this, TextFormattingMode.Display);
            TextOptions.SetTextRenderingMode(this, TextRenderingMode.Grayscale);

            LoadEmbeddedWindowIcon();
            ApplyDarkResources();
            BuildLayout();
            SizeChanged += OnMainWindowSizeChanged;
            if (_demoAudit)
            {
                PopulateDemoAuditData();
            }
            ApplyLanguage(_lang);
            SelectNavTab(_activeNavIndex);
            UpdateLogDrawerVisibility();
            UpdateMetricCards();
            UpdateAccountIdCard();
            AppendLog("Toolkit root: " + (string.IsNullOrEmpty(_toolkitRoot) ? "<not resolved>" : _toolkitRoot));
        }

        private static bool IsProcessElevated()
        {
            try
            {
                using (WindowsIdentity id = WindowsIdentity.GetCurrent())
                {
                    if (id == null) return false;
                    var principal = new WindowsPrincipal(id);
                    return principal.IsInRole(WindowsBuiltInRole.Administrator);
                }
            }
            catch
            {
                return false;
            }
        }

        private Stream OpenIconOrLogoStream(out bool isIcon)
        {
            isIcon = true;
            try
            {
                Stream resStream = Assembly.GetExecutingAssembly().GetManifestResourceStream("ClaudeResidualIdCleaner.app.ico");
                if (resStream != null) return resStream;
            }
            catch { }

            if (!string.IsNullOrEmpty(_toolkitRoot))
            {
                string diskIco = Path.Combine(_toolkitRoot, @"src\Gui\app.ico");
                if (File.Exists(diskIco))
                {
                    return File.OpenRead(diskIco);
                }
                string diskLogo = Path.Combine(_toolkitRoot, @"docs\images\logo.png");
                if (File.Exists(diskLogo))
                {
                    isIcon = false;
                    return File.OpenRead(diskLogo);
                }
            }
            return null;
        }

        private void LoadEmbeddedWindowIcon()
        {
            try
            {
                bool isIcon;
                using (Stream st = OpenIconOrLogoStream(out isIcon))
                {
                    if (st == null) return;
                    if (isIcon)
                    {
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
                            Icon = best;
                            _hasWindowIcon = true;
                        }
                    }
                    else
                    {
                        var bmp = new BitmapImage();
                        bmp.BeginInit();
                        bmp.CacheOption = BitmapCacheOption.OnLoad;
                        bmp.StreamSource = st;
                        bmp.EndInit();
                        bmp.Freeze();
                        Icon = bmp;
                        _hasWindowIcon = true;
                    }
                }
            }
            catch
            {
                _hasWindowIcon = false;
            }
        }

        private ImageSource LoadMascotImageSource()
        {
            if (Icon != null)
            {
                return Icon;
            }
            return null;
        }

        private void OnMainWindowSizeChanged(object sender, SizeChangedEventArgs e)
        {
            if (_logDrawerRow != null && _logsExpanded)
            {
                double maxAllowed = Math.Max(110.0, Math.Floor(ActualHeight * 0.60));
                _logDrawerRow.MaxHeight = maxAllowed;
            }
        }

        private void ApplyDarkResources()
        {
            string xaml =
@"<ResourceDictionary xmlns=""http://schemas.microsoft.com/winfx/2006/xaml/presentation""
                    xmlns:x=""http://schemas.microsoft.com/winfx/2006/xaml"">
    <Style TargetType=""ToolTip"">
        <Setter Property=""Background"" Value=""#181A1F""/>
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""BorderBrush"" Value=""#323842""/>
        <Setter Property=""BorderThickness"" Value=""1""/>
        <Setter Property=""Padding"" Value=""8,5""/>
    </Style>

    <Style TargetType=""Button"">
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""Background"" Value=""#282C34""/>
        <Setter Property=""BorderBrush"" Value=""#323842""/>
        <Setter Property=""BorderThickness"" Value=""1""/>
        <Setter Property=""Padding"" Value=""12,6""/>
        <Setter Property=""Cursor"" Value=""Hand""/>
        <Setter Property=""SnapsToDevicePixels"" Value=""True""/>
        <Setter Property=""Template"">
            <Setter.Value>
                <ControlTemplate TargetType=""Button"">
                    <Border x:Name=""Bd""
                            Background=""{TemplateBinding Background}""
                            BorderBrush=""{TemplateBinding BorderBrush}""
                            BorderThickness=""{TemplateBinding BorderThickness}""
                            CornerRadius=""6"">
                        <Grid>
                            <Border x:Name=""HoverOverlay"" Background=""#16FFFFFF"" CornerRadius=""6"" Opacity=""0"" IsHitTestVisible=""False""/>
                            <ContentPresenter x:Name=""Cp""
                                              Margin=""{TemplateBinding Padding}""
                                              HorizontalAlignment=""{TemplateBinding HorizontalContentAlignment}""
                                              VerticalAlignment=""{TemplateBinding VerticalContentAlignment}""
                                              RecognizesAccessKey=""False""/>
                        </Grid>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property=""IsMouseOver"" Value=""True"">
                            <Setter TargetName=""HoverOverlay"" Property=""Opacity"" Value=""1""/>
                        </Trigger>
                        <Trigger Property=""IsPressed"" Value=""True"">
                            <Setter TargetName=""HoverOverlay"" Property=""Background"" Value=""#26000000""/>
                            <Setter TargetName=""HoverOverlay"" Property=""Opacity"" Value=""1""/>
                        </Trigger>
                        <Trigger Property=""IsEnabled"" Value=""False"">
                            <Setter TargetName=""Bd"" Property=""Background"" Value=""#21252B""/>
                            <Setter TargetName=""Bd"" Property=""BorderBrush"" Value=""#323842""/>
                            <Setter TargetName=""Cp"" Property=""Opacity"" Value=""0.45""/>
                            <Setter Property=""Foreground"" Value=""#6B7280""/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <Style TargetType=""CheckBox"">
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""Cursor"" Value=""Hand""/>
        <Setter Property=""SnapsToDevicePixels"" Value=""True""/>
        <Setter Property=""Template"">
            <Setter.Value>
                <ControlTemplate TargetType=""CheckBox"">
                    <Grid Background=""Transparent"">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width=""Auto""/>
                            <ColumnDefinition Width=""*""/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name=""Box""
                                Grid.Column=""0""
                                Width=""16"" Height=""16""
                                CornerRadius=""4""
                                Background=""#181A1F""
                                BorderBrush=""#4B5563""
                                BorderThickness=""1""
                                VerticalAlignment=""Center"">
                            <Path x:Name=""CheckMark""
                                  Data=""M 3,8 L 6.5,11.5 L 12.5,4.5""
                                  Stroke=""#FFFFFF""
                                  StrokeThickness=""2""
                                  StrokeStartLineCap=""Round""
                                  StrokeEndLineCap=""Round""
                                  StrokeLineJoin=""Round""
                                  Visibility=""Collapsed""/>
                        </Border>
                        <ContentPresenter Grid.Column=""1""
                                          Margin=""8,0,0,0""
                                          VerticalAlignment=""Center""
                                          RecognizesAccessKey=""False""/>
                    </Grid>
                    <ControlTemplate.Triggers>
                        <Trigger Property=""IsChecked"" Value=""True"">
                            <Setter TargetName=""Box"" Property=""Background"" Value=""#3B82F6""/>
                            <Setter TargetName=""Box"" Property=""BorderBrush"" Value=""#60A5FA""/>
                            <Setter TargetName=""CheckMark"" Property=""Visibility"" Value=""Visible""/>
                        </Trigger>
                        <Trigger Property=""IsMouseOver"" Value=""True"">
                            <Setter TargetName=""Box"" Property=""BorderBrush"" Value=""#60A5FA""/>
                        </Trigger>
                        <Trigger Property=""IsEnabled"" Value=""False"">
                            <Setter TargetName=""Box"" Property=""Opacity"" Value=""0.45""/>
                            <Setter Property=""Foreground"" Value=""#6B7280""/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <Style TargetType=""RadioButton"">
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""Cursor"" Value=""Hand""/>
        <Setter Property=""SnapsToDevicePixels"" Value=""True""/>
        <Setter Property=""Template"">
            <Setter.Value>
                <ControlTemplate TargetType=""RadioButton"">
                    <Grid Background=""Transparent"">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width=""Auto""/>
                            <ColumnDefinition Width=""*""/>
                        </Grid.ColumnDefinitions>
                        <Border x:Name=""Circle""
                                Grid.Column=""0""
                                Width=""16"" Height=""16""
                                CornerRadius=""8""
                                Background=""#181A1F""
                                BorderBrush=""#4B5563""
                                BorderThickness=""1""
                                VerticalAlignment=""Top""
                                Margin=""0,2,0,0"">
                            <Ellipse x:Name=""Dot""
                                     Width=""8"" Height=""8""
                                     Fill=""#60A5FA""
                                     Visibility=""Collapsed""/>
                        </Border>
                        <ContentPresenter Grid.Column=""1""
                                          Margin=""8,0,0,0""
                                          VerticalAlignment=""Center""
                                          RecognizesAccessKey=""False""/>
                    </Grid>
                    <ControlTemplate.Triggers>
                        <Trigger Property=""IsChecked"" Value=""True"">
                            <Setter TargetName=""Circle"" Property=""BorderBrush"" Value=""#60A5FA""/>
                            <Setter TargetName=""Dot"" Property=""Visibility"" Value=""Visible""/>
                        </Trigger>
                        <Trigger Property=""IsMouseOver"" Value=""True"">
                            <Setter TargetName=""Circle"" Property=""BorderBrush"" Value=""#60A5FA""/>
                        </Trigger>
                        <Trigger Property=""IsEnabled"" Value=""False"">
                            <Setter TargetName=""Circle"" Property=""Opacity"" Value=""0.45""/>
                            <Setter Property=""Foreground"" Value=""#6B7280""/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <Style TargetType=""ScrollBar"">
        <Setter Property=""Background"" Value=""#181A1F""/>
        <Setter Property=""Width"" Value=""10""/>
        <Setter Property=""MinWidth"" Value=""10""/>
        <Setter Property=""Template"">
            <Setter.Value>
                <ControlTemplate TargetType=""ScrollBar"">
                    <Border Background=""{TemplateBinding Background}"" CornerRadius=""4"">
                        <Track x:Name=""PART_Track"" IsDirectionReversed=""True"">
                            <Track.Thumb>
                                <Thumb>
                                    <Thumb.Template>
                                        <ControlTemplate TargetType=""Thumb"">
                                            <Border x:Name=""ThumbBd"" Background=""#3A414D"" CornerRadius=""4"" Margin=""2""/>
                                            <ControlTemplate.Triggers>
                                                <Trigger Property=""IsMouseOver"" Value=""True"">
                                                    <Setter TargetName=""ThumbBd"" Property=""Background"" Value=""#60A5FA""/>
                                                </Trigger>
                                            </ControlTemplate.Triggers>
                                        </ControlTemplate>
                                    </Thumb.Template>
                                </Thumb>
                            </Track.Thumb>
                        </Track>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property=""Orientation"" Value=""Horizontal"">
                            <Setter Property=""Width"" Value=""Auto""/>
                            <Setter Property=""MinWidth"" Value=""0""/>
                            <Setter Property=""Height"" Value=""10""/>
                            <Setter Property=""MinHeight"" Value=""10""/>
                            <Setter TargetName=""PART_Track"" Property=""IsDirectionReversed"" Value=""False""/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <Style TargetType=""DataGridColumnHeader"">
        <Setter Property=""Background"" Value=""#1D2026""/>
        <Setter Property=""Foreground"" Value=""#9CA3AF""/>
        <Setter Property=""BorderBrush"" Value=""#323842""/>
        <Setter Property=""BorderThickness"" Value=""0,0,1,1""/>
        <Setter Property=""Padding"" Value=""10,7""/>
        <Setter Property=""FontWeight"" Value=""SemiBold""/>
        <Setter Property=""FontSize"" Value=""12""/>
        <Setter Property=""HorizontalContentAlignment"" Value=""Left""/>
    </Style>

    <Style TargetType=""DataGridRow"">
        <Setter Property=""Background"" Value=""#21252B""/>
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""BorderThickness"" Value=""0""/>
        <Setter Property=""MinHeight"" Value=""32""/>
        <Style.Triggers>
            <Trigger Property=""AlternationIndex"" Value=""1"">
                <Setter Property=""Background"" Value=""#242930""/>
            </Trigger>
            <Trigger Property=""IsMouseOver"" Value=""True"">
                <Setter Property=""Background"" Value=""#282C34""/>
            </Trigger>
            <Trigger Property=""IsSelected"" Value=""True"">
                <Setter Property=""Background"" Value=""#1E3A5F""/>
                <Setter Property=""Foreground"" Value=""#F3F4F6""/>
            </Trigger>
        </Style.Triggers>
    </Style>

    <Style TargetType=""DataGridCell"">
        <Setter Property=""BorderThickness"" Value=""0""/>
        <Setter Property=""Padding"" Value=""8,4""/>
        <Setter Property=""FocusVisualStyle"" Value=""{x:Null}""/>
        <Setter Property=""Template"">
            <Setter.Value>
                <ControlTemplate TargetType=""DataGridCell"">
                    <Border Padding=""{TemplateBinding Padding}"" Background=""{TemplateBinding Background}"">
                        <ContentPresenter VerticalAlignment=""Center""/>
                    </Border>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
        <Style.Triggers>
            <Trigger Property=""IsSelected"" Value=""True"">
                <Setter Property=""Background"" Value=""Transparent""/>
                <Setter Property=""Foreground"" Value=""#F3F4F6""/>
            </Trigger>
        </Style.Triggers>
    </Style>

    <Style TargetType=""DataGrid"">
        <Setter Property=""Background"" Value=""#21252B""/>
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""BorderThickness"" Value=""0""/>
        <Setter Property=""HorizontalGridLinesBrush"" Value=""#2C313A""/>
        <Setter Property=""VerticalGridLinesBrush"" Value=""#2C313A""/>
        <Setter Property=""AlternationCount"" Value=""2""/>
        <Setter Property=""RowHeaderWidth"" Value=""0""/>
    </Style>

    <DataTemplate x:Key=""StatusBadgeTemplate"">
        <Border Background=""{Binding StatusBg}""
                BorderBrush=""{Binding StatusBorder}""
                BorderThickness=""1""
                CornerRadius=""10""
                Padding=""9,2""
                HorizontalAlignment=""Left""
                ToolTip=""{Binding Status}"">
            <TextBlock Text=""{Binding Status}""
                       Foreground=""{Binding StatusFg}""
                       FontSize=""11.5""
                       FontWeight=""SemiBold""/>
        </Border>
    </DataTemplate>
</ResourceDictionary>";

            var dict = (ResourceDictionary)XamlReader.Parse(xaml);
            Resources.MergedDictionaries.Add(dict);
        }

        private static string ResolveToolkitRoot(string explicitRoot)
        {
            if (!string.IsNullOrEmpty(explicitRoot))
            {
                string full = Path.GetFullPath(explicitRoot);
                if (File.Exists(Path.Combine(full, "ClaudeCleanup.ps1")))
                {
                    return full;
                }
            }

            string baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            string[] candidates = new string[]
            {
                baseDir,
                Directory.GetParent(baseDir) != null ? Directory.GetParent(baseDir).FullName : string.Empty,
                Environment.CurrentDirectory
            };
            for (int i = 0; i < candidates.Length; i++)
            {
                string cand = candidates[i];
                if (string.IsNullOrEmpty(cand)) continue;
                try
                {
                    string full = Path.GetFullPath(cand);
                    if (File.Exists(Path.Combine(full, "ClaudeCleanup.ps1")))
                    {
                        return full;
                    }
                }
                catch
                {
                }
            }
            return string.Empty;
        }

        private void BuildLayout()
        {
            var rootShell = new Border
            {
                Background = BrushBgOuter,
                UseLayoutRounding = true,
                SnapsToDevicePixels = true
            };

            var shellGrid = new Grid();
            shellGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 0: Top Studio Header
            shellGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // 1: Sidebar + Canvas
            shellGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 2: Footer Status Bar

            var headerBorder = BuildStudioHeader();
            Grid.SetRow(headerBorder, 0);
            shellGrid.Children.Add(headerBorder);

            var bodyGrid = new Grid();
            bodyGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(220) });
            bodyGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var sidebar = BuildLeftSidebar();
            Grid.SetColumn(sidebar, 0);
            bodyGrid.Children.Add(sidebar);

            var canvasContainer = BuildMainCanvas();
            Grid.SetColumn(canvasContainer, 1);
            bodyGrid.Children.Add(canvasContainer);

            Grid.SetRow(bodyGrid, 1);
            shellGrid.Children.Add(bodyGrid);

            var footerBorder = BuildFooterBar();
            Grid.SetRow(footerBorder, 2);
            shellGrid.Children.Add(footerBorder);

            rootShell.Child = shellGrid;
            Content = rootShell;
        }

        private Border BuildStudioHeader()
        {
            var headerBorder = new Border
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(0, 0, 0, 1),
                Padding = new Thickness(16, 10, 16, 10)
            };

            var headerGrid = new Grid();
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var leftDock = new Grid { VerticalAlignment = VerticalAlignment.Center };
            leftDock.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            leftDock.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var appMark = new Border
            {
                Width = 42,
                Height = 42,
                CornerRadius = new CornerRadius(9),
                Background = BrushBgCard,
                BorderBrush = BrushAccentBright,
                BorderThickness = new Thickness(1),
                Margin = new Thickness(0, 0, 12, 0),
                VerticalAlignment = VerticalAlignment.Center,
                ClipToBounds = true
            };
            ImageSource mascotImg = LoadMascotImageSource();
            if (mascotImg != null)
            {
                var logoImage = new Image
                {
                    Source = mascotImg,
                    Width = 40,
                    Height = 40,
                    Stretch = Stretch.Uniform,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center
                };
                RenderOptions.SetBitmapScalingMode(logoImage, BitmapScalingMode.HighQuality);
                appMark.Child = logoImage;
            }
            else
            {
                appMark.Background = BrushAccent;
                var markGrid = new Grid();
                var shieldPath = new System.Windows.Shapes.Path
                {
                    Data = Geometry.Parse("M 12,3 L 20,6.5 L 20,12.5 C 20,17.2 16.6,20.8 12,22.2 C 7.4,20.8 4,17.2 4,12.5 L 4,6.5 Z"),
                    Stroke = Brushes.White,
                    StrokeThickness = 1.8,
                    Fill = new SolidColorBrush(Color.FromArgb(40, 255, 255, 255)),
                    Width = 22,
                    Height = 22,
                    Stretch = Stretch.Uniform,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center
                };
                var checkMark = new System.Windows.Shapes.Path
                {
                    Data = Geometry.Parse("M 8.5,12.5 L 11,15 L 16,9.5"),
                    Stroke = BrushSafetyFg,
                    StrokeThickness = 2.0,
                    StrokeStartLineCap = PenLineCap.Round,
                    StrokeEndLineCap = PenLineCap.Round,
                    StrokeLineJoin = PenLineJoin.Round,
                    Width = 22,
                    Height = 22,
                    Stretch = Stretch.Uniform,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center
                };
                markGrid.Children.Add(shieldPath);
                markGrid.Children.Add(checkMark);
                appMark.Child = markGrid;
            }
            Grid.SetColumn(appMark, 0);
            leftDock.Children.Add(appMark);

            var titleStack = new StackPanel { Orientation = Orientation.Vertical, VerticalAlignment = VerticalAlignment.Center };
            var titleRow = new WrapPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };

            _brandPill = new Border
            {
                Background = BrushBgElevated,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(5),
                Padding = new Thickness(7, 2, 7, 2),
                Margin = new Thickness(0, 2, 9, 2),
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblBrandName = new TextBlock
            {
                Foreground = BrushAccentBright,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold
            };
            _brandPill.Child = _lblBrandName;

            _lblHeaderTitle = new TextBlock
            {
                Foreground = BrushTextPrimary,
                FontSize = 16.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 1, 0, 1),
                VerticalAlignment = VerticalAlignment.Center
            };

            var versionBorder = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(5),
                Padding = new Thickness(8, 2, 8, 2),
                Margin = new Thickness(9, 2, 8, 2),
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblVersionBadge = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11
            };
            versionBorder.Child = _lblVersionBadge;

            var safetyBorder = new Border
            {
                Background = BrushSafetyBg,
                BorderBrush = BrushSafetyBorder,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(11),
                Padding = new Thickness(10, 2, 10, 2),
                Margin = new Thickness(0, 2, 8, 2),
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblSafetyPill = new TextBlock
            {
                Foreground = BrushSafetyFg,
                FontSize = 11,
                FontWeight = FontWeights.Bold
            };
            safetyBorder.Child = _lblSafetyPill;

            _privilegeBadgeBorder = new Border
            {
                Background = _isElevated ? BrushBadgeReadyBg : BrushBgCard,
                BorderBrush = _isElevated ? BrushBadgeReadyBorder : BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(11),
                Padding = new Thickness(9, 2, 9, 2),
                Margin = new Thickness(0, 2, 0, 2),
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblPrivilegeBadge = new TextBlock
            {
                Foreground = _isElevated ? BrushBadgeReadyFg : BrushTextSecondary,
                FontSize = 11,
                FontWeight = FontWeights.SemiBold
            };
            _privilegeBadgeBorder.Child = _lblPrivilegeBadge;

            titleRow.Children.Add(_brandPill);
            titleRow.Children.Add(_lblHeaderTitle);
            titleRow.Children.Add(versionBorder);
            titleRow.Children.Add(safetyBorder);
            titleRow.Children.Add(_privilegeBadgeBorder);

            _lblPositioning = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                Margin = new Thickness(0, 3, 0, 0),
                TextWrapping = TextWrapping.Wrap
            };

            titleStack.Children.Add(titleRow);
            titleStack.Children.Add(_lblPositioning);
            Grid.SetColumn(titleStack, 1);
            leftDock.Children.Add(titleStack);

            var rightControls = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(12, 0, 0, 0)
            };

            _btnRestartAdmin = new Button
            {
                Background = BrushBgCard,
                BorderBrush = BrushBadgeReadyBorder,
                BorderThickness = new Thickness(1),
                Foreground = BrushBadgeReadyFg,
                FontSize = 11.5,
                FontWeight = FontWeights.SemiBold,
                Padding = new Thickness(10, 5, 10, 5),
                Margin = new Thickness(0, 0, 8, 0),
                Visibility = _isElevated ? Visibility.Collapsed : Visibility.Visible
            };
            _btnRestartAdmin.Click += OnRestartAsAdminClick;

            _btnPolicyPill = new Button
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                Foreground = BrushTextPrimary,
                FontSize = 11.5,
                FontWeight = FontWeights.SemiBold,
                Padding = new Thickness(10, 5, 10, 5),
                Margin = new Thickness(0, 0, 8, 0)
            };
            _btnPolicyPill.Click += OnPolicyPillClick;

            _btnLangToggle = new Button
            {
                Background = BrushAccent,
                BorderBrush = BrushAccentBright,
                BorderThickness = new Thickness(1),
                Foreground = Brushes.White,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Padding = new Thickness(13, 5, 13, 5),
                Margin = new Thickness(0, 0, 8, 0)
            };
            _btnLangToggle.Click += OnLangToggleClick;

            _btnAbout = new Button
            {
                Background = BrushBgElevated,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                Foreground = BrushTextPrimary,
                FontSize = 11.5,
                FontWeight = FontWeights.SemiBold,
                Padding = new Thickness(11, 5, 11, 5)
            };
            _btnAbout.Click += OnAboutClick;

            rightControls.Children.Add(_btnRestartAdmin);
            rightControls.Children.Add(_btnPolicyPill);
            rightControls.Children.Add(_btnLangToggle);
            rightControls.Children.Add(_btnAbout);

            Grid.SetColumn(leftDock, 0);
            Grid.SetColumn(rightControls, 1);
            headerGrid.Children.Add(leftDock);
            headerGrid.Children.Add(rightControls);
            headerBorder.Child = headerGrid;
            return headerBorder;
        }

        private Border BuildLeftSidebar()
        {
            var sidebarBorder = new Border
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(0, 0, 1, 0),
                Padding = new Thickness(10, 12, 10, 12)
            };

            var sideGrid = new Grid();
            sideGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            sideGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            sideGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            _lblSidebarSection = new TextBlock
            {
                Foreground = BrushTextMuted,
                FontSize = 11,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(8, 0, 8, 10)
            };
            Grid.SetRow(_lblSidebarSection, 0);
            sideGrid.Children.Add(_lblSidebarSection);

            var navStack = new StackPanel { Orientation = Orientation.Vertical };
            _navButtons.Clear();
            _navIndicators.Clear();

            for (int i = 0; i < 3; i++)
            {
                int tabIndex = i;
                var rowGrid = new Grid { Margin = new Thickness(0, 0, 0, 6) };
                var indicator = new Border
                {
                    Width = 3,
                    CornerRadius = new CornerRadius(2),
                    Background = BrushAccentBright,
                    HorizontalAlignment = HorizontalAlignment.Left,
                    Margin = new Thickness(0, 7, 0, 7),
                    Visibility = Visibility.Collapsed
                };
                var navBtn = new Button
                {
                    HorizontalContentAlignment = HorizontalAlignment.Left,
                    Padding = new Thickness(14, 11, 10, 11),
                    Background = Brushes.Transparent,
                    BorderBrush = Brushes.Transparent,
                    BorderThickness = new Thickness(1),
                    Foreground = BrushTextSecondary,
                    FontSize = 13,
                    FontWeight = FontWeights.SemiBold
                };
                navBtn.Click += delegate { SelectNavTab(tabIndex); };

                rowGrid.Children.Add(navBtn);
                rowGrid.Children.Add(indicator);

                _navButtons.Add(navBtn);
                _navIndicators.Add(indicator);
                navStack.Children.Add(rowGrid);
            }

            Grid.SetRow(navStack, 1);
            sideGrid.Children.Add(navStack);

            var guardCard = new Border
            {
                Background = BrushBgOuter,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(11, 10, 11, 10)
            };
            var guardStack = new StackPanel();
            var guardTitleRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 5) };
            var greenDot = new System.Windows.Shapes.Ellipse
            {
                Width = 8,
                Height = 8,
                Fill = BrushSafetyBorder,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 7, 0)
            };
            _lblSidebarGuardTitle = new TextBlock
            {
                Foreground = BrushSafetyFg,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                VerticalAlignment = VerticalAlignment.Center
            };
            guardTitleRow.Children.Add(greenDot);
            guardTitleRow.Children.Add(_lblSidebarGuardTitle);

            _lblSidebarGuardBody = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11,
                TextWrapping = TextWrapping.Wrap,
                LineHeight = 16
            };
            guardStack.Children.Add(guardTitleRow);
            guardStack.Children.Add(_lblSidebarGuardBody);
            guardCard.Child = guardStack;

            Grid.SetRow(guardCard, 2);
            sideGrid.Children.Add(guardCard);

            sidebarBorder.Child = sideGrid;
            return sidebarBorder;
        }

        private Grid BuildMainCanvas()
        {
            var canvasGrid = new Grid { Margin = new Thickness(14, 8, 14, 8) };
            canvasGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            canvasGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            _contextBannerBorder = new Border
            {
                Background = _demoAudit ? BrushDemoBannerBg : BrushBgChrome,
                BorderBrush = _demoAudit ? BrushDemoBannerBorder : BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(11, 5, 11, 5),
                Margin = new Thickness(0, 0, 0, 7)
            };
            _lblContextBanner = new TextBlock
            {
                Foreground = _demoAudit ? BrushBadgeReadOnlyFg : BrushTextSecondary,
                FontSize = 11.5,
                TextWrapping = TextWrapping.Wrap
            };
            _contextBannerBorder.Child = _lblContextBanner;
            Grid.SetRow(_contextBannerBorder, 0);
            canvasGrid.Children.Add(_contextBannerBorder);

            // View 0: Scan & Clean Workspace
            _workspacePanel = BuildWorkspacePanel();
            Grid.SetRow(_workspacePanel, 1);
            canvasGrid.Children.Add(_workspacePanel);

            // View 1: Reports & Export
            _reportsPanel = BuildReportsExportPanel();
            _reportsPanel.Visibility = Visibility.Collapsed;
            Grid.SetRow(_reportsPanel, 1);
            canvasGrid.Children.Add(_reportsPanel);

            // View 2: Safety & About
            _aboutPanel = BuildSafetyAboutPanel();
            _aboutPanel.Visibility = Visibility.Collapsed;
            Grid.SetRow(_aboutPanel, 1);
            canvasGrid.Children.Add(_aboutPanel);

            return canvasGrid;
        }

        private Grid BuildWorkspacePanel()
        {
            var wsGrid = new Grid();
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 0: Metrics + Account ID + Scope/Policy
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 1: 4-step Workflow Toolbar + Presets
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 2: Real-Time Cleaning Progress & Completion Summary Banners
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star), MinHeight = 160 }); // 3: DataGrid
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 4: Horizontal GridSplitter
            _logDrawerRow = new RowDefinition { Height = new GridLength(108), MinHeight = 80, MaxHeight = 520 };
            wsGrid.RowDefinitions.Add(_logDrawerRow); // 5: Resizable Log Drawer

            // Row 0: Metrics + Account ID Card + Scope & Policy
            var topSection = new StackPanel { Orientation = Orientation.Vertical };

            var metricsGrid = new Grid { Margin = new Thickness(0, 0, 0, 7) };
            for (int c = 0; c < 4; c++)
            {
                metricsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                if (c < 3)
                {
                    metricsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
                }
            }
            _metricCards.Clear();

            var card1 = CreateMetricCard(out _lblMetricScannedTitle, out _lblMetricScannedValue, out _lblMetricScannedSub, BrushAccentBright);
            Grid.SetColumn(card1, 0);
            metricsGrid.Children.Add(card1);
            _metricCards.Add(card1);

            var card2 = CreateMetricCard(out _lblMetricFoundTitle, out _lblMetricFoundValue, out _lblMetricFoundSub, BrushBadgeReadyFg);
            Grid.SetColumn(card2, 2);
            metricsGrid.Children.Add(card2);
            _metricCards.Add(card2);

            var card3 = CreateMetricCard(out _lblMetricSizeTitle, out _lblMetricSizeValue, out _lblMetricSizeSub, BrushTextPrimary);
            Grid.SetColumn(card3, 4);
            metricsGrid.Children.Add(card3);
            _metricCards.Add(card3);

            var card4 = CreateMetricCard(out _lblMetricSafetyTitle, out _lblMetricSafetyValue, out _lblMetricSafetySub, BrushSafetyFg);
            card4.Background = BrushSafetyBg;
            card4.BorderBrush = BrushSafetyBorder;
            Grid.SetColumn(card4, 6);
            metricsGrid.Children.Add(card4);
            _metricCards.Add(card4);

            topSection.Children.Add(metricsGrid);

            _accountIdCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(11, 6, 11, 6),
                Margin = new Thickness(0, 0, 0, 7)
            };
            var aidGrid = new Grid();
            aidGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            aidGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var aidLeft = new StackPanel { Orientation = Orientation.Vertical };
            var aidHeaderRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 3) };
            _lblAccountIdCardTitle = new TextBlock
            {
                Foreground = BrushAccentBright,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblAccountIdCardSub = new TextBlock
            {
                Foreground = BrushTextMuted,
                FontSize = 11,
                Margin = new Thickness(10, 0, 0, 0),
                VerticalAlignment = VerticalAlignment.Center,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            aidHeaderRow.Children.Add(_lblAccountIdCardTitle);
            aidHeaderRow.Children.Add(_lblAccountIdCardSub);

            _txtAccountIdValue = new TextBox
            {
                IsReadOnly = true,
                BorderThickness = new Thickness(0),
                Background = Brushes.Transparent,
                Foreground = BrushTextPrimary,
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11.5,
                TextWrapping = TextWrapping.Wrap,
                Padding = new Thickness(0)
            };

            aidLeft.Children.Add(aidHeaderRow);
            aidLeft.Children.Add(_txtAccountIdValue);

            _btnCopyAccountId = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnCopyAccountId.Margin = new Thickness(10, 0, 0, 0);
            _btnCopyAccountId.Padding = new Thickness(11, 5, 11, 5);
            _btnCopyAccountId.VerticalAlignment = VerticalAlignment.Center;
            _btnCopyAccountId.IsEnabled = false;
            _btnCopyAccountId.Click += OnCopyAccountIdClick;

            Grid.SetColumn(aidLeft, 0);
            Grid.SetColumn(_btnCopyAccountId, 1);
            aidGrid.Children.Add(aidLeft);
            aidGrid.Children.Add(_btnCopyAccountId);
            _accountIdCard.Child = aidGrid;
            topSection.Children.Add(_accountIdCard);

            var topCards = new Grid { Margin = new Thickness(0, 0, 0, 7) };
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.65, GridUnitType.Star) });
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(8) });
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.0, GridUnitType.Star) });

            var scopeCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(11, 6, 11, 6)
            };
            var scopeStack = new StackPanel();
            _lblScopeHeader = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 0, 0, 4)
            };
            scopeStack.Children.Add(_lblScopeHeader);

            _scopeCheckboxes.Clear();
            _chkCli = CreateScopeCheckbox();
            _chkDesktop = CreateScopeCheckbox();
            _chkVsCode = CreateScopeCheckbox();
            _chkCred = CreateScopeCheckbox();
            _chkEnv = CreateScopeCheckbox();
            scopeStack.Children.Add(_chkCli);
            scopeStack.Children.Add(_chkDesktop);
            scopeStack.Children.Add(_chkVsCode);
            scopeStack.Children.Add(_chkCred);
            scopeStack.Children.Add(_chkEnv);
            scopeCard.Child = scopeStack;
            Grid.SetColumn(scopeCard, 0);
            topCards.Children.Add(scopeCard);

            var policyCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(11, 6, 11, 6)
            };
            var policyStack = new StackPanel();
            _lblPolicyHeader = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 0, 0, 5)
            };
            policyStack.Children.Add(_lblPolicyHeader);

            _lblPolicyAccountText = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = BrushTextPrimary, FontSize = 11.5 };
            _rbAccountData = new RadioButton { IsChecked = true, Content = _lblPolicyAccountText, Margin = new Thickness(0, 1, 0, 6) };
            _rbAccountData.Checked += OnPolicyRadioChanged;

            _lblPolicyFullText = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = BrushTextPrimary, FontSize = 11.5 };
            _rbFullRemoval = new RadioButton { IsChecked = false, Content = _lblPolicyFullText, Margin = new Thickness(0, 1, 0, 1) };
            _rbFullRemoval.Checked += OnPolicyRadioChanged;

            policyStack.Children.Add(_rbAccountData);
            policyStack.Children.Add(_rbFullRemoval);
            policyCard.Child = policyStack;
            Grid.SetColumn(policyCard, 2);
            topCards.Children.Add(policyCard);

            topSection.Children.Add(topCards);
            Grid.SetRow(topSection, 0);
            wsGrid.Children.Add(topSection);

            // Row 1: 4-Step Workflow Toolbar + Quick Presets + Plan Gate Pill
            var toolbarBorder = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(10, 6, 10, 6),
                Margin = new Thickness(0, 0, 0, 7)
            };
            var toolbarStack = new StackPanel { Orientation = Orientation.Vertical };

            var toolbarGrid = new Grid();
            toolbarGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            toolbarGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var mainActions = new WrapPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            _btnScan = CreateActionButton(BrushAccent, BrushAccentBright, Brushes.White);
            _btnScan.Click += OnScanClick;

            _btnPlan = CreateActionButton(BrushTealAction, CreateBrush(20, 184, 166), Brushes.White);
            _btnPlan.Click += OnPlanClick;

            _btnClean = CreateActionButton(BrushDangerAction, CreateBrush(239, 68, 68), Brushes.White);
            _btnClean.IsEnabled = false;
            _btnClean.Click += OnCleanClick;

            _btnVerify = CreateActionButton(BrushNeutralAction, BrushBorderSubtle, BrushTextPrimary);
            _btnVerify.Click += OnVerifyClick;

            mainActions.Children.Add(_btnScan);
            mainActions.Children.Add(_btnPlan);
            mainActions.Children.Add(_btnClean);
            mainActions.Children.Add(_btnVerify);

            var utilActions = new WrapPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            _btnOpenFolder = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnOpenFolder.Click += OnOpenFolderClick;

            _btnExportSummary = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnExportSummary.Click += OnExportSummaryClick;

            _btnToggleLogs = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextSecondary);
            _btnToggleLogs.Click += OnToggleLogsClick;

            utilActions.Children.Add(_btnOpenFolder);
            utilActions.Children.Add(_btnExportSummary);
            utilActions.Children.Add(_btnToggleLogs);

            Grid.SetColumn(mainActions, 0);
            Grid.SetColumn(utilActions, 1);
            toolbarGrid.Children.Add(mainActions);
            toolbarGrid.Children.Add(utilActions);

            var presetGrid = new Grid { Margin = new Thickness(0, 4, 0, 0) };
            presetGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            presetGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var presetRow = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblPresetLabel = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.SemiBold,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(2, 0, 8, 0)
            };
            _btnPresetAccount = CreateActionButton(BrushSafetyBg, BrushSafetyBorder, BrushSafetyFg);
            _btnPresetAccount.Padding = new Thickness(10, 3, 10, 3);
            _btnPresetAccount.FontSize = 11.5;
            _btnPresetAccount.Click += OnPresetAccountClick;

            _btnPresetFull = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnPresetFull.Padding = new Thickness(10, 3, 10, 3);
            _btnPresetFull.FontSize = 11.5;
            _btnPresetFull.Click += OnPresetFullClick;

            presetRow.Children.Add(_lblPresetLabel);
            presetRow.Children.Add(_btnPresetAccount);
            presetRow.Children.Add(_btnPresetFull);

            _planGatePillBorder = new Border
            {
                Background = BrushBgLog,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(10, 2, 10, 2),
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblPlanGatePill = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11,
                FontWeight = FontWeights.SemiBold
            };
            _planGatePillBorder.Child = _lblPlanGatePill;

            Grid.SetColumn(presetRow, 0);
            Grid.SetColumn(_planGatePillBorder, 1);
            presetGrid.Children.Add(presetRow);
            presetGrid.Children.Add(_planGatePillBorder);

            toolbarStack.Children.Add(toolbarGrid);
            toolbarStack.Children.Add(presetGrid);
            toolbarBorder.Child = toolbarStack;
            Grid.SetRow(toolbarBorder, 1);
            wsGrid.Children.Add(toolbarBorder);

            // Row 2: Real-Time Cleaning Progress Panel + Post-Verify Completion Summary Banner
            var bannerHost = new StackPanel { Orientation = Orientation.Vertical };

            _cleaningProgressCard = new Border
            {
                Background = BrushDemoBannerBg,
                BorderBrush = BrushAccentBright,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(12, 8, 12, 8),
                Margin = new Thickness(0, 0, 0, 7),
                Visibility = Visibility.Collapsed
            };
            var progStack = new StackPanel { Orientation = Orientation.Vertical };
            var progHeaderGrid = new Grid { Margin = new Thickness(0, 0, 0, 5) };
            progHeaderGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            progHeaderGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            _lblCleanProgressTitle = new TextBlock
            {
                Foreground = BrushAccentBright,
                FontSize = 12,
                FontWeight = FontWeights.Bold,
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblCleanProgressPercent = new TextBlock
            {
                Foreground = BrushTextPrimary,
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(_lblCleanProgressTitle, 0);
            Grid.SetColumn(_lblCleanProgressPercent, 1);
            progHeaderGrid.Children.Add(_lblCleanProgressTitle);
            progHeaderGrid.Children.Add(_lblCleanProgressPercent);

            _lblCleanProgressBanner = new TextBlock
            {
                Foreground = BrushTextPrimary,
                FontSize = 12,
                TextTrimming = TextTrimming.CharacterEllipsis,
                Margin = new Thickness(0, 0, 0, 6)
            };

            _cleanProgressBar = new ProgressBar
            {
                Height = 9,
                Minimum = 0,
                Maximum = 100,
                Value = 0,
                Background = BrushBgLog,
                Foreground = BrushAccentBright,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1)
            };

            progStack.Children.Add(progHeaderGrid);
            progStack.Children.Add(_lblCleanProgressBanner);
            progStack.Children.Add(_cleanProgressBar);
            _cleaningProgressCard.Child = progStack;

            _completionSummaryBanner = new Border
            {
                Background = BrushSafetyBg,
                BorderBrush = BrushSafetyBorder,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(12, 8, 12, 8),
                Margin = new Thickness(0, 0, 0, 7),
                Visibility = Visibility.Collapsed
            };
            var compGrid = new Grid();
            compGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            compGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var compStack = new StackPanel { Orientation = Orientation.Vertical, VerticalAlignment = VerticalAlignment.Center };
            _lblCompletionTitle = new TextBlock
            {
                Foreground = BrushSafetyFg,
                FontSize = 13,
                FontWeight = FontWeights.Bold,
                TextWrapping = TextWrapping.Wrap
            };
            _lblCompletionSub = new TextBlock
            {
                Foreground = BrushTextPrimary,
                FontSize = 11.5,
                Margin = new Thickness(0, 3, 0, 0),
                TextWrapping = TextWrapping.Wrap
            };
            compStack.Children.Add(_lblCompletionTitle);
            compStack.Children.Add(_lblCompletionSub);

            _btnCompletionViewReports = CreateActionButton(BrushSafetyAction, BrushSafetyBorder, Brushes.White);
            _btnCompletionViewReports.VerticalAlignment = VerticalAlignment.Center;
            _btnCompletionViewReports.Margin = new Thickness(12, 0, 0, 0);
            _btnCompletionViewReports.Click += delegate { SelectNavTab(1); };

            Grid.SetColumn(compStack, 0);
            Grid.SetColumn(_btnCompletionViewReports, 1);
            compGrid.Children.Add(compStack);
            compGrid.Children.Add(_btnCompletionViewReports);
            _completionSummaryBanner.Child = compGrid;

            bannerHost.Children.Add(_cleaningProgressCard);
            bannerHost.Children.Add(_completionSummaryBanner);
            Grid.SetRow(bannerHost, 2);
            wsGrid.Children.Add(bannerHost);

            // Row 3: Styled Horizontal-Scrollable Multi-Column DataGrid
            var gridContainer = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(1),
                ClipToBounds = true
            };
            var gridOverlayContainer = new Grid();

            _gridResults = new DataGrid
            {
                AutoGenerateColumns = false,
                CanUserAddRows = false,
                CanUserDeleteRows = false,
                CanUserResizeColumns = true,
                IsReadOnly = false,
                HeadersVisibility = DataGridHeadersVisibility.Column,
                GridLinesVisibility = DataGridGridLinesVisibility.Horizontal,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                ItemsSource = _visibleRows
            };

            _chkSelectAll = new CheckBox
            {
                IsChecked = false,
                VerticalAlignment = VerticalAlignment.Center,
                FontSize = 12,
                FontWeight = FontWeights.SemiBold,
                Foreground = BrushTextSecondary
            };
            _chkSelectAll.Click += OnSelectAllHeaderClick;

            var selectBinding = new Binding("Selected") { UpdateSourceTrigger = UpdateSourceTrigger.PropertyChanged };
            _colSelect = new DataGridCheckBoxColumn { Binding = selectBinding, Header = _chkSelectAll, Width = 114, MinWidth = 108 };

            _colCategory = new DataGridTextColumn
            {
                Binding = new Binding("Category"),
                IsReadOnly = true,
                Width = 155,
                MinWidth = 140,
                ElementStyle = CreateCellTextStyle("Category")
            };
            _colPath = new DataGridTextColumn
            {
                Binding = new Binding("PathOrPackage"),
                IsReadOnly = true,
                Width = 480,
                MinWidth = 360,
                ElementStyle = CreateCellTextStyle("PathOrPackage")
            };
            _colStatus = new DataGridTemplateColumn
            {
                Width = 190,
                MinWidth = 175,
                IsReadOnly = true,
                CellTemplate = (DataTemplate)Resources["StatusBadgeTemplate"]
            };
            _colDetails = new DataGridTextColumn
            {
                Binding = new Binding("Details"),
                IsReadOnly = true,
                Width = 520,
                MinWidth = 420,
                ElementStyle = CreateCellTextStyle("Details")
            };

            _gridResults.Columns.Add(_colSelect);
            _gridResults.Columns.Add(_colCategory);
            _gridResults.Columns.Add(_colPath);
            _gridResults.Columns.Add(_colStatus);
            _gridResults.Columns.Add(_colDetails);

            _lblGridEmptyHint = new TextBlock
            {
                Foreground = BrushTextMuted,
                FontSize = 13,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                IsHitTestVisible = false,
                Margin = new Thickness(20, 40, 20, 20)
            };

            gridOverlayContainer.Children.Add(_gridResults);
            gridOverlayContainer.Children.Add(_lblGridEmptyHint);
            gridContainer.Child = gridOverlayContainer;
            Grid.SetRow(gridContainer, 3);
            wsGrid.Children.Add(gridContainer);

            // Row 4: Horizontal GridSplitter
            _logSplitter = new GridSplitter
            {
                Height = 6,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                VerticalAlignment = VerticalAlignment.Center,
                ResizeDirection = GridResizeDirection.Rows,
                ResizeBehavior = GridResizeBehavior.PreviousAndNext,
                Background = BrushBorderSubtle,
                Margin = new Thickness(0, 3, 0, 3),
                ShowsPreview = true,
                Cursor = Cursors.SizeNS
            };
            Grid.SetRow(_logSplitter, 4);
            wsGrid.Children.Add(_logSplitter);

            // Row 5: Resizable Live Log Drawer
            _logDrawerPanel = new Border
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Margin = new Thickness(0, 1, 0, 0),
                Padding = new Thickness(9, 7, 9, 7)
            };
            var logGrid = new Grid();
            logGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            logGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            _lblLogDrawerTitle = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(2, 0, 0, 5)
            };
            Grid.SetRow(_lblLogDrawerTitle, 0);
            logGrid.Children.Add(_lblLogDrawerTitle);

            _txtLog = new TextBox
            {
                IsReadOnly = true,
                AcceptsReturn = true,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                Background = BrushBgLog,
                Foreground = BrushTextPrimary,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(8, 5, 8, 5),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11.5
            };
            Grid.SetRow(_txtLog, 1);
            logGrid.Children.Add(_txtLog);
            _logDrawerPanel.Child = logGrid;

            Grid.SetRow(_logDrawerPanel, 5);
            wsGrid.Children.Add(_logDrawerPanel);

            return wsGrid;
        }

        private ScrollViewer BuildReportsExportPanel()
        {
            var scroll = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto
            };
            var outer = new StackPanel { Orientation = Orientation.Vertical };

            var headerGrid = new Grid { Margin = new Thickness(0, 0, 0, 12) };
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var titleStack = new StackPanel();
            _lblReportsViewTitle = new TextBlock
            {
                Foreground = BrushTextPrimary,
                FontSize = 18,
                FontWeight = FontWeights.Bold
            };
            _lblReportsViewSub = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 12,
                Margin = new Thickness(0, 4, 0, 0),
                TextWrapping = TextWrapping.Wrap
            };
            titleStack.Children.Add(_lblReportsViewTitle);
            titleStack.Children.Add(_lblReportsViewSub);

            var topActions = new WrapPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            _btnRefreshReports = CreateActionButton(BrushAccent, BrushAccentBright, Brushes.White);
            _btnRefreshReports.Click += delegate { RefreshReportsView(); };
            _btnReportsVerify = CreateActionButton(BrushTealAction, CreateBrush(20, 184, 166), Brushes.White);
            _btnReportsVerify.Click += OnVerifyClick;
            _btnReportsExportAudit = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnReportsExportAudit.Click += OnExportSummaryClick;
            _btnReportsOpenFolder = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnReportsOpenFolder.Click += OnOpenFolderClick;

            topActions.Children.Add(_btnRefreshReports);
            topActions.Children.Add(_btnReportsVerify);
            topActions.Children.Add(_btnReportsExportAudit);
            topActions.Children.Add(_btnReportsOpenFolder);

            Grid.SetColumn(titleStack, 0);
            Grid.SetColumn(topActions, 1);
            headerGrid.Children.Add(titleStack);
            headerGrid.Children.Add(topActions);
            outer.Children.Add(headerGrid);

            outer.Children.Add(CreateReportSummaryCard(
                BrushAccentBright,
                out _lblReportAuditTitle,
                out _lblReportAuditMeta,
                out _txtReportAuditSummary,
                out _btnSaveAuditAs,
                out _btnOpenAuditFile,
                OnExportSummaryClick,
                delegate { OpenWorkspaceReportFile("AUDIT.md"); }));

            outer.Children.Add(CreateReportSummaryCard(
                BrushBadgeReadyFg,
                out _lblReportPlanTitle,
                out _lblReportPlanMeta,
                out _txtReportPlanSummary,
                out _btnSavePlanAs,
                out _btnOpenPlanFile,
                delegate { ExportExistingMarkdownReport("CLEANUP-PLAN.md"); },
                delegate { OpenWorkspaceReportFile("CLEANUP-PLAN.md"); }));

            outer.Children.Add(CreateReportSummaryCard(
                BrushSafetyFg,
                out _lblReportVerifyTitle,
                out _lblReportVerifyMeta,
                out _txtReportVerifySummary,
                out _btnSaveVerifyAs,
                out _btnOpenVerifyFile,
                delegate { ExportExistingMarkdownReport("VERIFICATION.md"); },
                delegate { OpenWorkspaceReportFile("VERIFICATION.md"); }));

            scroll.Content = outer;
            return scroll;
        }

        private Border CreateReportSummaryCard(
            Brush accentBrush,
            out TextBlock titleBlock,
            out TextBlock metaBlock,
            out TextBox summaryBox,
            out Button saveAsBtn,
            out Button openBtn,
            RoutedEventHandler onSaveClick,
            RoutedEventHandler onOpenClick)
        {
            var card = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(14, 11, 14, 11),
                Margin = new Thickness(0, 0, 0, 12)
            };
            var stack = new StackPanel { Orientation = Orientation.Vertical };

            var topRow = new Grid { Margin = new Thickness(0, 0, 0, 8) };
            topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var leftMeta = new StackPanel();
            titleBlock = new TextBlock
            {
                Foreground = accentBrush,
                FontSize = 13.5,
                FontWeight = FontWeights.Bold
            };
            metaBlock = new TextBlock
            {
                Foreground = BrushTextMuted,
                FontSize = 11.5,
                Margin = new Thickness(0, 2, 0, 0)
            };
            leftMeta.Children.Add(titleBlock);
            leftMeta.Children.Add(metaBlock);

            var btnRow = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            saveAsBtn = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            saveAsBtn.Padding = new Thickness(11, 5, 11, 5);
            saveAsBtn.Click += onSaveClick;
            openBtn = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            openBtn.Padding = new Thickness(11, 5, 11, 5);
            openBtn.Click += onOpenClick;
            btnRow.Children.Add(saveAsBtn);
            btnRow.Children.Add(openBtn);

            Grid.SetColumn(leftMeta, 0);
            Grid.SetColumn(btnRow, 1);
            topRow.Children.Add(leftMeta);
            topRow.Children.Add(btnRow);

            summaryBox = new TextBox
            {
                IsReadOnly = true,
                AcceptsReturn = true,
                TextWrapping = TextWrapping.Wrap,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                MaxHeight = 145,
                Background = BrushBgLog,
                Foreground = BrushTextPrimary,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(9, 7, 9, 7),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11.5
            };

            stack.Children.Add(topRow);
            stack.Children.Add(summaryBox);
            card.Child = stack;
            return card;
        }

        private static Style CreateCellTextStyle(string propertyName)
        {
            var style = new Style(typeof(TextBlock));
            style.Setters.Add(new Setter(TextBlock.ToolTipProperty, new Binding(propertyName)));
            style.Setters.Add(new Setter(TextBlock.VerticalAlignmentProperty, VerticalAlignment.Center));
            return style;
        }

        private Border CreateMetricCard(out TextBlock lblTitle, out TextBlock lblValue, out TextBlock lblSub, Brush valueBrush)
        {
            var card = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(11, 6, 11, 6)
            };
            var stack = new StackPanel();
            lblTitle = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11,
                FontWeight = FontWeights.SemiBold
            };
            lblValue = new TextBlock
            {
                Foreground = valueBrush,
                FontSize = 19,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 2, 0, 2),
                Text = "0"
            };
            lblSub = new TextBlock
            {
                Foreground = BrushTextMuted,
                FontSize = 10.5,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            stack.Children.Add(lblTitle);
            stack.Children.Add(lblValue);
            stack.Children.Add(lblSub);
            card.Child = stack;
            return card;
        }

        private ScrollViewer BuildSafetyAboutPanel()
        {
            var scroll = new ScrollViewer
            {
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto
            };
            var outer = new StackPanel { Orientation = Orientation.Vertical };

            var headerStack = new StackPanel { Margin = new Thickness(0, 0, 0, 14) };
            _lblSafetyViewTitle = new TextBlock
            {
                Foreground = BrushTextPrimary,
                FontSize = 19,
                FontWeight = FontWeights.Bold
            };
            _lblSafetyViewSubtitle = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 12.5,
                Margin = new Thickness(0, 5, 0, 0),
                TextWrapping = TextWrapping.Wrap
            };
            headerStack.Children.Add(_lblSafetyViewTitle);
            headerStack.Children.Add(_lblSafetyViewSubtitle);
            outer.Children.Add(headerStack);

            var cardsGrid = new Grid { Margin = new Thickness(0, 0, 0, 16) };
            cardsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            cardsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(14) });
            cardsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            cardsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            cardsGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(14) });
            cardsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var c1 = CreateSafetyInfoCard(out _lblSafetyCard1Title, out _lblSafetyCard1Body, BrushAccentBright);
            Grid.SetRow(c1, 0);
            Grid.SetColumn(c1, 0);
            cardsGrid.Children.Add(c1);

            var c2 = CreateSafetyInfoCard(out _lblSafetyCard2Title, out _lblSafetyCard2Body, BrushSafetyFg);
            Grid.SetRow(c2, 0);
            Grid.SetColumn(c2, 2);
            cardsGrid.Children.Add(c2);

            var c3 = CreateSafetyInfoCard(out _lblSafetyCard3Title, out _lblSafetyCard3Body, BrushBadgeReadOnlyFg);
            Grid.SetRow(c3, 2);
            Grid.SetColumn(c3, 0);
            cardsGrid.Children.Add(c3);

            var c4 = CreateSafetyInfoCard(out _lblSafetyCard4Title, out _lblSafetyCard4Body, BrushTextPrimary);
            Grid.SetRow(c4, 2);
            Grid.SetColumn(c4, 2);
            cardsGrid.Children.Add(c4);

            outer.Children.Add(cardsGrid);

            _btnBackToWorkspace = CreateActionButton(BrushAccent, BrushAccentBright, Brushes.White);
            _btnBackToWorkspace.HorizontalAlignment = HorizontalAlignment.Left;
            _btnBackToWorkspace.Click += delegate { SelectNavTab(0); };
            outer.Children.Add(_btnBackToWorkspace);

            scroll.Content = outer;
            return scroll;
        }

        private Border CreateSafetyInfoCard(out TextBlock titleBlock, out TextBlock bodyBlock, Brush titleBrush)
        {
            var card = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(16, 14, 16, 14)
            };
            var stack = new StackPanel();
            titleBlock = new TextBlock
            {
                Foreground = titleBrush,
                FontSize = 14,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 0, 0, 8),
                TextWrapping = TextWrapping.Wrap
            };
            bodyBlock = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 12.5,
                LineHeight = 20,
                TextWrapping = TextWrapping.Wrap
            };
            stack.Children.Add(titleBlock);
            stack.Children.Add(bodyBlock);
            card.Child = stack;
            return card;
        }

        private Border BuildFooterBar()
        {
            var footer = new Border
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(0, 1, 0, 0),
                Padding = new Thickness(16, 6, 16, 6)
            };
            var footerGrid = new Grid();
            footerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            footerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            _lblStatusBar = new TextBlock
            {
                Foreground = BrushTextPrimary,
                FontSize = 11.5,
                VerticalAlignment = VerticalAlignment.Center,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            _lblFooterBoundary = new TextBlock
            {
                Foreground = BrushSafetyFg,
                FontSize = 11.5,
                FontWeight = FontWeights.SemiBold,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(16, 0, 0, 0)
            };

            Grid.SetColumn(_lblStatusBar, 0);
            Grid.SetColumn(_lblFooterBoundary, 1);
            footerGrid.Children.Add(_lblStatusBar);
            footerGrid.Children.Add(_lblFooterBoundary);
            footer.Child = footerGrid;
            return footer;
        }

        private CheckBox CreateScopeCheckbox()
        {
            var cb = new CheckBox { IsChecked = true, Margin = new Thickness(0, 2, 0, 2) };
            cb.Checked += OnScopeFilterChanged;
            cb.Unchecked += OnScopeFilterChanged;
            _scopeCheckboxes.Add(cb);
            return cb;
        }

        private static Button CreateActionButton(Brush bg, Brush border, Brush fg)
        {
            return new Button
            {
                Padding = new Thickness(12, 6, 12, 6),
                Margin = new Thickness(0, 1, 6, 1),
                Background = bg,
                BorderBrush = border,
                BorderThickness = new Thickness(1),
                Foreground = fg,
                FontSize = 12,
                FontWeight = FontWeights.SemiBold
            };
        }

        private void SelectNavTab(int index)
        {
            if (index < 0 || index >= _navButtons.Count) return;
            _activeNavIndex = index;

            for (int i = 0; i < _navButtons.Count; i++)
            {
                bool active = (i == index);
                _navButtons[i].Background = active ? BrushBgCard : Brushes.Transparent;
                _navButtons[i].BorderBrush = active ? BrushBorderSubtle : Brushes.Transparent;
                _navButtons[i].Foreground = active ? BrushTextPrimary : BrushTextSecondary;
                _navIndicators[i].Visibility = active ? Visibility.Visible : Visibility.Collapsed;
            }

            _workspacePanel.Visibility = (index == 0) ? Visibility.Visible : Visibility.Collapsed;
            _reportsPanel.Visibility = (index == 1) ? Visibility.Visible : Visibility.Collapsed;
            _aboutPanel.Visibility = (index == 2) ? Visibility.Visible : Visibility.Collapsed;

            if (index == 1)
            {
                RefreshReportsView();
            }

            UpdatePlanGateState();
            UpdateContextBanner();
        }

        private void UpdateContextBanner()
        {
            var s = Localization.GetStrings(_lang);
            if (_isDemoCleaning && _activeNavIndex == 0)
            {
                _lblContextBanner.Text = s["DemoCleaningBanner"];
                return;
            }
            if (_isDemoVerified && _activeNavIndex == 0)
            {
                _lblContextBanner.Text = s["DemoVerifiedBanner"];
                return;
            }
            if (_demoAudit && _activeNavIndex == 0)
            {
                _lblContextBanner.Text = s["DemoBanner"];
                return;
            }
            if (_activeNavIndex == 0) _lblContextBanner.Text = s["NavBannerScanClean"];
            else if (_activeNavIndex == 1) _lblContextBanner.Text = s["NavBannerReports"];
            else _lblContextBanner.Text = s["NavBannerSafety"];
        }

        private void UpdateLogDrawerVisibility()
        {
            if (_logsExpanded)
            {
                double maxAllowed = ActualHeight > 200 ? Math.Max(110.0, Math.Floor(ActualHeight * 0.60)) : 480.0;
                _logDrawerRow.MinHeight = 80;
                _logDrawerRow.MaxHeight = maxAllowed;
                _logDrawerRow.Height = new GridLength(_lastLogHeight >= 80 ? _lastLogHeight : 108);
                _logSplitter.Visibility = Visibility.Visible;
                _logDrawerPanel.Visibility = Visibility.Visible;
            }
            else
            {
                if (_logDrawerPanel.ActualHeight >= 80)
                {
                    _lastLogHeight = _logDrawerPanel.ActualHeight;
                }
                _logDrawerRow.MinHeight = 0;
                _logDrawerRow.Height = new GridLength(0);
                _logSplitter.Visibility = Visibility.Collapsed;
                _logDrawerPanel.Visibility = Visibility.Collapsed;
            }
        }

        private void OnToggleLogsClick(object sender, RoutedEventArgs e)
        {
            _logsExpanded = !_logsExpanded;
            UpdateLogDrawerVisibility();
        }

        private string GetActivePolicy()
        {
            return (_rbFullRemoval != null && _rbFullRemoval.IsChecked == true) ? "FullRemoval" : "AccountData";
        }

        private void OnPolicyPillClick(object sender, RoutedEventArgs e)
        {
            if (_rbFullRemoval.IsChecked == true)
            {
                _rbAccountData.IsChecked = true;
            }
            else
            {
                _rbFullRemoval.IsChecked = true;
            }
        }

        private void OnPolicyRadioChanged(object sender, RoutedEventArgs e)
        {
            UpdatePolicyPillText();
            var s = Localization.GetStrings(_lang);
            RelocalizeExistingRows(s);
            UpdatePlanGateState();
            if (!_isElevated && _rbFullRemoval != null && _rbFullRemoval.IsChecked == true)
            {
                AppendLog("[INFO] " + s["ElevationHintFullRemoval"]);
            }
        }

        private void OnRestartAsAdminClick(object sender, RoutedEventArgs e)
        {
            var s = Localization.GetStrings(_lang);
            if (_isElevated || _dryRun)
            {
                return;
            }
            MessageBoxResult choice = MessageBox.Show(
                this,
                s["RestartAdminPrompt"],
                s["RestartAdminTitle"],
                MessageBoxButton.YesNo,
                MessageBoxImage.Question,
                MessageBoxResult.No);
            if (choice != MessageBoxResult.Yes)
            {
                return;
            }
            try
            {
                string exePath = Assembly.GetExecutingAssembly().Location;
                if (string.IsNullOrEmpty(exePath))
                {
                    exePath = Process.GetCurrentProcess().MainModule.FileName;
                }
                var psi = new ProcessStartInfo
                {
                    FileName = exePath,
                    Arguments = "--language " + _lang,
                    UseShellExecute = true,
                    Verb = "runas"
                };
                Process.Start(psi);
                Close();
            }
            catch (Exception ex)
            {
                AppendLog("[WARN] " + string.Format(s["RestartAdminFailed"], ex.Message));
                MessageBox.Show(this, string.Format(s["RestartAdminFailed"], ex.Message), Title, MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void UpdatePolicyPillText()
        {
            if (_btnPolicyPill == null) return;
            var s = Localization.GetStrings(_lang);
            string policyName = (_rbFullRemoval != null && _rbFullRemoval.IsChecked == true)
                ? s["PolicyFullShort"]
                : s["PolicyAccountShort"];
            _btnPolicyPill.Content = s["PolicyPillPrefix"] + policyName;
        }

        private void OnPresetAccountClick(object sender, RoutedEventArgs e)
        {
            ApplySelectionPreset("AccountData");
        }

        private void OnPresetFullClick(object sender, RoutedEventArgs e)
        {
            ApplySelectionPreset("FullRemoval");
        }

        private void ApplySelectionPreset(string policyName)
        {
            bool isFull = string.Equals(policyName, "FullRemoval", StringComparison.OrdinalIgnoreCase);
            if (_chkCli != null) _chkCli.IsChecked = true;
            if (_chkDesktop != null) _chkDesktop.IsChecked = true;
            if (_chkVsCode != null) _chkVsCode.IsChecked = true;
            if (_chkCred != null) _chkCred.IsChecked = true;
            if (_chkEnv != null) _chkEnv.IsChecked = true;

            if (isFull) _rbFullRemoval.IsChecked = true;
            else _rbAccountData.IsChecked = true;

            _hasPlan = false;
            _readyCount = 0;
            _planSha256 = string.Empty;

            for (int i = 0; i < _allRows.Count; i++)
            {
                ResidualGridRow r = _allRows[i];
                if (!r.CanSelect)
                {
                    r.Selected = false;
                    continue;
                }
                if (isFull)
                {
                    r.Selected = true;
                }
                else
                {
                    r.Selected = string.Equals(r.Policy, "AccountData", StringComparison.OrdinalIgnoreCase);
                }
            }

            RelocalizeExistingRows(Localization.GetStrings(_lang));
            RefreshVisibleRows();
            UpdateMetricCards();
            SyncSelectAllCheckbox();
            UpdatePlanGateState();
        }

        private void OnSelectAllHeaderClick(object sender, RoutedEventArgs e)
        {
            if (_suppressSelectAllSync || _chkSelectAll == null) return;
            bool targetChecked = (_chkSelectAll.IsChecked == true);
            for (int i = 0; i < _visibleRows.Count; i++)
            {
                if (_visibleRows[i].CanSelect)
                {
                    _visibleRows[i].Selected = targetChecked;
                }
            }
        }

        private void SyncSelectAllCheckbox()
        {
            if (_chkSelectAll == null) return;
            _suppressSelectAllSync = true;
            try
            {
                int selectable = 0;
                int selected = 0;
                for (int i = 0; i < _visibleRows.Count; i++)
                {
                    if (_visibleRows[i].CanSelect)
                    {
                        selectable++;
                        if (_visibleRows[i].Selected) selected++;
                    }
                }
                _chkSelectAll.IsChecked = (selectable > 0 && selected == selectable);
            }
            finally
            {
                _suppressSelectAllSync = false;
            }
        }

        private void UpdateAccountIdCard()
        {
            if (_txtAccountIdValue == null) return;
            var s = Localization.GetStrings(_lang);
            if (_accountIdRecords.Count == 0)
            {
                _txtAccountIdValue.Text = s["AccountIdEmpty"];
                _btnCopyAccountId.IsEnabled = false;
                return;
            }
            var parts = new List<string>();
            for (int i = 0; i < _accountIdRecords.Count; i++)
            {
                ResidualAccountIdRecord rec = _accountIdRecords[i];
                parts.Add(string.Format("[{0}] {1}: {2}", rec.Source, rec.Field, rec.Value));
            }
            _txtAccountIdValue.Text = string.Join("   |   ", parts.ToArray());
            _btnCopyAccountId.IsEnabled = true;
        }

        private void OnCopyAccountIdClick(object sender, RoutedEventArgs e)
        {
            if (_accountIdRecords.Count == 0) return;
            var lines = new List<string>();
            for (int i = 0; i < _accountIdRecords.Count; i++)
            {
                ResidualAccountIdRecord rec = _accountIdRecords[i];
                lines.Add(string.Format("{0} | {1} | {2} = {3}", rec.Source, rec.IdType, rec.Field, rec.Value));
            }
            Clipboard.SetText(string.Join("\r\n", lines.ToArray()));
            var s = Localization.GetStrings(_lang);
            _lblStatusBar.Text = s["CopiedAccountIdMsg"];
            AppendLog("[INFO] Copied non-secret residual Account/Device IDs to clipboard.");
        }

        private void UpdatePlanGateState()
        {
            bool armed = _hasScanned && _hasPlan && _readyCount > 0 && !string.IsNullOrEmpty(_planSha256);
            if (_btnClean != null)
            {
                _btnClean.IsEnabled = (_busyDepth == 0) && armed;
            }
            if (_lblPlanGatePill != null && _planGatePillBorder != null)
            {
                var s = Localization.GetStrings(_lang);
                if (armed)
                {
                    string shortSha = _planSha256.Length >= 10 ? _planSha256.Substring(0, 10) : _planSha256;
                    _lblPlanGatePill.Text = string.Format(s["PlanGateReadyPill"], _readyCount, shortSha);
                    _lblPlanGatePill.Foreground = BrushSafetyFg;
                    _planGatePillBorder.Background = BrushSafetyBg;
                    _planGatePillBorder.BorderBrush = BrushSafetyBorder;
                }
                else
                {
                    _lblPlanGatePill.Text = s["PlanGateLockedPill"];
                    _lblPlanGatePill.Foreground = BrushTextSecondary;
                    _planGatePillBorder.Background = BrushBgLog;
                    _planGatePillBorder.BorderBrush = BrushBorderSubtle;
                }
            }
        }

        private void UpdateProgressAndCompletionBanners()
        {
            var s = Localization.GetStrings(_lang);
            if (_cleaningProgressCard != null)
            {
                if (_cleaningInProgress)
                {
                    _cleaningProgressCard.Visibility = Visibility.Visible;
                    _lblCleanProgressTitle.Text = s["CleaningProgressTitle"];
                    int pct = (_cleaningTotalCount > 0)
                        ? (int)Math.Round(Math.Min(100.0, Math.Max(0.0, (_cleaningCurrentIndex * 100.0) / _cleaningTotalCount)))
                        : 0;
                    _lblCleanProgressPercent.Text = string.Format("{0} / {1} ({2}%)", _cleaningCurrentIndex, _cleaningTotalCount, pct);
                    _lblCleanProgressBanner.Text = string.Format(
                        s["CleaningProgressBanner"],
                        Math.Max(1, _cleaningCurrentIndex),
                        Math.Max(1, _cleaningTotalCount),
                        _cleaningCurrentPath);
                }
                else
                {
                    _cleaningProgressCard.Visibility = Visibility.Collapsed;
                }
            }

            if (_completionSummaryBanner != null)
            {
                if (_showCompletionBanner)
                {
                    _completionSummaryBanner.Visibility = Visibility.Visible;
                    bool cleanAll = (_lastLockedCount == 0 && _lastRemainingCount == 0);
                    if (cleanAll)
                    {
                        _completionSummaryBanner.Background = BrushSafetyBg;
                        _completionSummaryBanner.BorderBrush = BrushSafetyBorder;
                        _lblCompletionTitle.Foreground = BrushSafetyFg;
                        _lblCompletionTitle.Text = string.Format(s["CompletionBannerTitleOk"], _lastCleanedCount);
                        _lblCompletionSub.Text = s["CompletionBannerSubOk"];
                    }
                    else
                    {
                        _completionSummaryBanner.Background = BrushBadgeReadyBg;
                        _completionSummaryBanner.BorderBrush = BrushBadgeReadyBorder;
                        _lblCompletionTitle.Foreground = BrushBadgeReadyFg;
                        _lblCompletionTitle.Text = string.Format(s["CompletionBannerTitlePartial"], _lastCleanedCount, Math.Max(_lastLockedCount, _lastRemainingCount));
                        _lblCompletionSub.Text = s["CompletionBannerSubPartial"];
                    }
                    _btnCompletionViewReports.Content = s["NavReports"];
                }
                else
                {
                    _completionSummaryBanner.Visibility = Visibility.Collapsed;
                }
            }
        }

        private void AnimateProgressValue(double targetPercent)
        {
            if (_cleanProgressBar == null) return;
            double clamped = Math.Max(0.0, Math.Min(100.0, targetPercent));
            try
            {
                var anim = new DoubleAnimation
                {
                    To = clamped,
                    Duration = TimeSpan.FromMilliseconds(220),
                    EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut }
                };
                _cleanProgressBar.BeginAnimation(ProgressBar.ValueProperty, anim);
            }
            catch
            {
                _cleanProgressBar.BeginAnimation(ProgressBar.ValueProperty, null);
                _cleanProgressBar.Value = clamped;
            }
        }

        public void ToggleLanguage()
        {
            string next = string.Equals(_lang, "zh-CN", StringComparison.OrdinalIgnoreCase)
                ? "en-US"
                : "zh-CN";
            ApplyLanguage(next);
            RefreshVisibleRows();
        }

        public void ApplyLanguage(string lang)
        {
            _lang = lang;
            var s = Localization.GetStrings(lang);

            Title = s["AppTitle"];
            _lblBrandName.Text = s["BrandName"];
            _lblHeaderTitle.Text = s["HeaderTitle"];
            if (_brandPill != null)
            {
                _brandPill.Visibility = string.Equals(s["BrandName"], s["HeaderTitle"], StringComparison.Ordinal)
                    ? Visibility.Collapsed
                    : Visibility.Visible;
            }
            _lblVersionBadge.Text = s["VersionBadge"];
            _lblSafetyPill.Text = s["SafetyPill"];
            _lblPrivilegeBadge.Text = _isElevated ? s["PrivilegeAdmin"] : s["PrivilegeStandard"];
            _lblPositioning.Text = s["Positioning"];
            _btnRestartAdmin.Content = s["BtnRestartAdmin"];
            _btnLangToggle.Content = s["LangButton"];
            _btnAbout.Content = s["AboutButton"];
            UpdatePolicyPillText();

            _lblSidebarSection.Text = s["SidebarSectionTitle"];
            if (_navButtons.Count >= 3)
            {
                _navButtons[0].Content = s["NavScanClean"];
                _navButtons[1].Content = s["NavReports"];
                _navButtons[2].Content = s["NavSafety"];
            }
            _lblSidebarGuardTitle.Text = s["SidebarGuardTitle"];
            _lblSidebarGuardBody.Text = s["SidebarGuardBody"];

            _lblMetricScannedTitle.Text = s["MetricScannedTitle"];
            _lblMetricScannedSub.Text = s["MetricScannedSub"];
            _lblMetricFoundTitle.Text = s["MetricFoundTitle"];
            _lblMetricFoundSub.Text = s["MetricFoundSub"];
            _lblMetricSizeTitle.Text = s["MetricSizeTitle"];
            _lblMetricSizeSub.Text = s["MetricSizeSub"];
            _lblMetricSafetyTitle.Text = s["MetricSafetyTitle"];
            _lblMetricSafetyValue.Text = s["MetricSafetyValue"];
            _lblMetricSafetySub.Text = s["MetricSafetySub"];

            _lblAccountIdCardTitle.Text = s["AccountIdCardTitle"];
            _lblAccountIdCardSub.Text = s["AccountIdCardSub"];
            _btnCopyAccountId.Content = s["BtnCopyAccountId"];

            _lblScopeHeader.Text = s["ScopeHeader"];
            _chkCli.Content = s["ChkCli"];
            _chkDesktop.Content = s["ChkDesktop"];
            _chkVsCode.Content = s["ChkVsCode"];
            _chkCred.Content = s["ChkCred"];
            _chkEnv.Content = s["ChkEnv"];

            _lblPolicyHeader.Text = s["PolicyHeader"];
            _lblPolicyAccountText.Text = s["PolicyAccount"];
            _lblPolicyFullText.Text = s["PolicyFull"];

            _btnScan.Content = s["BtnScan"];
            _btnPlan.Content = s["BtnPlan"];
            _btnClean.Content = s["BtnClean"];
            _btnVerify.Content = s["BtnVerify"];
            _btnOpenFolder.Content = s["BtnOpenFolder"];
            _btnExportSummary.Content = s["BtnExportSummary"];
            _btnToggleLogs.Content = s["BtnToggleLogs"];

            _lblPresetLabel.Text = s["PresetLabel"];
            _btnPresetAccount.Content = s["PresetAccountBtn"];
            _btnPresetFull.Content = s["PresetFullBtn"];
            _chkSelectAll.Content = s["ColSelect"];

            _colCategory.Header = s["ColCategory"];
            _colPath.Header = s["ColPath"];
            _colStatus.Header = s["ColStatus"];
            _colDetails.Header = s["ColDetails"];

            _lblGridEmptyHint.Text = s["GridEmptyHint"];
            _lblLogDrawerTitle.Text = s["LogDrawerTitle"];

            if (_lblReportsViewTitle != null)
            {
                _lblReportsViewTitle.Text = s["ReportsViewTitle"];
                _lblReportsViewSub.Text = s["ReportsViewSub"];
                _btnRefreshReports.Content = s["BtnRefreshReports"];
                _btnReportsVerify.Content = s["BtnVerify"];
                _btnReportsExportAudit.Content = s["BtnExportSummary"];
                _btnReportsOpenFolder.Content = s["BtnOpenFolder"];
                _lblReportAuditTitle.Text = s["ReportAuditTitle"];
                _lblReportPlanTitle.Text = s["ReportPlanTitle"];
                _lblReportVerifyTitle.Text = s["ReportVerifyTitle"];
                _btnSaveAuditAs.Content = s["BtnSaveAs"];
                _btnOpenAuditFile.Content = s["BtnOpenFile"];
                _btnSavePlanAs.Content = s["BtnSaveAs"];
                _btnOpenPlanFile.Content = s["BtnOpenFile"];
                _btnSaveVerifyAs.Content = s["BtnSaveAs"];
                _btnOpenVerifyFile.Content = s["BtnOpenFile"];
                if (_activeNavIndex == 1)
                {
                    RefreshReportsView();
                }
            }

            _lblSafetyViewTitle.Text = s["SafetyViewTitle"];
            _lblSafetyViewSubtitle.Text = s["SafetyViewSubtitle"];
            _lblSafetyCard1Title.Text = s["SafetyCard1Title"];
            _lblSafetyCard1Body.Text = s["SafetyCard1Body"];
            _lblSafetyCard2Title.Text = s["SafetyCard2Title"];
            _lblSafetyCard2Body.Text = s["SafetyCard2Body"];
            _lblSafetyCard3Title.Text = s["SafetyCard3Title"];
            _lblSafetyCard3Body.Text = s["SafetyCard3Body"];
            _lblSafetyCard4Title.Text = s["SafetyCard4Title"];
            _lblSafetyCard4Body.Text = s["SafetyCard4Body"];
            _btnBackToWorkspace.Content = s["BtnBackToWorkspace"];
            _lblFooterBoundary.Text = s["FooterBoundary"];

            RelocalizeExistingRows(s);
            UpdateAccountIdCard();
            UpdatePlanGateState();
            UpdateProgressAndCompletionBanners();
            UpdateContextBanner();

            if (!_hasScanned)
            {
                _lblStatusBar.Text = s["StatusIdle"];
            }
            else if (_isDemoCleaning)
            {
                _lblStatusBar.Text = s["StatusApplying"];
            }
            else if (_isDemoVerified)
            {
                _lblStatusBar.Text = string.Format(s["StatusVerified"], 6, 0);
            }
            else if (_demoAudit)
            {
                _lblStatusBar.Text = string.Format(s["StatusScanned"], _allRows.Count, CountActiveRows());
            }
        }

        public static void ClassifyNonReadyToneAndLabel(
            Dictionary<string, string> s,
            string itemId,
            string policy,
            string decision,
            string activePolicy,
            out string tone,
            out string label)
        {
            bool isOsBoundary =
                string.Equals(decision, "Blocked", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(itemId, "desktop-msix-data", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(itemId, "vscode-shared-obsolete", StringComparison.OrdinalIgnoreCase);

            if (isOsBoundary)
            {
                tone = "Protected";
                label = s["ProtectedLabel"];
                return;
            }
            bool requiresFullRemoval =
                !string.Equals(activePolicy, "FullRemoval", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(policy, "FullRemoval", StringComparison.OrdinalIgnoreCase);
            if (requiresFullRemoval)
            {
                tone = "Excluded";
                label = s["ExcludedLabel"];
                return;
            }
            tone = "Review";
            label = s["ReviewLabel"];
        }

        private void RelocalizeExistingRows(Dictionary<string, string> s)
        {
            string activePolicy = GetActivePolicy();
            for (int i = 0; i < _allRows.Count; i++)
            {
                ResidualGridRow r = _allRows[i];
                if (r.StatusTone == "Cleaning")
                {
                    r.Status = s["RowCleaningLabel"];
                }
                else if (r.StatusTone == "Locked")
                {
                    r.Status = s["RowLockedLabel"];
                }
                else if (r.StatusTone == "Clean")
                {
                    r.Status = r.IsClearedItem ? s["RowClearedLabel"] : s["CleanLabel"];
                }
                else if (r.StatusTone == "ReadOnly")
                {
                    r.Status = s["ReadOnlyLabel"];
                }
                else if (string.Equals(r.Decision, "Ready", StringComparison.OrdinalIgnoreCase))
                {
                    bool inScope = string.Equals(activePolicy, "FullRemoval", StringComparison.OrdinalIgnoreCase) ||
                                   string.Equals(r.Policy, "AccountData", StringComparison.OrdinalIgnoreCase);
                    r.StatusTone = inScope ? "Ready" : "Excluded";
                    r.Status = inScope ? s["FoundLabel"] : s["ExcludedLabel"];
                }
                else
                {
                    string tone;
                    string label;
                    ClassifyNonReadyToneAndLabel(s, r.ItemId, r.Policy, r.Decision, activePolicy, out tone, out label);
                    r.StatusTone = tone;
                    r.Status = label;
                }
            }
        }

        private void PopulateDemoAuditData()
        {
            var s = Localization.GetStrings(_lang);
            _isDemoCleaning = false;
            _isDemoVerified = false;
            _cleaningInProgress = false;
            _showCompletionBanner = false;
            _allRows.Clear();
            _accountIdRecords.Clear();

            _accountIdRecords.Add(new ResidualAccountIdRecord
            {
                Source = "Claude Code CLI",
                IdType = "AccountUuid",
                Field = "accountUuid",
                Value = "a1b2c3d4-0000-4000-8000-000000000001",
                ConfigPath = @"C:\Users\<USERNAME>\.claude.json"
            });
            _accountIdRecords.Add(new ResidualAccountIdRecord
            {
                Source = "Claude Code CLI",
                IdType = "OrganizationUuid",
                Field = "organizationUuid",
                Value = "b2c3d4e5-0000-4000-8000-000000000002",
                ConfigPath = @"C:\Users\<USERNAME>\.claude.json"
            });
            _accountIdRecords.Add(new ResidualAccountIdRecord
            {
                Source = "Claude Desktop",
                IdType = "DeviceId",
                Field = "anonymousId",
                Value = "dev-claude-0000-4000-8000-000000000003",
                ConfigPath = @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Preferences"
            });

            AddDemoRow(true, true, "ClaudeCode", "AccountData", "cli-credentials", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude\.credentials.json", s["FoundLabel"], "Ready", "Ready", "[AccountData] Claude OAuth credentials cache", 18432, false);
            AddDemoRow(true, true, "ClaudeCode", "AccountData", "cli-global", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude.json", s["FoundLabel"], "Ready", "Ready", "[AccountData] Account UUID & auth metadata (.claude.json)", 42190, false);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-buddy-tokens", "File", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\buddy-tokens.json", s["FoundLabel"], "Ready", "Ready", "[AccountData] Claude Desktop buddy token residual", 12288, false);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-cache", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Cache", s["FoundLabel"], "Ready", "Ready", "[AccountData] Electron GPU/HTTP cache directory", 124620800, false);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-network", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Network", s["FoundLabel"], "Ready", "Ready", "[AccountData] Session cookies & network state", 2450112, false);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-logs", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Local\Claude\logs", s["FoundLabel"], "Ready", "Ready", "[AccountData] Desktop diagnostic log files", 845312, false);

            AddDemoRow(false, true, "ClaudeCode", "FullRemoval", "npm-claude-code", "NpmPackage", "npm Global Package", @"C:\Users\<USERNAME>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code", s["ExcludedLabel"], "Excluded", "Ready", "[FullRemoval] @anthropic-ai/claude-code package binary (switch to FullRemoval)", 38450120, false);
            AddDemoRow(false, true, "VsCodeExtensions", "FullRemoval", "vscode-ext", "VsCodeExtension", "VS Code Extension", @"C:\Users\<USERNAME>\.vscode\extensions\anthropic.claude-code-2.1.40", s["ExcludedLabel"], "Excluded", "Ready", "[FullRemoval] anthropic.claude-code IDE extension (switch to FullRemoval)", 48210400, false);
            AddDemoRow(false, true, "VsCodeExtensions", "FullRemoval", "chrome-native-host", "RegistryKey", "Browser Native Host", @"HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.anthropic.claude_browser_extension", s["ExcludedLabel"], "Excluded", "Ready", "[FullRemoval] Exact HKCU Chrome NativeMessagingHosts key (switch to FullRemoval)", 0, false);
            AddDemoRow(false, false, "ClaudeDesktop", "FullRemoval", "desktop-msix-data", "Directory", "OS-managed MSIX data", @"C:\Users\<USERNAME>\AppData\Local\Packages\Claude_pzs8sxrjxfjjc", s["ProtectedLabel"], "Protected", "Blocked", "[OS Protected] WindowsApps / MSIX OS-managed junction folder (never direct-deleted)", 0, false);

            AddDemoRow(false, false, "CredentialManager", "ReadOnly", "cred-manager", "CredentialManager", "Credential Manager", "Claude* targets (count: 2)", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Credential Manager Claude* target count: 2 (secret values never read)", 0, false);
            AddDemoRow(false, false, "EnvironmentVars", "ReadOnly", "env-0", "EnvVar", "Env (User)", "ANTHROPIC_API_KEY", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Environment variable name only (secret value never read)", 0, false);

            _hasScanned = true;
            _hasPlan = false;
            _readyCount = 0;
            _btnClean.IsEnabled = false;
            RefreshVisibleRows();
            UpdateMetricCards();
            UpdateAccountIdCard();
            UpdatePlanGateState();
            UpdateProgressAndCompletionBanners();
            SyncSelectAllCheckbox();

            AppendLog("[DEMO] Populated sanitized mock audit inventory (12 entries; 3 non-secret UUIDs detected).");
            AppendLog("[DEMO] Ready (AccountData): 6 | FullRemoval Scope: 3 | OS Protected: 1 | Read-Only: 2.");
            AppendLog("[DEMO] Clean button remains locked until a verified SHA-256 plan is generated.");
        }

        public void ApplyDemoCleaningState()
        {
            if (!_dryRun) return;
            PopulateDemoAuditData();
            var s = Localization.GetStrings(_lang);

            _isDemoCleaning = true;
            _isDemoVerified = false;
            _hasScanned = true;
            _hasPlan = true;
            _readyCount = 6;
            _planSha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

            if (_allRows.Count >= 3)
            {
                _allRows[0].StatusTone = "Clean";
                _allRows[0].IsClearedItem = true;
                _allRows[0].Status = s["RowClearedLabel"];
                _allRows[0].Selected = false;
                _allRows[0].CanSelect = false;
                _allRows[0].Details = "[VerifiedAbsent] Removed via Win32 handle-bound deletion";

                _allRows[1].StatusTone = "Clean";
                _allRows[1].IsClearedItem = true;
                _allRows[1].Status = s["RowClearedLabel"];
                _allRows[1].Selected = false;
                _allRows[1].CanSelect = false;
                _allRows[1].Details = "[VerifiedAbsent] Removed via Win32 handle-bound deletion";

                _allRows[2].StatusTone = "Cleaning";
                _allRows[2].Status = s["RowCleaningLabel"];
                _allRows[2].Selected = true;
                _allRows[2].CanSelect = false;
                _allRows[2].Details = "[AccountData] Executing Win32 handle-bound deletion...";
            }

            _cleaningInProgress = true;
            _showCompletionBanner = false;
            _cleaningCurrentIndex = 3;
            _cleaningTotalCount = 6;
            _cleaningCurrentPath = @"C:\Users\<USERNAME>\AppData\Roaming\Claude\buddy-tokens.json";
            if (_cleanProgressBar != null)
            {
                _cleanProgressBar.BeginAnimation(ProgressBar.ValueProperty, null);
                _cleanProgressBar.Value = 50.0;
            }

            _logsExpanded = true;
            UpdateLogDrawerVisibility();
            RefreshVisibleRows();
            UpdateMetricCards();
            UpdateAccountIdCard();
            UpdatePlanGateState();
            UpdateProgressAndCompletionBanners();
            UpdateContextBanner();
            SyncSelectAllCheckbox();
            _lblStatusBar.Text = s["StatusApplying"];

            AppendLog("[DEMO] Plan verified: SHA256=" + _planSha256.Substring(0, 12) + "... | Policy=AccountData (6 Ready)");
            AppendLog("[PROGRESS] 1/6 Cleared: C:\\Users\\<USERNAME>\\.claude\\.credentials.json");
            AppendLog("[PROGRESS] 2/6 Cleared: C:\\Users\\<USERNAME>\\.claude.json");
            AppendLog("[PROGRESS] 3/6 Cleaning: C:\\Users\\<USERNAME>\\AppData\\Roaming\\Claude\\buddy-tokens.json...");
        }

        public void ApplyDemoVerifiedState()
        {
            if (!_dryRun) return;
            var s = Localization.GetStrings(_lang);
            _isDemoCleaning = false;
            _isDemoVerified = true;
            _cleaningInProgress = false;
            _allRows.Clear();
            _accountIdRecords.Clear();

            AddDemoRow(false, false, "ClaudeCode", "AccountData", "cli-credentials", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude\.credentials.json", s["RowClearedLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0, true);
            AddDemoRow(false, false, "ClaudeCode", "AccountData", "cli-global", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude.json", s["RowClearedLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0, true);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-buddy-tokens", "File", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\buddy-tokens.json", s["RowClearedLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0, true);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-cache", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Cache", s["RowClearedLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0, true);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-network", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Network", s["RowClearedLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0, true);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-logs", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Local\Claude\logs", s["RowClearedLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0, true);

            AddDemoRow(false, false, "ClaudeDesktop", "FullRemoval", "desktop-msix-data", "Directory", "OS-managed MSIX data", @"C:\Users\<USERNAME>\AppData\Local\Packages\Claude_pzs8sxrjxfjjc", s["ProtectedLabel"], "Protected", "Blocked", "[OS Protected] WindowsApps / MSIX OS-managed junction folder (untouched)", 0, false);
            AddDemoRow(false, false, "CredentialManager", "ReadOnly", "cred-manager", "CredentialManager", "Credential Manager", "Claude* targets (count: 2)", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Read-only target count (secret values never read)", 0, false);
            AddDemoRow(false, false, "EnvironmentVars", "ReadOnly", "env-0", "EnvVar", "Env (User)", "ANTHROPIC_API_KEY", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Environment variable name only (secret value never read)", 0, false);

            _hasScanned = true;
            _hasPlan = false;
            _readyCount = 0;
            _planSha256 = string.Empty;
            _btnClean.IsEnabled = false;

            _showCompletionBanner = true;
            _lastCleanedCount = 6;
            _lastLockedCount = 0;
            _lastRemainingCount = 0;

            _logsExpanded = true;
            UpdateLogDrawerVisibility();
            RefreshVisibleRows();
            UpdateMetricCards();
            UpdateAccountIdCard();
            UpdatePlanGateState();
            UpdateProgressAndCompletionBanners();
            UpdateContextBanner();
            SyncSelectAllCheckbox();
            _lblStatusBar.Text = string.Format(s["StatusVerified"], 6, 0);

            AppendLog("[DEMO] Cleanup applied for Policy=AccountData (6/6 Ready items removed via Win32 handle).");
            AppendLog("[DEMO] VERIFICATION.md updated atomically; 0 cleanable residuals remaining.");
        }

        private void AddDemoRow(bool selected, bool canSelect, string scopeKey, string policy, string itemId, string kind, string category, string path, string status, string tone, string decision, string details, long sizeBytes, bool isCleared)
        {
            _allRows.Add(new ResidualGridRow
            {
                Selected = selected,
                CanSelect = canSelect,
                IsClearedItem = isCleared,
                ScopeKey = scopeKey,
                Policy = policy,
                ItemId = itemId,
                Kind = kind,
                Category = category,
                PathOrPackage = path,
                Status = status,
                StatusTone = tone,
                Decision = decision,
                Details = details,
                SizeBytes = sizeBytes
            });
        }

        private int CountActiveRows()
        {
            int count = 0;
            for (int i = 0; i < _allRows.Count; i++)
            {
                string t = _allRows[i].StatusTone;
                if (t == "Ready" || t == "Cleaning" || t == "Locked" || t == "Review" || t == "Excluded")
                {
                    count++;
                }
            }
            return count;
        }

        private void UpdateMetricCards()
        {
            if (_lblMetricScannedValue == null) return;
            int total = _allRows.Count;
            int active = CountActiveRows();
            long totalBytes = 0;
            for (int i = 0; i < _allRows.Count; i++)
            {
                ResidualGridRow r = _allRows[i];
                if (r.SizeBytes > 0 && (r.StatusTone == "Ready" || r.StatusTone == "Cleaning"))
                {
                    totalBytes += r.SizeBytes;
                }
            }

            _lblMetricScannedValue.Text = total.ToString();
            _lblMetricFoundValue.Text = active.ToString();
            _lblMetricSizeValue.Text = FormatBytes(totalBytes);
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes <= 0) return "0 B";
            if (bytes < 1024) return string.Format("{0} B", bytes);
            if (bytes < 1024L * 1024L) return string.Format("{0:F1} KB", bytes / 1024.0);
            if (bytes < 1024L * 1024L * 1024L) return string.Format("{0:F1} MB", bytes / (1024.0 * 1024.0));
            return string.Format("{0:F2} GB", bytes / (1024.0 * 1024.0 * 1024.0));
        }

        internal SelfTestReport BuildSelfTestReport()
        {
            string initLang = _lang;
            string initTitle = _lblHeaderTitle.Text;
            string initPill = _lblSafetyPill.Text;
            bool initClean = _btnClean.IsEnabled;

            ToggleLanguage();

            return new SelfTestReport
            {
                AppInstantiated = true,
                InitialLanguage = initLang,
                ToggledLanguage = _lang,
                InitialHeaderTitle = initTitle,
                ToggledHeaderTitle = _lblHeaderTitle.Text,
                InitialSafetyPill = initPill,
                ToggledSafetyPill = _lblSafetyPill.Text,
                ScopeCheckboxCount = _scopeCheckboxes.Count,
                DataGridColumnCount = _gridResults.Columns.Count,
                InitialCleanButtonEnabled = initClean,
                BackendFound = !string.IsNullOrEmpty(_toolkitRoot),
                ResolvedToolkitRoot = _toolkitRoot,
                DryRun = _dryRun,
                NavTabCount = _navButtons.Count,
                MetricCardCount = _metricCards.Count,
                ThemeStyle = "ModernDarkStudio",
                HasGridSplitter = (_logSplitter != null),
                HasAccountIdCard = (_accountIdCard != null && _btnCopyAccountId != null),
                HorizontalScrollEnabled = (_gridResults != null && _gridResults.HorizontalScrollBarVisibility == ScrollBarVisibility.Auto),
                AccountIdCount = _accountIdRecords.Count,
                HasWindowIcon = _hasWindowIcon,
                IsElevated = _isElevated,
                PrivilegeBadgeText = (_lblPrivilegeBadge != null) ? _lblPrivilegeBadge.Text : string.Empty,
                HasRestartAdminButton = (_btnRestartAdmin != null),
                HasCleaningProgressPanel = (_cleaningProgressCard != null && _cleanProgressBar != null),
                HasCompletionSummaryBanner = (_completionSummaryBanner != null && _lblCompletionTitle != null),
                HasReportsView = (_reportsPanel != null),
                CleaningProgressVisible = (_cleaningProgressCard != null && _cleaningProgressCard.Visibility == Visibility.Visible),
                CompletionBannerVisible = (_completionSummaryBanner != null && _completionSummaryBanner.Visibility == Visibility.Visible)
            };
        }

        private void OnLangToggleClick(object sender, RoutedEventArgs e)
        {
            ToggleLanguage();
        }

        private void OnAboutClick(object sender, RoutedEventArgs e)
        {
            SelectNavTab(2);
        }

        private void OnScopeFilterChanged(object sender, RoutedEventArgs e)
        {
            RefreshVisibleRows();
        }

        private void RefreshVisibleRows()
        {
            _visibleRows.Clear();
            for (int i = 0; i < _allRows.Count; i++)
            {
                ResidualGridRow row = _allRows[i];
                if (IsScopeEnabled(row.ScopeKey))
                {
                    _visibleRows.Add(row);
                }
            }
            if (_lblGridEmptyHint != null)
            {
                _lblGridEmptyHint.Visibility = (_visibleRows.Count == 0) ? Visibility.Visible : Visibility.Collapsed;
            }
        }

        private bool IsScopeEnabled(string scopeKey)
        {
            if (scopeKey == "ClaudeCode") return _chkCli.IsChecked == true;
            if (scopeKey == "ClaudeDesktop") return _chkDesktop.IsChecked == true;
            if (scopeKey == "VsCodeExtensions") return _chkVsCode.IsChecked == true;
            if (scopeKey == "CredentialManager") return _chkCred.IsChecked == true;
            if (scopeKey == "EnvironmentVars") return _chkEnv.IsChecked == true;
            return true;
        }

        private static string ClassifyScope(string id, string category, string path)
        {
            if (Regex.IsMatch(id ?? string.Empty, "vscode|native-host|cursor|windsurf|browser", RegexOptions.IgnoreCase) ||
                Regex.IsMatch(category ?? string.Empty, "VS Code|Extension|Native Messaging|Browser", RegexOptions.IgnoreCase) ||
                Regex.IsMatch(path ?? string.Empty, "anthropic\\.claude-code|NativeMessagingHosts", RegexOptions.IgnoreCase))
            {
                return "VsCodeExtensions";
            }
            if (Regex.IsMatch(id ?? string.Empty, "desktop|appdata|msix|appx|local-claude|roaming", RegexOptions.IgnoreCase) ||
                Regex.IsMatch(category ?? string.Empty, "Desktop|AppX|MSIX|AppData|Cache|Log", RegexOptions.IgnoreCase) ||
                Regex.IsMatch(path ?? string.Empty, "\\\\AppData\\\\|\\\\Packages\\\\Claude_|^Claude_", RegexOptions.IgnoreCase))
            {
                return "ClaudeDesktop";
            }
            return "ClaudeCode";
        }

        private bool EnsureBackend()
        {
            if (!string.IsNullOrEmpty(_toolkitRoot) && File.Exists(Path.Combine(_toolkitRoot, "ClaudeCleanup.ps1")))
            {
                return true;
            }
            var s = Localization.GetStrings(_lang);
            MessageBox.Show(this, s["BackendMissing"], Title, MessageBoxButton.OK, MessageBoxImage.Error);
            return false;
        }

        private void SetBusy(bool busy)
        {
            if (busy)
            {
                _busyDepth++;
            }
            else if (_busyDepth > 0)
            {
                _busyDepth--;
            }
            bool isBusy = (_busyDepth > 0);
            _btnScan.IsEnabled = !isBusy;
            _btnPlan.IsEnabled = !isBusy;
            _btnVerify.IsEnabled = !isBusy;
            _btnLangToggle.IsEnabled = !isBusy;
            _btnExportSummary.IsEnabled = !isBusy;
            _btnPolicyPill.IsEnabled = !isBusy;
            if (_btnReportsVerify != null) _btnReportsVerify.IsEnabled = !isBusy;
            _btnClean.IsEnabled = (!isBusy) && _hasScanned && _hasPlan && (_readyCount > 0);
        }

        public static string StripAnsiEscapeCodes(string text)
        {
            if (string.IsNullOrEmpty(text)) return string.Empty;
            string cleaned = Regex.Replace(text, @"\x1B\[[0-9;?]*[A-Za-z]", string.Empty);
            cleaned = cleaned.Replace("\x1B", string.Empty);
            return cleaned;
        }

        public static bool IsClaudeRunningError(string rawError)
        {
            string cleaned = StripAnsiEscapeCodes(rawError);
            return cleaned.IndexOf("Claude is running", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        public static string ExtractRunningProcessList(string rawError)
        {
            string cleaned = StripAnsiEscapeCodes(rawError);
            Match m = Regex.Match(cleaned, @"Processes:\s*(.+?)(?=\.\s+(?:Shut|Unable)|[\r\n]|$)", RegexOptions.IgnoreCase);
            if (m.Success && !string.IsNullOrWhiteSpace(m.Groups[1].Value))
            {
                string[] parts = m.Groups[1].Value.Split(',');
                var lines = new List<string>();
                for (int i = 0; i < parts.Length; i++)
                {
                    string item = parts[i].Trim();
                    if (!string.IsNullOrEmpty(item))
                    {
                        lines.Add(" - " + item);
                    }
                }
                if (lines.Count > 0)
                {
                    return string.Join("\r\n", lines.ToArray());
                }
            }
            return " - Claude";
        }

        public static string FormatClaudeRunningPrompt(string rawError, string lang)
        {
            var s = Localization.GetStrings(lang);
            string procList = ExtractRunningProcessList(rawError);
            return string.Format(s["ClaudeRunningPromptBody"], procList);
        }

        public static string FormatPartialFailureMessage(string jsonStdOut, string rawStdErr, string lang, out bool isPartialFailure)
        {
            isPartialFailure = false;
            var s = Localization.GetStrings(lang);
            string cleanErr = StripAnsiEscapeCodes(rawStdErr);

            Dictionary<string, object> doc = null;
            if (!string.IsNullOrWhiteSpace(jsonStdOut))
            {
                try
                {
                    doc = ParseJsonObject(jsonStdOut);
                }
                catch
                {
                    doc = null;
                }
            }

            string outcome = (doc != null) ? GetDictString(doc, "Outcome") : string.Empty;
            if (doc == null && !string.IsNullOrWhiteSpace(jsonStdOut))
            {
                Match om = Regex.Match(jsonStdOut, "\"Outcome\"\\s*:\\s*\"(PartialFailure|Failed)\"", RegexOptions.IgnoreCase);
                if (om.Success) outcome = om.Groups[1].Value;
            }
            bool hasOutcomePartial =
                string.Equals(outcome, "PartialFailure", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(outcome, "Failed", StringComparison.OrdinalIgnoreCase);

            if (!hasOutcomePartial &&
                cleanErr.IndexOf("PartialFailure", StringComparison.OrdinalIgnoreCase) < 0)
            {
                return string.Empty;
            }

            isPartialFailure = true;
            var cleanedLines = new List<string>();
            var lockedLines = new List<string>();

            object resObj;
            if (doc != null && doc.TryGetValue("Results", out resObj) && resObj is ArrayList)
            {
                var items = (ArrayList)resObj;
                for (int i = 0; i < items.Count; i++)
                {
                    var r = items[i] as Dictionary<string, object>;
                    if (r == null) continue;
                    string status = GetDictString(r, "Status");
                    string path = StripAnsiEscapeCodes(GetDictString(r, "Path"));
                    string err = StripAnsiEscapeCodes(GetDictString(r, "Error"));
                    if (string.Equals(status, "Removed", StringComparison.OrdinalIgnoreCase))
                    {
                        cleanedLines.Add(" - " + path);
                    }
                    else if (string.Equals(status, "Failed", StringComparison.OrdinalIgnoreCase) ||
                             string.Equals(status, "NotExecuted", StringComparison.OrdinalIgnoreCase))
                    {
                        string suffix = string.IsNullOrEmpty(err) ? string.Empty : " (" + err + ")";
                        lockedLines.Add(" - " + path + suffix);
                    }
                }
            }
            else if (doc == null && !string.IsNullOrWhiteSpace(jsonStdOut))
            {
                Match om = Regex.Match(jsonStdOut, "\"Outcome\"\\s*:\\s*\"(PartialFailure|Failed)\"", RegexOptions.IgnoreCase);
                if (!om.Success && cleanErr.IndexOf("PartialFailure", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    return string.Empty;
                }
                isPartialFailure = true;
                MatchCollection entryMatches = Regex.Matches(jsonStdOut, "\\{[^{}]*\"Status\"\\s*:\\s*\"([^\"]+)\"[^{}]*\\}", RegexOptions.Singleline);
                for (int i = 0; i < entryMatches.Count; i++)
                {
                    string block = entryMatches[i].Value;
                    string status = entryMatches[i].Groups[1].Value;
                    Match pm = Regex.Match(block, "\"Path\"\\s*:\\s*\"((?:\\\\.|[^\"])*)\"");
                    Match em = Regex.Match(block, "\"Error\"\\s*:\\s*\"((?:\\\\.|[^\"])*)\"");
                    string path = pm.Success ? Regex.Unescape(pm.Groups[1].Value) : string.Empty;
                    string err = em.Success ? Regex.Unescape(em.Groups[1].Value) : string.Empty;
                    if (string.Equals(status, "Removed", StringComparison.OrdinalIgnoreCase) && !string.IsNullOrEmpty(path))
                    {
                        cleanedLines.Add(" - " + path);
                    }
                    else if ((string.Equals(status, "Failed", StringComparison.OrdinalIgnoreCase) ||
                              string.Equals(status, "NotExecuted", StringComparison.OrdinalIgnoreCase)) && !string.IsNullOrEmpty(path))
                    {
                        string suffix = string.IsNullOrEmpty(err) ? string.Empty : " (" + err + ")";
                        lockedLines.Add(" - " + path + suffix);
                    }
                }
            }

            string noneText = string.Equals(lang, "zh-CN", StringComparison.OrdinalIgnoreCase) ? " - (无)" : " - (None)";
            string cleanedText = (cleanedLines.Count > 0) ? string.Join("\r\n", cleanedLines.ToArray()) : noneText;
            string lockedText = (lockedLines.Count > 0)
                ? string.Join("\r\n", lockedLines.ToArray())
                : (" - " + (string.IsNullOrWhiteSpace(cleanErr) ? "Target file locked" : cleanErr));

            int remainingCount = (lockedLines.Count > 0) ? lockedLines.Count : 1;
            return string.Format(s["PartialFailureBody"], cleanedLines.Count, remainingCount, cleanedText, lockedText);
        }

        public static string TranslateFriendlyBackendError(string rawError, string lang, out bool isProcessWarning, out string customTitle)
        {
            string cleaned = StripAnsiEscapeCodes(rawError).Trim();
            var s = Localization.GetStrings(lang);
            if (cleaned.IndexOf("Claude is running", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                isProcessWarning = true;
                customTitle = s["ClaudeRunningTitle"];
                return s["ClaudeRunningBody"];
            }
            if (cleaned.IndexOf("VS Code is running", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                isProcessWarning = true;
                customTitle = s["VsCodeRunningTitle"];
                return s["VsCodeRunningBody"];
            }
            isProcessWarning = false;
            customTitle = string.Empty;
            return cleaned;
        }

        private void ShowBackendErrorDialog(string logPrefix, string rawError)
        {
            string cleanRaw = StripAnsiEscapeCodes(rawError).Trim();
            bool isProcessWarning;
            string customTitle;
            string friendlyMessage = TranslateFriendlyBackendError(cleanRaw, _lang, out isProcessWarning, out customTitle);
            AppendLog(logPrefix + (isProcessWarning ? friendlyMessage : cleanRaw));
            string dialogTitle = string.IsNullOrEmpty(customTitle) ? Title : customTitle;
            MessageBoxImage icon = isProcessWarning ? MessageBoxImage.Warning : MessageBoxImage.Error;
            MessageBox.Show(this, string.IsNullOrEmpty(friendlyMessage) ? cleanRaw : friendlyMessage, dialogTitle, MessageBoxButton.OK, icon);
        }

        private void AppendLog(string message)
        {
            if (_txtLog == null) return;
            string safeMessage = StripAnsiEscapeCodes(message);
            string line = string.Format("[{0}] {1}{2}", DateTime.Now.ToString("HH:mm:ss"), safeMessage, Environment.NewLine);
            _txtLog.AppendText(line);
            _txtLog.ScrollToEnd();
        }

        private static string FindPowerShellExecutable()
        {
            string pwsh = FindOnPath("pwsh.exe");
            if (!string.IsNullOrEmpty(pwsh)) return pwsh;
            string sysPs = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
            if (File.Exists(sysPs)) return sysPs;
            return "powershell.exe";
        }

        private static string FindOnPath(string exeName)
        {
            string pathEnv = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
            string[] dirs = pathEnv.Split(';');
            for (int i = 0; i < dirs.Length; i++)
            {
                string d = dirs[i].Trim();
                if (string.IsNullOrEmpty(d)) continue;
                try
                {
                    string candidate = Path.Combine(d, exeName);
                    if (File.Exists(candidate)) return candidate;
                }
                catch
                {
                }
            }
            return string.Empty;
        }

        private static string QuoteArg(string val)
        {
            if (string.IsNullOrEmpty(val)) return "\"\"";
            if (!Regex.IsMatch(val, @"[\s""]")) return val;
            string escaped = Regex.Replace(val, @"(\\*)" + "\"", "$1$1\\\"");
            escaped = Regex.Replace(escaped, @"(\\+)$", "$1$1");
            return "\"" + escaped + "\"";
        }

        private void RunBackendAsync(string[] scriptArgs, Action<BackendRunResult> onDone)
        {
            RunBackendAsync(scriptArgs, null, onDone);
        }

        private void RunBackendAsync(string[] scriptArgs, Action<string> onProgressLine, Action<BackendRunResult> onDone)
        {
            string psExe = FindPowerShellExecutable();
            string backend = Path.Combine(_toolkitRoot, "ClaudeCleanup.ps1");

            var allArgs = new List<string>();
            allArgs.Add("-NoProfile");
            allArgs.Add("-NonInteractive");
            allArgs.Add("-File");
            allArgs.Add(QuoteArg(backend));
            for (int i = 0; i < scriptArgs.Length; i++)
            {
                allArgs.Add(QuoteArg(scriptArgs[i]));
            }

            SetBusy(true);
            ThreadPool.QueueUserWorkItem(delegate
            {
                BackendRunResult res = new BackendRunResult();
                var errSb = new StringBuilder();
                var errLock = new object();
                using (var errDone = new ManualResetEvent(false))
                {
                    try
                    {
                        var psi = new ProcessStartInfo
                        {
                            FileName = psExe,
                            Arguments = string.Join(" ", allArgs.ToArray()),
                            UseShellExecute = false,
                            CreateNoWindow = true,
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                            StandardOutputEncoding = Encoding.UTF8,
                            StandardErrorEncoding = Encoding.UTF8
                        };
                        psi.EnvironmentVariables["NO_COLOR"] = "1";
                        psi.EnvironmentVariables["TERM"] = "dumb";
                        using (var proc = new Process { StartInfo = psi })
                        {
                            proc.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e)
                            {
                                if (e.Data == null)
                                {
                                    try { errDone.Set(); } catch { }
                                    return;
                                }
                                string cleanLine = StripAnsiEscapeCodes(e.Data);
                                if (cleanLine.StartsWith("@@PROGRESS@@", StringComparison.Ordinal))
                                {
                                    string payload = cleanLine.Substring("@@PROGRESS@@".Length);
                                    if (onProgressLine != null)
                                    {
                                        Dispatcher.BeginInvoke(new Action(delegate
                                        {
                                            onProgressLine(payload);
                                        }));
                                    }
                                    return;
                                }
                                lock (errLock)
                                {
                                    errSb.AppendLine(cleanLine);
                                }
                            };
                            proc.Start();
                            proc.BeginErrorReadLine();
                            res.StdOut = proc.StandardOutput.ReadToEnd();
                            proc.WaitForExit();
                            errDone.WaitOne(5000);
                            res.ExitCode = proc.ExitCode;
                            lock (errLock)
                            {
                                res.StdErr = errSb.ToString();
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        res.ExitCode = -1;
                        res.StdErr = ex.Message;
                        res.StdOut = string.Empty;
                    }
                }

                Dispatcher.BeginInvoke(new Action(delegate
                {
                    try
                    {
                        onDone(res);
                    }
                    finally
                    {
                        SetBusy(false);
                    }
                }));
            });
        }

        private void HandleCleaningProgressEvent(string jsonPayload)
        {
            if (string.IsNullOrWhiteSpace(jsonPayload)) return;
            Dictionary<string, object> evt;
            try
            {
                evt = ParseJsonObject(jsonPayload);
            }
            catch
            {
                return;
            }

            var s = Localization.GetStrings(_lang);
            string phase = GetDictString(evt, "Phase");
            int index = GetDictInt(evt, "Index");
            int total = GetDictInt(evt, "Total");
            string itemId = GetDictString(evt, "Id");
            string itemPath = StripAnsiEscapeCodes(GetDictString(evt, "Path"));
            string status = GetDictString(evt, "Status");
            string err = StripAnsiEscapeCodes(GetDictString(evt, "Error"));

            _cleaningInProgress = true;
            _cleaningCurrentIndex = Math.Max(0, index);
            _cleaningTotalCount = Math.Max(1, total);
            if (!string.IsNullOrEmpty(itemPath))
            {
                _cleaningCurrentPath = itemPath;
            }

            ResidualGridRow matchRow = FindGridRowByIdOrPath(itemId, itemPath);

            if (string.Equals(phase, "Cleaning", StringComparison.OrdinalIgnoreCase))
            {
                double startPct = ((Math.Max(1, index) - 0.5) * 100.0) / Math.Max(1, total);
                AnimateProgressValue(startPct);
                UpdateProgressAndCompletionBanners();
                _lblStatusBar.Text = string.Format(s["CleaningProgressBanner"], index, total, itemPath);
                if (matchRow != null)
                {
                    matchRow.StatusTone = "Cleaning";
                    matchRow.Status = s["RowCleaningLabel"];
                    matchRow.CanSelect = false;
                    try { _gridResults.ScrollIntoView(matchRow); } catch { }
                }
                AppendLog(string.Format("[PROGRESS] {0}/{1} Cleaning: {2}", index, total, itemPath));
            }
            else if (string.Equals(phase, "Result", StringComparison.OrdinalIgnoreCase))
            {
                double donePct = (index * 100.0) / Math.Max(1, total);
                AnimateProgressValue(donePct);
                UpdateProgressAndCompletionBanners();

                bool ok = string.Equals(status, "Removed", StringComparison.OrdinalIgnoreCase) ||
                          string.Equals(status, "AlreadyAbsent", StringComparison.OrdinalIgnoreCase);
                if (ok)
                {
                    _lastCleanedCount++;
                }
                else
                {
                    _lastLockedCount++;
                }

                if (matchRow != null)
                {
                    matchRow.Selected = false;
                    matchRow.CanSelect = false;
                    if (ok)
                    {
                        matchRow.StatusTone = "Clean";
                        matchRow.IsClearedItem = true;
                        matchRow.Status = s["RowClearedLabel"];
                        matchRow.Details = "[VerifiedAbsent] Removed via Win32 handle-bound engine";
                    }
                    else
                    {
                        matchRow.StatusTone = "Locked";
                        matchRow.Status = s["RowLockedLabel"];
                        if (!string.IsNullOrEmpty(err))
                        {
                            matchRow.Details = "[Locked / Skipped] " + err;
                        }
                    }
                }
                UpdateMetricCards();
                AppendLog(string.Format("[PROGRESS] {0}/{1} {2}: {3}{4}", index, total, ok ? "Cleared" : status, itemPath, string.IsNullOrEmpty(err) ? string.Empty : (" (" + err + ")")));
            }
        }

        private ResidualGridRow FindGridRowByIdOrPath(string itemId, string path)
        {
            for (int i = 0; i < _allRows.Count; i++)
            {
                if (!string.IsNullOrEmpty(itemId) && string.Equals(_allRows[i].ItemId, itemId, StringComparison.OrdinalIgnoreCase))
                {
                    return _allRows[i];
                }
            }
            for (int i = 0; i < _allRows.Count; i++)
            {
                if (!string.IsNullOrEmpty(path) && string.Equals(_allRows[i].PathOrPackage, path, StringComparison.OrdinalIgnoreCase))
                {
                    return _allRows[i];
                }
            }
            return null;
        }

        private static Dictionary<string, object> ParseJsonObject(string raw)
        {
            if (string.IsNullOrEmpty(raw))
            {
                throw new InvalidOperationException("Backend returned empty output.");
            }
            int idx = raw.IndexOf('{');
            if (idx < 0)
            {
                throw new InvalidOperationException("Backend output did not contain JSON: " + raw);
            }
            var ser = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
            return ser.Deserialize<Dictionary<string, object>>(raw.Substring(idx));
        }

        private static string GetDictString(Dictionary<string, object> dict, string key)
        {
            object val;
            if (dict != null && dict.TryGetValue(key, out val) && val != null)
            {
                return Convert.ToString(val);
            }
            return string.Empty;
        }

        private static int GetDictInt(Dictionary<string, object> dict, string key)
        {
            object val;
            if (dict != null && dict.TryGetValue(key, out val) && val != null)
            {
                return Convert.ToInt32(val);
            }
            return 0;
        }

        private static long GetDictLong(Dictionary<string, object> dict, string key)
        {
            object val;
            if (dict != null && dict.TryGetValue(key, out val) && val != null)
            {
                try
                {
                    return Convert.ToInt64(val);
                }
                catch
                {
                    return 0;
                }
            }
            return 0;
        }

        private void OnScanClick(object sender, RoutedEventArgs e)
        {
            if (_demoAudit)
            {
                PopulateDemoAuditData();
                SelectNavTab(0);
                return;
            }
            if (!EnsureBackend()) return;
            var s = Localization.GetStrings(_lang);
            _showCompletionBanner = false;
            _cleaningInProgress = false;
            UpdateProgressAndCompletionBanners();
            _lblStatusBar.Text = s["StatusScanning"];
            AppendLog("Starting read-only scan (-Audit -Language " + _lang + ")...");

            RunBackendAsync(new string[] { "-Audit", "-Language", _lang, "-OutputFormat", "Json" }, delegate(BackendRunResult res)
            {
                if (res.ExitCode != 0)
                {
                    ShowBackendErrorDialog("[ERROR] Scan failed: ", res.StdErr);
                    return;
                }

                var doc = ParseJsonObject(res.StdOut);
                _allRows.Clear();
                _accountIdRecords.Clear();
                int activeCount = 0;
                string activePolicy = GetActivePolicy();

                object invObj;
                if (doc.TryGetValue("Inventory", out invObj) && invObj is ArrayList)
                {
                    var invList = (ArrayList)invObj;
                    for (int i = 0; i < invList.Count; i++)
                    {
                        var item = invList[i] as Dictionary<string, object>;
                        if (item == null) continue;
                        string policy = GetDictString(item, "Policy");
                        string id = GetDictString(item, "Id");
                        string kind = GetDictString(item, "Kind");
                        string cat = GetDictString(item, "Category");
                        string path = GetDictString(item, "Path");
                        string decision = GetDictString(item, "Decision");
                        string reason = GetDictString(item, "Reason");
                        long sizeBytes = GetDictLong(item, "SizeBytes");
                        bool ready = string.Equals(decision, "Ready", StringComparison.OrdinalIgnoreCase);
                        bool inPolicy = string.Equals(activePolicy, "FullRemoval", StringComparison.OrdinalIgnoreCase) ||
                                        string.Equals(policy, "AccountData", StringComparison.OrdinalIgnoreCase);
                        if (ready) activeCount++;

                        string tone;
                        string statusLabel;
                        if (ready)
                        {
                            tone = inPolicy ? "Ready" : "Excluded";
                            statusLabel = inPolicy ? s["FoundLabel"] : s["ExcludedLabel"];
                        }
                        else
                        {
                            ClassifyNonReadyToneAndLabel(s, id, policy, decision, activePolicy, out tone, out statusLabel);
                        }

                        _allRows.Add(new ResidualGridRow
                        {
                            Selected = (ready && inPolicy),
                            CanSelect = ready,
                            IsClearedItem = false,
                            ScopeKey = ClassifyScope(id, cat, path),
                            Policy = policy,
                            ItemId = id,
                            Kind = kind,
                            Category = StripAnsiEscapeCodes(cat),
                            PathOrPackage = StripAnsiEscapeCodes(path),
                            Status = statusLabel,
                            StatusTone = tone,
                            Decision = decision,
                            Details = StripAnsiEscapeCodes(string.Format("[{0}] {1}", policy, reason)),
                            SizeBytes = sizeBytes
                        });
                    }
                }

                object sumObj;
                if (doc.TryGetValue("Summary", out sumObj) && sumObj is Dictionary<string, object>)
                {
                    var sumDict = (Dictionary<string, object>)sumObj;
                    object idsObj;
                    if (sumDict.TryGetValue("ResidualAccountIds", out idsObj) && idsObj is ArrayList)
                    {
                        var idList = (ArrayList)idsObj;
                        for (int i = 0; i < idList.Count; i++)
                        {
                            var rec = idList[i] as Dictionary<string, object>;
                            if (rec == null) continue;
                            _accountIdRecords.Add(new ResidualAccountIdRecord
                            {
                                Source = GetDictString(rec, "Source"),
                                IdType = GetDictString(rec, "IdType"),
                                Field = GetDictString(rec, "Field"),
                                Value = GetDictString(rec, "Value"),
                                ConfigPath = GetDictString(rec, "ConfigPath")
                            });
                        }
                    }

                    object envObj;
                    if (sumDict.TryGetValue("EnvironmentVariableNames", out envObj) && envObj is ArrayList)
                    {
                        var envList = (ArrayList)envObj;
                        for (int i = 0; i < envList.Count; i++)
                        {
                            var ev = envList[i] as Dictionary<string, object>;
                            if (ev == null) continue;
                            activeCount++;
                            _allRows.Add(new ResidualGridRow
                            {
                                Selected = false,
                                CanSelect = false,
                                IsClearedItem = false,
                                ScopeKey = "EnvironmentVars",
                                Policy = "ReadOnly",
                                ItemId = "env-" + i,
                                Kind = "EnvVar",
                                Category = "Env (" + GetDictString(ev, "Scope") + ")",
                                PathOrPackage = GetDictString(ev, "Name"),
                                Status = s["ReadOnlyLabel"],
                                StatusTone = "ReadOnly",
                                Decision = "ReadOnly",
                                Details = s["ReadOnlyLabel"],
                                SizeBytes = 0
                            });
                        }
                    }
                }

                object envLinesObj;
                if (doc.TryGetValue("EnvironmentLines", out envLinesObj) && envLinesObj is ArrayList)
                {
                    var lines = (ArrayList)envLinesObj;
                    for (int i = 0; i < lines.Count; i++)
                    {
                        string l = Convert.ToString(lines[i]);
                        if (l != null && l.IndexOf("Credential Manager", StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            bool zero = l.IndexOf("count: 0", StringComparison.OrdinalIgnoreCase) >= 0;
                            if (!zero) activeCount++;
                            _allRows.Add(new ResidualGridRow
                            {
                                Selected = false,
                                CanSelect = false,
                                IsClearedItem = false,
                                ScopeKey = "CredentialManager",
                                Policy = "ReadOnly",
                                ItemId = "cred-manager",
                                Kind = "CredentialManager",
                                Category = "Credential Manager",
                                PathOrPackage = "Claude* targets",
                                Status = zero ? s["CleanLabel"] : s["ReadOnlyLabel"],
                                StatusTone = zero ? "Clean" : "ReadOnly",
                                Decision = "ReadOnly",
                                Details = l,
                                SizeBytes = 0
                            });
                        }
                    }
                }

                _hasScanned = true;
                _hasPlan = false;
                _readyCount = 0;
                _planSha256 = string.Empty;
                RefreshVisibleRows();
                UpdateMetricCards();
                UpdateAccountIdCard();
                SyncSelectAllCheckbox();
                UpdatePlanGateState();
                _lblStatusBar.Text = string.Format(s["StatusScanned"], _allRows.Count, activeCount);
                AppendLog(string.Format("Scan finished: {0} total entries inspected; {1} non-secret Account/Device IDs found.", _allRows.Count, _accountIdRecords.Count));
            });
        }

        private void OnPlanClick(object sender, RoutedEventArgs e)
        {
            var s = Localization.GetStrings(_lang);
            if (_demoAudit)
            {
                MessageBox.Show(this, s["DemoPlanNotice"], Title, MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            if (!EnsureBackend()) return;
            _lblStatusBar.Text = s["StatusPlanning"];
            AppendLog("Generating CLEANUP-PLAN.md (-Plan -Language " + _lang + ")...");

            RunBackendAsync(new string[] { "-Plan", "-Language", _lang, "-OutputFormat", "Json" }, delegate(BackendRunResult res)
            {
                if (res.ExitCode != 0)
                {
                    ShowBackendErrorDialog("[ERROR] Plan failed: ", res.StdErr);
                    return;
                }

                var planDoc = ParseJsonObject(res.StdOut);
                _planSha256 = GetDictString(planDoc, "Sha256");
                _readyCount = GetDictInt(planDoc, "Ready");
                _hasPlan = !string.IsNullOrEmpty(_planSha256);

                string shortSha = _planSha256.Length >= 12 ? _planSha256.Substring(0, 12) : _planSha256;
                UpdatePlanGateState();
                _lblStatusBar.Text = string.Format(s["StatusPlanned"], _readyCount, shortSha);
                AppendLog(string.Format("CLEANUP-PLAN.md written | Ready={0} | SHA256={1}", _readyCount, _planSha256));
            });
        }

        private void OnCleanClick(object sender, RoutedEventArgs e)
        {
            if (_demoAudit) return;
            if (!EnsureBackend()) return;
            if (!_hasScanned || !_hasPlan || string.IsNullOrEmpty(_planSha256)) return;

            string policy = (_rbFullRemoval.IsChecked == true) ? "FullRemoval" : "AccountData";
            RunCleanPreviewAndExecute(policy, false);
        }

        private bool ConfirmCloseRunningClaudeProcesses(string rawError)
        {
            var s = Localization.GetStrings(_lang);
            string promptBody = FormatClaudeRunningPrompt(rawError, _lang);
            AppendLog("[WARN] " + StripAnsiEscapeCodes(rawError).Trim());
            MessageBoxResult res = MessageBox.Show(
                this,
                promptBody,
                s["ClaudeRunningTitle"],
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning,
                MessageBoxResult.No);
            return (res == MessageBoxResult.Yes);
        }

        private void RunCleanPreviewAndExecute(string policy, bool closeRunningProcesses)
        {
            var s = Localization.GetStrings(_lang);
            AppendLog("Running -WhatIf preview before confirmation dialog...");

            var previewArgs = new List<string>(new string[]
            {
                "-Apply", "-Policy", policy, "-ApprovedManifestSha256", _planSha256,
                "-Language", _lang, "-OutputFormat", "Json", "-WhatIf"
            });
            if (closeRunningProcesses)
            {
                previewArgs.Add("-CloseRunningProcesses");
            }

            RunBackendAsync(previewArgs.ToArray(), delegate(BackendRunResult previewRes)
            {
                if (previewRes.ExitCode != 0)
                {
                    if (!closeRunningProcesses && IsClaudeRunningError(previewRes.StdErr))
                    {
                        if (ConfirmCloseRunningClaudeProcesses(previewRes.StdErr))
                        {
                            AppendLog("User authorized closing running Claude processes; retrying preview...");
                            RunCleanPreviewAndExecute(policy, true);
                        }
                        else
                        {
                            AppendLog("Cleanup cancelled: user declined closing running Claude processes.");
                        }
                        return;
                    }
                    ShowBackendErrorDialog("[ERROR] Preview failed: ", previewRes.StdErr);
                    return;
                }

                var doc = ParseJsonObject(previewRes.StdOut);
                var previewLines = new List<string>();
                object resObj;
                if (doc.TryGetValue("Results", out resObj) && resObj is ArrayList)
                {
                    var items = (ArrayList)resObj;
                    for (int i = 0; i < items.Count; i++)
                    {
                        var r = items[i] as Dictionary<string, object>;
                        if (r == null) continue;
                        if (string.Equals(GetDictString(r, "Status"), "PreviewOnly", StringComparison.OrdinalIgnoreCase))
                        {
                            previewLines.Add(string.Format(" - [{0}] ({1}) {2}", GetDictString(r, "Id"), GetDictString(r, "Kind"), GetDictString(r, "Path")));
                        }
                    }
                }

                if (previewLines.Count == 0)
                {
                    MessageBox.Show(this, s["NoReadyBody"], s["NoReadyTitle"], MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }

                if (_dryRun)
                {
                    AppendLog("DryRun active: blocked live -Apply; showed -WhatIf targets.");
                    MessageBox.Show(this, s["DryRunBody"] + "\r\n\r\n" + string.Join("\r\n", previewLines.ToArray()), s["DryRunTitle"], MessageBoxButton.OK, MessageBoxImage.Information);
                    return;
                }

                string confirmText = string.Format(s["ConfirmBody"], previewLines.Count, policy, _planSha256, string.Join("\r\n", previewLines.ToArray()));
                MessageBoxResult choice = MessageBox.Show(this, confirmText, s["ConfirmTitle"], MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No);
                if (choice != MessageBoxResult.Yes)
                {
                    AppendLog("Cleanup cancelled by user confirmation prompt.");
                    return;
                }

                ExecuteCleanApply(policy, closeRunningProcesses, previewLines.Count);
            });
        }

        private void ExecuteCleanApply(string policy, bool closeRunningProcesses, int expectedTotal)
        {
            var s = Localization.GetStrings(_lang);
            _lastCleanedCount = 0;
            _lastLockedCount = 0;
            _lastRemainingCount = 0;
            _showCompletionBanner = false;
            _cleaningInProgress = true;
            _cleaningCurrentIndex = 0;
            _cleaningTotalCount = Math.Max(1, expectedTotal);
            _cleaningCurrentPath = string.Empty;
            if (_cleanProgressBar != null)
            {
                _cleanProgressBar.BeginAnimation(ProgressBar.ValueProperty, null);
                _cleanProgressBar.Value = 0;
            }
            UpdateProgressAndCompletionBanners();

            _lblStatusBar.Text = s["StatusApplying"];
            AppendLog("User confirmed SHA256=" + _planSha256 + ". Executing ClaudeCleanup.ps1 -Apply -EmitProgress" + (closeRunningProcesses ? " -CloseRunningProcesses" : string.Empty) + "...");

            var applyArgs = new List<string>(new string[]
            {
                "-Apply", "-Policy", policy, "-ApprovedManifestSha256", _planSha256,
                "-Language", _lang, "-OutputFormat", "Json", "-EmitProgress", "-Confirm:$false"
            });
            if (closeRunningProcesses)
            {
                applyArgs.Add("-CloseRunningProcesses");
            }

            RunBackendAsync(applyArgs.ToArray(), HandleCleaningProgressEvent, delegate(BackendRunResult applyRes)
            {
                _cleaningInProgress = false;
                UpdateCountsFromApplyJson(applyRes.StdOut);

                if (applyRes.ExitCode != 0)
                {
                    if (!closeRunningProcesses && IsClaudeRunningError(applyRes.StdErr))
                    {
                        UpdateProgressAndCompletionBanners();
                        if (ConfirmCloseRunningClaudeProcesses(applyRes.StdErr))
                        {
                            AppendLog("User authorized closing running Claude processes; retrying Apply...");
                            ExecuteCleanApply(policy, true, expectedTotal);
                        }
                        else
                        {
                            AppendLog("Cleanup cancelled: user declined closing running Claude processes.");
                        }
                        return;
                    }
                    bool isPartialFailure;
                    string partialMsg = FormatPartialFailureMessage(applyRes.StdOut, applyRes.StdErr, _lang, out isPartialFailure);
                    if (isPartialFailure)
                    {
                        _hasPlan = false;
                        _readyCount = 0;
                        _planSha256 = string.Empty;
                        UpdatePlanGateState();
                        UpdateProgressAndCompletionBanners();
                        AppendLog("[WARN] Partial cleanup completed (some files locked); invoking Verify...");
                        MessageBox.Show(this, partialMsg, s["PartialFailureTitle"], MessageBoxButton.OK, MessageBoxImage.Warning);
                        RunVerifyInternal(true);
                        return;
                    }
                    UpdateProgressAndCompletionBanners();
                    ShowBackendErrorDialog("[ERROR] Cleanup exited " + applyRes.ExitCode + ": ", applyRes.StdErr);
                    return;
                }

                _hasPlan = false;
                _readyCount = 0;
                _planSha256 = string.Empty;
                UpdatePlanGateState();
                UpdateProgressAndCompletionBanners();
                AppendLog("Cleanup complete; invoking automatic Verify...");
                RunVerifyInternal(true);
            });
        }

        private void UpdateCountsFromApplyJson(string stdOut)
        {
            if (string.IsNullOrWhiteSpace(stdOut)) return;
            try
            {
                Dictionary<string, object> doc = ParseJsonObject(stdOut);
                object resObj;
                if (doc != null && doc.TryGetValue("Results", out resObj) && resObj is ArrayList)
                {
                    int removed = 0;
                    int locked = 0;
                    var items = (ArrayList)resObj;
                    for (int i = 0; i < items.Count; i++)
                    {
                        var r = items[i] as Dictionary<string, object>;
                        if (r == null) continue;
                        string st = GetDictString(r, "Status");
                        if (string.Equals(st, "Removed", StringComparison.OrdinalIgnoreCase) ||
                            string.Equals(st, "AlreadyAbsent", StringComparison.OrdinalIgnoreCase))
                        {
                            removed++;
                        }
                        else if (string.Equals(st, "Failed", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(st, "NotExecuted", StringComparison.OrdinalIgnoreCase))
                        {
                            locked++;
                        }
                    }
                    if (removed > 0 || locked > 0)
                    {
                        _lastCleanedCount = removed;
                        _lastLockedCount = locked;
                    }
                }
            }
            catch
            {
            }
        }

        private void OnVerifyClick(object sender, RoutedEventArgs e)
        {
            RunVerifyInternal(false);
        }

        private void RunVerifyInternal(bool fromCleanup)
        {
            var s = Localization.GetStrings(_lang);
            if (_demoAudit)
            {
                MessageBox.Show(this, s["DemoPlanNotice"], Title, MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            if (!EnsureBackend()) return;
            _lblStatusBar.Text = s["StatusVerifying"];
            AppendLog("Running Verify (-Verify -Language " + _lang + ")...");

            RunBackendAsync(new string[] { "-Verify", "-Language", _lang, "-OutputFormat", "Json" }, delegate(BackendRunResult res)
            {
                if (res.ExitCode != 0)
                {
                    ShowBackendErrorDialog("[ERROR] Verify failed: ", res.StdErr);
                    return;
                }

                var doc = ParseJsonObject(res.StdOut);
                object verObj;
                int checkedCount = 0;
                int remainingCleanable = 0;
                string activePolicy = GetActivePolicy();

                if (doc.TryGetValue("Verify", out verObj) && verObj is Dictionary<string, object>)
                {
                    var v = (Dictionary<string, object>)verObj;
                    object pcObj;
                    if (v.TryGetValue("PlanChecks", out pcObj) && pcObj is ArrayList)
                    {
                        checkedCount = ((ArrayList)pcObj).Count;
                    }
                    object ciObj;
                    if (v.TryGetValue("CurrentInventory", out ciObj) && ciObj is ArrayList)
                    {
                        var ciList = (ArrayList)ciObj;
                        for (int i = 0; i < ciList.Count; i++)
                        {
                            var item = ciList[i] as Dictionary<string, object>;
                            if (item == null) continue;
                            string dec = GetDictString(item, "Decision");
                            string pol = GetDictString(item, "Policy");
                            bool inPolicy = string.Equals(activePolicy, "FullRemoval", StringComparison.OrdinalIgnoreCase) ||
                                            string.Equals(pol, "AccountData", StringComparison.OrdinalIgnoreCase);
                            if (string.Equals(dec, "Ready", StringComparison.OrdinalIgnoreCase) && inPolicy)
                            {
                                remainingCleanable++;
                            }
                        }
                    }
                }

                _lastRemainingCount = remainingCleanable;
                if (fromCleanup || _lastCleanedCount > 0)
                {
                    _showCompletionBanner = true;
                    UpdateProgressAndCompletionBanners();
                }

                UpdateMetricCards();
                UpdatePlanGateState();
                if (_activeNavIndex == 1)
                {
                    RefreshReportsView();
                }

                _lblStatusBar.Text = string.Format(s["StatusVerified"], checkedCount, remainingCleanable);
                AppendLog(string.Format("Verify finished: checked={0}, remaining cleanable={1}.", checkedCount, remainingCleanable));
            });
        }

        private void RefreshReportsView()
        {
            if (_txtReportAuditSummary == null) return;
            var s = Localization.GetStrings(_lang);

            if (_demoAudit || _isDemoCleaning || _isDemoVerified)
            {
                _lblReportAuditMeta.Text = "DEMO · AUDIT.md (sanitized mock preview)";
                _txtReportAuditSummary.Text = string.Format(
                    "Detected Entries: {0}\r\nNon-Secret Account/Device UUIDs: {1}\r\nDemo Mode: Zero real disk reads performed.",
                    _allRows.Count, _accountIdRecords.Count);
                _lblReportPlanMeta.Text = _hasPlan ? ("SHA-256: " + _planSha256) : "DEMO · CLEANUP-PLAN.md";
                _txtReportPlanSummary.Text = _hasPlan
                    ? string.Format("SchemaVersion: 3\r\nPolicy: {0}\r\nReady Targets: {1}", GetActivePolicy(), _readyCount)
                    : s["ReportMissing"];
                _lblReportVerifyMeta.Text = _isDemoVerified ? "DEMO · VERIFICATION.md (Outcome: Succeeded)" : "DEMO · VERIFICATION.md";
                _txtReportVerifySummary.Text = _isDemoVerified
                    ? string.Format("Outcome: Succeeded | Cleared: {0} | Remaining Cleanable: 0", _lastCleanedCount)
                    : s["ReportMissing"];
                _btnSavePlanAs.IsEnabled = false;
                _btnOpenPlanFile.IsEnabled = false;
                _btnSaveVerifyAs.IsEnabled = false;
                _btnOpenVerifyFile.IsEnabled = false;
                return;
            }

            if (string.IsNullOrEmpty(_toolkitRoot))
            {
                _lblReportAuditMeta.Text = s["BackendMissing"];
                _txtReportAuditSummary.Text = s["BackendMissing"];
                _txtReportPlanSummary.Text = s["BackendMissing"];
                _txtReportVerifySummary.Text = s["BackendMissing"];
                return;
            }

            PopulateSingleReportSummary("AUDIT.md", _lblReportAuditMeta, _txtReportAuditSummary, _btnSaveAuditAs, _btnOpenAuditFile, s, true);
            PopulateSingleReportSummary("CLEANUP-PLAN.md", _lblReportPlanMeta, _txtReportPlanSummary, _btnSavePlanAs, _btnOpenPlanFile, s, false);
            PopulateSingleReportSummary("VERIFICATION.md", _lblReportVerifyMeta, _txtReportVerifySummary, _btnSaveVerifyAs, _btnOpenVerifyFile, s, false);
        }

        private void PopulateSingleReportSummary(
            string fileName,
            TextBlock metaBlock,
            TextBox summaryBox,
            Button saveBtn,
            Button openBtn,
            Dictionary<string, string> s,
            bool alwaysEnableSave)
        {
            string fullPath = Path.Combine(_toolkitRoot, fileName);
            if (!File.Exists(fullPath))
            {
                metaBlock.Text = fullPath + " (Not found)";
                summaryBox.Text = s["ReportMissing"];
                saveBtn.IsEnabled = alwaysEnableSave;
                openBtn.IsEnabled = false;
                return;
            }

            try
            {
                var fi = new FileInfo(fullPath);
                byte[] bytes = File.ReadAllBytes(fullPath);
                string text = Encoding.UTF8.GetString(bytes);
                string sha;
                using (var sha256 = SHA256.Create())
                {
                    sha = BitConverter.ToString(sha256.ComputeHash(bytes)).Replace("-", string.Empty).ToLowerInvariant();
                }

                metaBlock.Text = string.Format(
                    "{0}  |  {1}  |  UTC {2}  |  SHA-256: {3}...",
                    fileName,
                    FormatBytes(fi.Length),
                    fi.LastWriteTimeUtc.ToString("yyyy-MM-dd HH:mm:ss"),
                    sha.Substring(0, 12));

                if (string.Equals(fileName, "VERIFICATION.md", StringComparison.OrdinalIgnoreCase))
                {
                    summaryBox.Text = SummarizeVerificationMarkdown(text);
                }
                else if (string.Equals(fileName, "CLEANUP-PLAN.md", StringComparison.OrdinalIgnoreCase))
                {
                    summaryBox.Text = SummarizePlanMarkdown(text, sha);
                }
                else
                {
                    summaryBox.Text = SummarizeAuditMarkdown(text);
                }

                saveBtn.IsEnabled = true;
                openBtn.IsEnabled = true;
            }
            catch (Exception ex)
            {
                metaBlock.Text = fileName;
                summaryBox.Text = ex.Message;
                saveBtn.IsEnabled = alwaysEnableSave;
                openBtn.IsEnabled = false;
            }
        }

        private static string SummarizeAuditMarkdown(string text)
        {
            string[] lines = text.Replace("\r\n", "\n").Split('\n');
            var preview = new List<string>();
            for (int i = 0; i < lines.Length && preview.Count < 14; i++)
            {
                string trimmed = lines[i].Trim();
                if (!string.IsNullOrEmpty(trimmed))
                {
                    preview.Add(trimmed);
                }
            }
            return string.Join("\r\n", preview.ToArray());
        }

        private static string SummarizePlanMarkdown(string text, string fileSha)
        {
            var sb = new StringBuilder();
            sb.AppendLine("File SHA-256: " + fileSha);
            int start = text.IndexOf("<!-- PLAN-MANIFEST-BEGIN -->", StringComparison.Ordinal);
            int end = text.IndexOf("<!-- PLAN-MANIFEST-END -->", StringComparison.Ordinal);
            if (start >= 0 && end > start)
            {
                string json = text.Substring(start + "<!-- PLAN-MANIFEST-BEGIN -->".Length, end - start - "<!-- PLAN-MANIFEST-BEGIN -->".Length).Trim();
                try
                {
                    Dictionary<string, object> manifest = ParseJsonObject(json);
                    sb.AppendLine("PlanId: " + GetDictString(manifest, "PlanId"));
                    sb.AppendLine("GeneratedUtc: " + GetDictString(manifest, "GeneratedUtc"));
                    object entriesObj;
                    if (manifest.TryGetValue("Entries", out entriesObj) && entriesObj is ArrayList)
                    {
                        var entries = (ArrayList)entriesObj;
                        int ready = 0;
                        int nonReady = 0;
                        for (int i = 0; i < entries.Count; i++)
                        {
                            var e = entries[i] as Dictionary<string, object>;
                            if (e == null) continue;
                            if (string.Equals(GetDictString(e, "Decision"), "Ready", StringComparison.OrdinalIgnoreCase)) ready++;
                            else nonReady++;
                        }
                        sb.AppendLine(string.Format("Entries: {0} total (Ready={1}, ReviewOnly/Blocked={2})", entries.Count, ready, nonReady));
                    }
                    return sb.ToString().TrimEnd();
                }
                catch { }
            }
            sb.AppendLine(SummarizeAuditMarkdown(text));
            return sb.ToString().TrimEnd();
        }

        private static string SummarizeVerificationMarkdown(string text)
        {
            int start = text.IndexOf("<!-- EXECUTION-LEDGER-BEGIN -->", StringComparison.Ordinal);
            int end = text.IndexOf("<!-- EXECUTION-LEDGER-END -->", StringComparison.Ordinal);
            if (start >= 0 && end > start)
            {
                string json = text.Substring(start + "<!-- EXECUTION-LEDGER-BEGIN -->".Length, end - start - "<!-- EXECUTION-LEDGER-BEGIN -->".Length).Trim();
                try
                {
                    var ser = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
                    var list = ser.Deserialize<ArrayList>(json);
                    if (list != null && list.Count > 0)
                    {
                        var last = list[list.Count - 1] as Dictionary<string, object>;
                        if (last != null)
                        {
                            int removed = 0;
                            int failed = 0;
                            object resObj;
                            if (last.TryGetValue("Results", out resObj) && resObj is ArrayList)
                            {
                                var resList = (ArrayList)resObj;
                                for (int i = 0; i < resList.Count; i++)
                                {
                                    var r = resList[i] as Dictionary<string, object>;
                                    if (r == null) continue;
                                    string st = GetDictString(r, "Status");
                                    if (string.Equals(st, "Removed", StringComparison.OrdinalIgnoreCase)) removed++;
                                    else if (string.Equals(st, "Failed", StringComparison.OrdinalIgnoreCase) || string.Equals(st, "NotExecuted", StringComparison.OrdinalIgnoreCase)) failed++;
                                }
                            }
                            return string.Format(
                                "Ledger Entries: {0}\r\nLatest PlanId: {1}\r\nLatest Policy: {2}  |  Outcome: {3}\r\nCompletedUtc: {4}\r\nLatest Counts: Removed={5}, Failed/NotExecuted={6}",
                                list.Count,
                                GetDictString(last, "PlanId"),
                                GetDictString(last, "Policy"),
                                GetDictString(last, "Outcome"),
                                GetDictString(last, "CompletedUtc"),
                                removed,
                                failed);
                        }
                    }
                }
                catch { }
            }
            return SummarizeAuditMarkdown(text);
        }

        private void ExportExistingMarkdownReport(string fileName)
        {
            var s = Localization.GetStrings(_lang);
            if (!EnsureBackend()) return;
            string srcPath = Path.Combine(_toolkitRoot, fileName);
            if (!File.Exists(srcPath))
            {
                MessageBox.Show(this, s["ReportMissing"], Title, MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            var dlg = new SaveFileDialog
            {
                Title = s["BtnSaveAs"] + " " + fileName,
                Filter = s["SaveDialogFilter"],
                DefaultExt = ".md",
                FileName = fileName,
                InitialDirectory = _toolkitRoot,
                AddExtension = true
            };
            if (dlg.ShowDialog(this) != true || string.IsNullOrEmpty(dlg.FileName))
            {
                return;
            }
            try
            {
                string destPath = Path.GetFullPath(dlg.FileName);
                File.Copy(srcPath, destPath, true);
                PromptOpenExportedAudit(destPath, s);
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, Title, MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void OpenWorkspaceReportFile(string fileName)
        {
            if (!EnsureBackend()) return;
            string fullPath = Path.Combine(_toolkitRoot, fileName);
            if (File.Exists(fullPath))
            {
                Process.Start(new ProcessStartInfo { FileName = fullPath, UseShellExecute = true });
            }
        }

        private void OnOpenFolderClick(object sender, RoutedEventArgs e)
        {
            if (!EnsureBackend()) return;
            Process.Start(new ProcessStartInfo { FileName = _toolkitRoot, UseShellExecute = true });
        }

        private void OnExportSummaryClick(object sender, RoutedEventArgs e)
        {
            var s = Localization.GetStrings(_lang);
            if (!_demoAudit && !EnsureBackend()) return;

            var dlg = new SaveFileDialog
            {
                Title = s["SaveDialogTitle"],
                Filter = s["SaveDialogFilter"],
                DefaultExt = ".md",
                FileName = "AUDIT.md",
                AddExtension = true
            };
            if (!string.IsNullOrEmpty(_toolkitRoot) && Directory.Exists(_toolkitRoot))
            {
                dlg.InitialDirectory = _toolkitRoot;
            }
            bool? picked = dlg.ShowDialog(this);
            if (picked != true || string.IsNullOrEmpty(dlg.FileName))
            {
                return;
            }

            string targetPath = Path.GetFullPath(dlg.FileName);
            if (_demoAudit)
            {
                try
                {
                    var sb = new StringBuilder();
                    sb.AppendLine("# Claude Residual ID Cleaner Demo Audit Report (Sanitized)");
                    sb.AppendLine();
                    sb.AppendLine("## Detected Residual Account IDs (Non-Secret Metadata Only)");
                    for (int i = 0; i < _accountIdRecords.Count; i++)
                    {
                        ResidualAccountIdRecord r = _accountIdRecords[i];
                        sb.AppendLine(string.Format("- {0}: `{1}` = `{2}` (`{3}`)", r.Source, r.Field, r.Value, r.ConfigPath));
                    }
                    File.WriteAllText(targetPath, sb.ToString(), new UTF8Encoding(false));
                    PromptOpenExportedAudit(targetPath, s);
                }
                catch (Exception ex)
                {
                    MessageBox.Show(this, ex.Message, Title, MessageBoxButton.OK, MessageBoxImage.Error);
                }
                return;
            }

            RunBackendAsync(new string[] { "-Audit", "-Language", _lang, "-SaveAuditReport", "-AuditOutputPath", targetPath, "-OutputFormat", "Json" }, delegate(BackendRunResult res)
            {
                if (res.ExitCode != 0)
                {
                    ShowBackendErrorDialog("[ERROR] Export failed: ", res.StdErr);
                    return;
                }
                if (_activeNavIndex == 1)
                {
                    RefreshReportsView();
                }
                PromptOpenExportedAudit(targetPath, s);
            });
        }

        private void PromptOpenExportedAudit(string exportedPath, Dictionary<string, string> s)
        {
            _lblStatusBar.Text = string.Format(s["StatusExported"], exportedPath);
            AppendLog("Exported sanitized report: " + exportedPath);
            MessageBoxResult openChoice = MessageBox.Show(
                this,
                string.Format(s["ExportSuccessAskOpen"], exportedPath),
                s["ExportSuccessTitle"],
                MessageBoxButton.YesNo,
                MessageBoxImage.Information,
                MessageBoxResult.Yes);
            if (openChoice == MessageBoxResult.Yes)
            {
                Process.Start(new ProcessStartInfo { FileName = exportedPath, UseShellExecute = true });
            }
        }

        internal static void PumpDispatcher()
        {
            var frame = new DispatcherFrame();
            Dispatcher.CurrentDispatcher.BeginInvoke(
                DispatcherPriority.ApplicationIdle,
                new DispatcherOperationCallback(delegate(object arg)
                {
                    ((DispatcherFrame)arg).Continue = false;
                    return null;
                }),
                frame);
            Dispatcher.PushFrame(frame);
        }

        internal static void RenderWindowContentToPng(Window win, string outPath, double dpi)
        {
            var rootElement = win.Content as FrameworkElement;
            if (rootElement == null)
            {
                throw new InvalidOperationException("Window content is not a FrameworkElement.");
            }
            double width = rootElement.ActualWidth;
            double height = rootElement.ActualHeight;
            if (width <= 0 || height <= 0)
            {
                rootElement.Measure(new Size(win.Width, win.Height));
                rootElement.Arrange(new Rect(0, 0, win.Width, win.Height));
                rootElement.UpdateLayout();
                width = rootElement.ActualWidth;
                height = rootElement.ActualHeight;
            }
            int pxW = Math.Max(1, (int)Math.Ceiling(width * dpi / 96.0));
            int pxH = Math.Max(1, (int)Math.Ceiling(height * dpi / 96.0));
            var rtb = new RenderTargetBitmap(pxW, pxH, dpi, dpi, PixelFormats.Pbgra32);
            rtb.Render(rootElement);

            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(rtb));

            string parent = Path.GetDirectoryName(Path.GetFullPath(outPath));
            if (!string.IsNullOrEmpty(parent) && !Directory.Exists(parent))
            {
                Directory.CreateDirectory(parent);
            }
            using (var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                encoder.Save(fs);
            }
        }
    }

    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            string language = null;
            string toolkitRoot = null;
            string selfTestOut = null;
            string capturePngPath = null;
            bool headless = false;
            bool dryRun = false;
            bool demoAudit = false;
            bool demoCleaning = false;
            bool demoVerified = false;
            int initialNavIndex = 0;

            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i];
                if (string.Equals(a, "--headless", StringComparison.OrdinalIgnoreCase))
                {
                    headless = true;
                }
                else if (string.Equals(a, "--dry-run", StringComparison.OrdinalIgnoreCase))
                {
                    dryRun = true;
                }
                else if (string.Equals(a, "--demo-audit", StringComparison.OrdinalIgnoreCase))
                {
                    demoAudit = true;
                }
                else if (string.Equals(a, "--demo-cleaning", StringComparison.OrdinalIgnoreCase))
                {
                    demoCleaning = true;
                }
                else if (string.Equals(a, "--demo-verified", StringComparison.OrdinalIgnoreCase))
                {
                    demoVerified = true;
                }
                else if (string.Equals(a, "--nav", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    int parsedNav;
                    if (int.TryParse(args[++i], out parsedNav))
                    {
                        initialNavIndex = (parsedNav >= 0 && parsedNav <= 2) ? parsedNav : 0;
                    }
                }
                else if (string.Equals(a, "--language", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    language = args[++i];
                }
                else if (string.Equals(a, "--toolkit-root", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    toolkitRoot = args[++i];
                }
                else if (string.Equals(a, "--self-test", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    selfTestOut = args[++i];
                }
                else if (string.Equals(a, "--capture-png", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    capturePngPath = args[++i];
                }
            }

            if (headless || !string.IsNullOrEmpty(selfTestOut))
            {
                var win = new MainWindow(language, toolkitRoot, dryRun, demoAudit, initialNavIndex);
                if (demoCleaning && dryRun)
                {
                    win.ApplyDemoCleaningState();
                }
                else if (demoVerified && dryRun)
                {
                    win.ApplyDemoVerifiedState();
                }
                SelfTestReport report = win.BuildSelfTestReport();
                win.Close();
                if (!string.IsNullOrEmpty(selfTestOut))
                {
                    string parent = Path.GetDirectoryName(Path.GetFullPath(selfTestOut));
                    if (!string.IsNullOrEmpty(parent) && !Directory.Exists(parent))
                    {
                        Directory.CreateDirectory(parent);
                    }
                    var ser = new JavaScriptSerializer();
                    File.WriteAllText(selfTestOut, ser.Serialize(report), new UTF8Encoding(false));
                }
                return 0;
            }

            if (!string.IsNullOrEmpty(capturePngPath))
            {
                var captureApp = new Application();
                var captureWin = new MainWindow(language, toolkitRoot, dryRun, demoAudit, initialNavIndex);
                if (demoCleaning && dryRun)
                {
                    captureWin.ApplyDemoCleaningState();
                }
                else if (demoVerified && dryRun)
                {
                    captureWin.ApplyDemoVerifiedState();
                }
                captureWin.WindowStartupLocation = WindowStartupLocation.Manual;
                captureWin.Left = -32000;
                captureWin.Top = -32000;
                captureWin.ShowInTaskbar = false;
                captureWin.Width = 1360;
                captureWin.Height = 920;
                captureWin.Show();
                MainWindow.PumpDispatcher();
                captureWin.UpdateLayout();
                MainWindow.PumpDispatcher();
                MainWindow.RenderWindowContentToPng(captureWin, capturePngPath, 144.0);
                captureWin.Close();
                captureApp.Shutdown(0);
                return 0;
            }

            var app = new Application();
            var mainWindow = new MainWindow(language, toolkitRoot, dryRun, demoAudit, initialNavIndex);
            if (demoCleaning && dryRun)
            {
                mainWindow.ApplyDemoCleaningState();
            }
            else if (demoVerified && dryRun)
            {
                mainWindow.ApplyDemoVerifiedState();
            }
            app.Run(mainWindow);
            return 0;
        }
    }
}
