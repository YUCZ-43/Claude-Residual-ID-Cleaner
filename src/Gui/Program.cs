using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Reflection;
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
        public string Details { get; set; }
        public long SizeBytes { get; set; }

        public Brush StatusBg
        {
            get
            {
                if (StatusTone == "Ready") return MainWindow.BrushBadgeReadyBg;
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
    }

    public sealed class MainWindow : Window
    {
        internal static readonly Brush BrushBgOuter = CreateBrush(30, 30, 30);          // #1E1E1E
        internal static readonly Brush BrushBgChrome = CreateBrush(37, 37, 38);         // #252526
        internal static readonly Brush BrushBgCard = CreateBrush(45, 45, 48);           // #2D2D30
        internal static readonly Brush BrushBgElevated = CreateBrush(51, 51, 55);       // #333337
        internal static readonly Brush BrushBgLog = CreateBrush(22, 22, 24);            // #161618
        internal static readonly Brush BrushBorderSubtle = CreateBrush(62, 62, 66);     // #3E3E42
        internal static readonly Brush BrushAccent = CreateBrush(0, 120, 212);          // #0078D4
        internal static readonly Brush BrushAccentBright = CreateBrush(55, 148, 255);   // #3794FF
        internal static readonly Brush BrushTealAction = CreateBrush(14, 116, 144);     // #0E7490
        internal static readonly Brush BrushDangerAction = CreateBrush(153, 27, 27);    // #991B1B
        internal static readonly Brush BrushNeutralAction = CreateBrush(55, 65, 81);    // #374151
        internal static readonly Brush BrushSafetyBg = CreateBrush(18, 53, 36);         // #123524
        internal static readonly Brush BrushSafetyBorder = CreateBrush(34, 197, 94);    // #22C55E
        internal static readonly Brush BrushSafetyFg = CreateBrush(134, 239, 172);      // #86EFAC
        internal static readonly Brush BrushTextPrimary = CreateBrush(243, 244, 246);   // #F3F4F6
        internal static readonly Brush BrushTextSecondary = CreateBrush(156, 163, 175); // #9CA3AF
        internal static readonly Brush BrushTextMuted = CreateBrush(107, 114, 128);     // #6B7280
        internal static readonly Brush BrushDemoBannerBg = CreateBrush(23, 37, 54);     // #172536
        internal static readonly Brush BrushDemoBannerBorder = CreateBrush(55, 148, 255);

        internal static readonly Brush BrushBadgeReadyBg = CreateBrush(58, 36, 18);
        internal static readonly Brush BrushBadgeReadyBorder = CreateBrush(245, 158, 11);
        internal static readonly Brush BrushBadgeReadyFg = CreateBrush(253, 224, 71);
        internal static readonly Brush BrushBadgeReadOnlyBg = CreateBrush(23, 37, 58);
        internal static readonly Brush BrushBadgeReadOnlyBorder = CreateBrush(59, 130, 246);
        internal static readonly Brush BrushBadgeReadOnlyFg = CreateBrush(147, 197, 253);
        internal static readonly Brush BrushBadgeCleanBg = CreateBrush(18, 53, 36);
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
        private double _lastLogHeight = 115.0;
        private bool _hasScanned;
        private bool _hasPlan;
        private string _planSha256 = string.Empty;
        private int _readyCount;
        private string _lastVerifySummaryText = string.Empty;
        private bool _suppressSelectAllSync;
        private int _busyDepth;

        private readonly ObservableCollection<ResidualGridRow> _allRows = new ObservableCollection<ResidualGridRow>();
        private readonly ObservableCollection<ResidualGridRow> _visibleRows = new ObservableCollection<ResidualGridRow>();
        private readonly List<ResidualAccountIdRecord> _accountIdRecords = new List<ResidualAccountIdRecord>();

        private readonly List<Button> _navButtons = new List<Button>();
        private readonly List<Border> _navIndicators = new List<Border>();
        private readonly List<Border> _metricCards = new List<Border>();
        private readonly List<CheckBox> _scopeCheckboxes = new List<CheckBox>();

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
        private ScrollViewer _aboutPanel;

        private Border _accountIdCard;
        private TextBlock _lblAccountIdCardTitle;
        private TextBlock _lblAccountIdCardSub;
        private TextBox _txtAccountIdValue;
        private Button _btnCopyAccountId;

        private StackPanel _viewScanSection;
        private Border _viewPlanCard;
        private TextBlock _lblPlanViewTitle;
        private TextBlock _lblPlanViewSub;
        private TextBlock _lblPlanShaLabel;
        private TextBox _txtPlanShaValue;
        private Button _btnPlanViewGenerate;
        private Button _btnPlanViewSwitchAccount;
        private Button _btnPlanViewSwitchFull;

        private Border _viewCleanCard;
        private TextBlock _lblCleanViewTitle;
        private TextBlock _lblCleanViewSub;
        private Border _cleanGateBadge;
        private TextBlock _lblCleanGateStatus;
        private Button _btnCleanViewExecute;

        private Border _viewVerifyCard;
        private TextBlock _lblVerifyViewTitle;
        private TextBlock _lblVerifyViewSub;
        private TextBlock _lblVerifySummary;
        private Button _btnVerifyViewRun;
        private Button _btnVerifyViewExport;
        private Button _btnVerifyViewFolder;

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
        private CheckBox _chkSelectAll;

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
            _activeNavIndex = (initialNavIndex >= 0 && initialNavIndex <= 4) ? initialNavIndex : 0;
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
        <Setter Property=""Background"" Value=""#1E1E1E""/>
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""BorderBrush"" Value=""#3E3E42""/>
        <Setter Property=""BorderThickness"" Value=""1""/>
        <Setter Property=""Padding"" Value=""8,5""/>
    </Style>

    <Style TargetType=""Button"">
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""Background"" Value=""#2D2D30""/>
        <Setter Property=""BorderBrush"" Value=""#3E3E42""/>
        <Setter Property=""BorderThickness"" Value=""1""/>
        <Setter Property=""Padding"" Value=""12,7""/>
        <Setter Property=""Cursor"" Value=""Hand""/>
        <Setter Property=""SnapsToDevicePixels"" Value=""True""/>
        <Setter Property=""Template"">
            <Setter.Value>
                <ControlTemplate TargetType=""Button"">
                    <Border x:Name=""Bd""
                            Background=""{TemplateBinding Background}""
                            BorderBrush=""{TemplateBinding BorderBrush}""
                            BorderThickness=""{TemplateBinding BorderThickness}""
                            CornerRadius=""5"">
                        <Grid>
                            <Border x:Name=""HoverOverlay"" Background=""#16FFFFFF"" CornerRadius=""5"" Opacity=""0"" IsHitTestVisible=""False""/>
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
                            <Setter TargetName=""Bd"" Property=""Background"" Value=""#2A2A2E""/>
                            <Setter TargetName=""Bd"" Property=""BorderBrush"" Value=""#3E3E42""/>
                            <Setter TargetName=""Cp"" Property=""Opacity"" Value=""0.55""/>
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
                                CornerRadius=""3""
                                Background=""#252526""
                                BorderBrush=""#52525B""
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
                            <Setter TargetName=""Box"" Property=""Background"" Value=""#0078D4""/>
                            <Setter TargetName=""Box"" Property=""BorderBrush"" Value=""#3794FF""/>
                            <Setter TargetName=""CheckMark"" Property=""Visibility"" Value=""Visible""/>
                        </Trigger>
                        <Trigger Property=""IsMouseOver"" Value=""True"">
                            <Setter TargetName=""Box"" Property=""BorderBrush"" Value=""#3794FF""/>
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
                                Background=""#252526""
                                BorderBrush=""#52525B""
                                BorderThickness=""1""
                                VerticalAlignment=""Top""
                                Margin=""0,2,0,0"">
                            <Ellipse x:Name=""Dot""
                                     Width=""8"" Height=""8""
                                     Fill=""#3794FF""
                                     Visibility=""Collapsed""/>
                        </Border>
                        <ContentPresenter Grid.Column=""1""
                                          Margin=""8,0,0,0""
                                          VerticalAlignment=""Center""
                                          RecognizesAccessKey=""False""/>
                    </Grid>
                    <ControlTemplate.Triggers>
                        <Trigger Property=""IsChecked"" Value=""True"">
                            <Setter TargetName=""Circle"" Property=""BorderBrush"" Value=""#3794FF""/>
                            <Setter TargetName=""Dot"" Property=""Visibility"" Value=""Visible""/>
                        </Trigger>
                        <Trigger Property=""IsMouseOver"" Value=""True"">
                            <Setter TargetName=""Circle"" Property=""BorderBrush"" Value=""#3794FF""/>
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
        <Setter Property=""Background"" Value=""#252526""/>
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
                                            <Border x:Name=""ThumbBd"" Background=""#4B4B52"" CornerRadius=""4"" Margin=""2""/>
                                            <ControlTemplate.Triggers>
                                                <Trigger Property=""IsMouseOver"" Value=""True"">
                                                    <Setter TargetName=""ThumbBd"" Property=""Background"" Value=""#6B7280""/>
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
        <Setter Property=""Background"" Value=""#252526""/>
        <Setter Property=""Foreground"" Value=""#9CA3AF""/>
        <Setter Property=""BorderBrush"" Value=""#3E3E42""/>
        <Setter Property=""BorderThickness"" Value=""0,0,1,1""/>
        <Setter Property=""Padding"" Value=""10,8""/>
        <Setter Property=""FontWeight"" Value=""SemiBold""/>
        <Setter Property=""FontSize"" Value=""12""/>
        <Setter Property=""HorizontalContentAlignment"" Value=""Left""/>
    </Style>

    <Style TargetType=""DataGridRow"">
        <Setter Property=""Background"" Value=""#262629""/>
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""BorderThickness"" Value=""0""/>
        <Setter Property=""MinHeight"" Value=""34""/>
        <Style.Triggers>
            <Trigger Property=""AlternationIndex"" Value=""1"">
                <Setter Property=""Background"" Value=""#2B2B2F""/>
            </Trigger>
            <Trigger Property=""IsMouseOver"" Value=""True"">
                <Setter Property=""Background"" Value=""#323842""/>
            </Trigger>
            <Trigger Property=""IsSelected"" Value=""True"">
                <Setter Property=""Background"" Value=""#1E3A5F""/>
                <Setter Property=""Foreground"" Value=""#F3F4F6""/>
            </Trigger>
        </Style.Triggers>
    </Style>

    <Style TargetType=""DataGridCell"">
        <Setter Property=""BorderThickness"" Value=""0""/>
        <Setter Property=""Padding"" Value=""8,5""/>
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
        <Setter Property=""Background"" Value=""#2D2D30""/>
        <Setter Property=""Foreground"" Value=""#F3F4F6""/>
        <Setter Property=""BorderThickness"" Value=""0""/>
        <Setter Property=""HorizontalGridLinesBrush"" Value=""#333337""/>
        <Setter Property=""VerticalGridLinesBrush"" Value=""#333337""/>
        <Setter Property=""AlternationCount"" Value=""2""/>
        <Setter Property=""RowHeaderWidth"" Value=""0""/>
    </Style>

    <DataTemplate x:Key=""StatusBadgeTemplate"">
        <Border Background=""{Binding StatusBg}""
                BorderBrush=""{Binding StatusBorder}""
                BorderThickness=""1""
                CornerRadius=""10""
                Padding=""8,2""
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

            // 1. Top Studio Header
            var headerBorder = BuildStudioHeader();
            Grid.SetRow(headerBorder, 0);
            shellGrid.Children.Add(headerBorder);

            // 2. Body (Left Sidebar + Main Canvas)
            var bodyGrid = new Grid();
            bodyGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(224) });
            bodyGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            var sidebar = BuildLeftSidebar();
            Grid.SetColumn(sidebar, 0);
            bodyGrid.Children.Add(sidebar);

            var canvasContainer = BuildMainCanvas();
            Grid.SetColumn(canvasContainer, 1);
            bodyGrid.Children.Add(canvasContainer);

            Grid.SetRow(bodyGrid, 1);
            shellGrid.Children.Add(bodyGrid);

            // 3. Footer Status Bar
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
                Padding = new Thickness(18, 12, 18, 12)
            };

            var headerGrid = new Grid();
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            // Left: App Mark + Titles + Safety Pill
            var leftDock = new Grid { VerticalAlignment = VerticalAlignment.Center };
            leftDock.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            leftDock.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

            // Mascot Logo or Geometric Fallback App Mark
            var appMark = new Border
            {
                Width = 44,
                Height = 44,
                CornerRadius = new CornerRadius(9),
                Background = BrushBgCard,
                BorderBrush = BrushAccentBright,
                BorderThickness = new Thickness(1),
                Margin = new Thickness(0, 0, 14, 0),
                VerticalAlignment = VerticalAlignment.Center,
                ClipToBounds = true
            };
            ImageSource mascotImg = LoadMascotImageSource();
            if (mascotImg != null)
            {
                var logoImage = new Image
                {
                    Source = mascotImg,
                    Width = 42,
                    Height = 42,
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
                    Width = 24,
                    Height = 24,
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
                    Width = 24,
                    Height = 24,
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

            var brandPill = new Border
            {
                Background = BrushBgElevated,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(4),
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
            brandPill.Child = _lblBrandName;

            _lblHeaderTitle = new TextBlock
            {
                Foreground = BrushTextPrimary,
                FontSize = 17,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 1, 0, 1),
                VerticalAlignment = VerticalAlignment.Center
            };

            var versionBorder = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(8, 2, 8, 2),
                Margin = new Thickness(10, 2, 8, 2),
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
                FontSize = 11.5,
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

            titleRow.Children.Add(brandPill);
            titleRow.Children.Add(_lblHeaderTitle);
            titleRow.Children.Add(versionBorder);
            titleRow.Children.Add(safetyBorder);
            titleRow.Children.Add(_privilegeBadgeBorder);

            _lblPositioning = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                Margin = new Thickness(0, 4, 0, 0),
                TextWrapping = TextWrapping.Wrap
            };

            titleStack.Children.Add(titleRow);
            titleStack.Children.Add(_lblPositioning);
            Grid.SetColumn(titleStack, 1);
            leftDock.Children.Add(titleStack);

            // Right: On-Demand Admin Restart + Policy Quick Pill + Language Toggle + Safety/About
            var rightControls = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(14, 0, 0, 0)
            };

            _btnRestartAdmin = new Button
            {
                Background = BrushBgCard,
                BorderBrush = BrushBadgeReadyBorder,
                BorderThickness = new Thickness(1),
                Foreground = BrushBadgeReadyFg,
                FontSize = 11.5,
                FontWeight = FontWeights.SemiBold,
                Padding = new Thickness(10, 6, 10, 6),
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
                Padding = new Thickness(10, 6, 10, 6),
                Margin = new Thickness(0, 0, 8, 0)
            };
            _btnPolicyPill.Click += OnPolicyPillClick;

            _btnLangToggle = new Button
            {
                Background = BrushAccent,
                BorderBrush = BrushAccentBright,
                BorderThickness = new Thickness(1),
                Foreground = Brushes.White,
                FontSize = 12,
                FontWeight = FontWeights.Bold,
                Padding = new Thickness(14, 6, 14, 6),
                Margin = new Thickness(0, 0, 8, 0)
            };
            _btnLangToggle.Click += OnLangToggleClick;

            _btnAbout = new Button
            {
                Background = BrushBgElevated,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                Foreground = BrushTextPrimary,
                FontSize = 12,
                FontWeight = FontWeights.SemiBold,
                Padding = new Thickness(12, 6, 12, 6)
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
                Padding = new Thickness(10, 14, 10, 14)
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

            for (int i = 0; i < 5; i++)
            {
                int tabIndex = i;
                var rowGrid = new Grid { Margin = new Thickness(0, 0, 0, 4) };
                var indicator = new Border
                {
                    Width = 3,
                    CornerRadius = new CornerRadius(2),
                    Background = BrushAccentBright,
                    HorizontalAlignment = HorizontalAlignment.Left,
                    Margin = new Thickness(0, 6, 0, 6),
                    Visibility = Visibility.Collapsed
                };
                var navBtn = new Button
                {
                    HorizontalContentAlignment = HorizontalAlignment.Left,
                    Padding = new Thickness(14, 10, 10, 10),
                    Background = Brushes.Transparent,
                    BorderBrush = Brushes.Transparent,
                    BorderThickness = new Thickness(1),
                    Foreground = BrushTextSecondary,
                    FontSize = 12.5,
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

            // Bottom Engine Guardrail Card
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
            var canvasGrid = new Grid { Margin = new Thickness(16, 10, 16, 10) };
            canvasGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Context / Demo Banner
            canvasGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Workspace or About view

            // Context Banner
            _contextBannerBorder = new Border
            {
                Background = _demoAudit ? BrushDemoBannerBg : BrushBgChrome,
                BorderBrush = _demoAudit ? BrushDemoBannerBorder : BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(12, 7, 12, 7),
                Margin = new Thickness(0, 0, 0, 10)
            };
            _lblContextBanner = new TextBlock
            {
                Foreground = _demoAudit ? BrushBadgeReadOnlyFg : BrushTextSecondary,
                FontSize = 12,
                TextWrapping = TextWrapping.Wrap
            };
            _contextBannerBorder.Child = _lblContextBanner;
            Grid.SetRow(_contextBannerBorder, 0);
            canvasGrid.Children.Add(_contextBannerBorder);

            // Workspace Panel (Tabs 0..3)
            _workspacePanel = BuildWorkspacePanel();
            Grid.SetRow(_workspacePanel, 1);
            canvasGrid.Children.Add(_workspacePanel);

            // Safety & About Panel (Tab 4)
            _aboutPanel = BuildSafetyAboutPanel();
            _aboutPanel.Visibility = Visibility.Collapsed;
            Grid.SetRow(_aboutPanel, 1);
            canvasGrid.Children.Add(_aboutPanel);

            return canvasGrid;
        }

        private Grid BuildWorkspacePanel()
        {
            var wsGrid = new Grid();
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 0: Step-specific top view cards + Account ID card
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 1: Shared Action Toolbar + Quick Presets
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star), MinHeight = 160 }); // 2: Horizontal Scrollable DataGrid
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 3: Horizontal GridSplitter
            _logDrawerRow = new RowDefinition { Height = new GridLength(110), MinHeight = 80, MaxHeight = 520 };
            wsGrid.RowDefinitions.Add(_logDrawerRow); // 4: Freely Resizable Log Drawer

            // 0. Stacked Multi-View Stage Host (Tabs 0..3)
            var topViewHost = new StackPanel { Orientation = Orientation.Vertical };

            // --- TAB 0: Scan View (Metrics + Account ID Card + Scope & Policy Cards) ---
            _viewScanSection = new StackPanel { Orientation = Orientation.Vertical };

            var metricsGrid = new Grid { Margin = new Thickness(0, 0, 0, 8) };
            for (int c = 0; c < 4; c++)
            {
                metricsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                if (c < 3)
                {
                    metricsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(10) });
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

            _viewScanSection.Children.Add(metricsGrid);

            // Detected Residual Account IDs Summary Card (Non-Secret UUIDs Only)
            _accountIdCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(12, 8, 12, 8),
                Margin = new Thickness(0, 0, 0, 8)
            };
            var aidGrid = new Grid();
            aidGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            aidGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var aidLeft = new StackPanel { Orientation = Orientation.Vertical };
            var aidHeaderRow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 4) };
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
            _btnCopyAccountId.Margin = new Thickness(12, 0, 0, 0);
            _btnCopyAccountId.VerticalAlignment = VerticalAlignment.Center;
            _btnCopyAccountId.IsEnabled = false;
            _btnCopyAccountId.Click += OnCopyAccountIdClick;

            Grid.SetColumn(aidLeft, 0);
            Grid.SetColumn(_btnCopyAccountId, 1);
            aidGrid.Children.Add(aidLeft);
            aidGrid.Children.Add(_btnCopyAccountId);
            _accountIdCard.Child = aidGrid;
            _viewScanSection.Children.Add(_accountIdCard);

            // Scope Checklist + Policy Selector (2-column card row)
            var topCards = new Grid { Margin = new Thickness(0, 0, 0, 8) };
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.65, GridUnitType.Star) });
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(10) });
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.0, GridUnitType.Star) });

            var scopeCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(12, 8, 12, 8)
            };
            var scopeStack = new StackPanel();
            _lblScopeHeader = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 0, 0, 5)
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
                Padding = new Thickness(12, 8, 12, 8)
            };
            var policyStack = new StackPanel();
            _lblPolicyHeader = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 0, 0, 6)
            };
            policyStack.Children.Add(_lblPolicyHeader);

            _lblPolicyAccountText = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = BrushTextPrimary, FontSize = 11.5 };
            _rbAccountData = new RadioButton { IsChecked = true, Content = _lblPolicyAccountText, Margin = new Thickness(0, 2, 0, 8) };
            _rbAccountData.Checked += OnPolicyRadioChanged;

            _lblPolicyFullText = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = BrushTextPrimary, FontSize = 11.5 };
            _rbFullRemoval = new RadioButton { IsChecked = false, Content = _lblPolicyFullText, Margin = new Thickness(0, 2, 0, 2) };
            _rbFullRemoval.Checked += OnPolicyRadioChanged;

            policyStack.Children.Add(_rbAccountData);
            policyStack.Children.Add(_rbFullRemoval);
            policyCard.Child = policyStack;
            Grid.SetColumn(policyCard, 2);
            topCards.Children.Add(policyCard);

            _viewScanSection.Children.Add(topCards);
            topViewHost.Children.Add(_viewScanSection);

            // --- TAB 1: Plan Preview Dedicated View Card ---
            _viewPlanCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(14, 12, 14, 12),
                Margin = new Thickness(0, 0, 0, 8),
                Visibility = Visibility.Collapsed
            };
            var planStack = new StackPanel();
            _lblPlanViewTitle = new TextBlock { Foreground = BrushTextPrimary, FontSize = 14, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 4) };
            _lblPlanViewSub = new TextBlock { Foreground = BrushTextSecondary, FontSize = 12, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 8) };
            var shaRow = new Grid { Margin = new Thickness(0, 0, 0, 8) };
            shaRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            shaRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            _lblPlanShaLabel = new TextBlock { Foreground = BrushTextSecondary, FontSize = 12, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 10, 0) };
            _txtPlanShaValue = new TextBox
            {
                IsReadOnly = true,
                Background = BrushBgLog,
                Foreground = BrushAccentBright,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                Padding = new Thickness(8, 5, 8, 5),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 12
            };
            Grid.SetColumn(_lblPlanShaLabel, 0);
            Grid.SetColumn(_txtPlanShaValue, 1);
            shaRow.Children.Add(_lblPlanShaLabel);
            shaRow.Children.Add(_txtPlanShaValue);

            var planBtns = new WrapPanel { Orientation = Orientation.Horizontal };
            _btnPlanViewGenerate = CreateActionButton(BrushTealAction, CreateBrush(20, 184, 166), Brushes.White);
            _btnPlanViewGenerate.Click += OnPlanClick;
            _btnPlanViewSwitchAccount = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnPlanViewSwitchAccount.Click += OnPresetAccountClick;
            _btnPlanViewSwitchFull = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnPlanViewSwitchFull.Click += OnPresetFullClick;
            planBtns.Children.Add(_btnPlanViewGenerate);
            planBtns.Children.Add(_btnPlanViewSwitchAccount);
            planBtns.Children.Add(_btnPlanViewSwitchFull);

            planStack.Children.Add(_lblPlanViewTitle);
            planStack.Children.Add(_lblPlanViewSub);
            planStack.Children.Add(shaRow);
            planStack.Children.Add(planBtns);
            _viewPlanCard.Child = planStack;
            topViewHost.Children.Add(_viewPlanCard);

            // --- TAB 2: Safe Cleanup Dedicated Execution Gate Card ---
            _viewCleanCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(14, 12, 14, 12),
                Margin = new Thickness(0, 0, 0, 8),
                Visibility = Visibility.Collapsed
            };
            var cleanStack = new StackPanel();
            _lblCleanViewTitle = new TextBlock { Foreground = BrushTextPrimary, FontSize = 14, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 4) };
            _lblCleanViewSub = new TextBlock { Foreground = BrushTextSecondary, FontSize = 12, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 8) };
            _cleanGateBadge = new Border
            {
                Background = BrushBgLog,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(10, 6, 10, 6),
                Margin = new Thickness(0, 0, 0, 10)
            };
            _lblCleanGateStatus = new TextBlock { Foreground = BrushBadgeReadyFg, FontSize = 12, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap };
            _cleanGateBadge.Child = _lblCleanGateStatus;
            _btnCleanViewExecute = CreateActionButton(BrushDangerAction, CreateBrush(239, 68, 68), Brushes.White);
            _btnCleanViewExecute.IsEnabled = false;
            _btnCleanViewExecute.HorizontalAlignment = HorizontalAlignment.Left;
            _btnCleanViewExecute.Click += OnCleanClick;

            cleanStack.Children.Add(_lblCleanViewTitle);
            cleanStack.Children.Add(_lblCleanViewSub);
            cleanStack.Children.Add(_cleanGateBadge);
            cleanStack.Children.Add(_btnCleanViewExecute);
            _viewCleanCard.Child = cleanStack;
            topViewHost.Children.Add(_viewCleanCard);

            // --- TAB 3: Verify & Reports Dedicated Card ---
            _viewVerifyCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(14, 12, 14, 12),
                Margin = new Thickness(0, 0, 0, 8),
                Visibility = Visibility.Collapsed
            };
            var verStack = new StackPanel();
            _lblVerifyViewTitle = new TextBlock { Foreground = BrushTextPrimary, FontSize = 14, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 4) };
            _lblVerifyViewSub = new TextBlock { Foreground = BrushTextSecondary, FontSize = 12, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 8) };
            _lblVerifySummary = new TextBlock { Foreground = BrushBadgeReadOnlyFg, FontSize = 12, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 8) };
            var verBtns = new WrapPanel { Orientation = Orientation.Horizontal };
            _btnVerifyViewRun = CreateActionButton(BrushAccent, BrushAccentBright, Brushes.White);
            _btnVerifyViewRun.Click += OnVerifyClick;
            _btnVerifyViewExport = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnVerifyViewExport.Click += OnExportSummaryClick;
            _btnVerifyViewFolder = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnVerifyViewFolder.Click += OnOpenFolderClick;
            verBtns.Children.Add(_btnVerifyViewRun);
            verBtns.Children.Add(_btnVerifyViewExport);
            verBtns.Children.Add(_btnVerifyViewFolder);

            verStack.Children.Add(_lblVerifyViewTitle);
            verStack.Children.Add(_lblVerifyViewSub);
            verStack.Children.Add(_lblVerifySummary);
            verStack.Children.Add(verBtns);
            _viewVerifyCard.Child = verStack;
            topViewHost.Children.Add(_viewVerifyCard);

            Grid.SetRow(topViewHost, 0);
            wsGrid.Children.Add(topViewHost);

            // 1. Action Toolbar + Quick Preset Bar
            var toolbarBorder = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(10, 7, 10, 7),
                Margin = new Thickness(0, 0, 0, 8)
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

            var presetRow = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Margin = new Thickness(0, 6, 0, 0),
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
            _btnPresetAccount.Padding = new Thickness(10, 4, 10, 4);
            _btnPresetAccount.FontSize = 11.5;
            _btnPresetAccount.Click += OnPresetAccountClick;

            _btnPresetFull = CreateActionButton(BrushBgElevated, BrushBorderSubtle, BrushTextPrimary);
            _btnPresetFull.Padding = new Thickness(10, 4, 10, 4);
            _btnPresetFull.FontSize = 11.5;
            _btnPresetFull.Click += OnPresetFullClick;

            presetRow.Children.Add(_lblPresetLabel);
            presetRow.Children.Add(_btnPresetAccount);
            presetRow.Children.Add(_btnPresetFull);

            toolbarStack.Children.Add(toolbarGrid);
            toolbarStack.Children.Add(presetRow);
            toolbarBorder.Child = toolbarStack;
            Grid.SetRow(toolbarBorder, 1);
            wsGrid.Children.Add(toolbarBorder);

            // 2. Styled Horizontal-Scrollable Multi-Column DataGrid inside Card Container
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
            Grid.SetRow(gridContainer, 2);
            wsGrid.Children.Add(gridContainer);

            // 3. Horizontal GridSplitter between DataGrid and Live Log Drawer
            _logSplitter = new GridSplitter
            {
                Height = 6,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                VerticalAlignment = VerticalAlignment.Center,
                ResizeDirection = GridResizeDirection.Rows,
                ResizeBehavior = GridResizeBehavior.PreviousAndNext,
                Background = BrushBorderSubtle,
                Margin = new Thickness(0, 4, 0, 4),
                ShowsPreview = true,
                Cursor = Cursors.SizeNS
            };
            Grid.SetRow(_logSplitter, 3);
            wsGrid.Children.Add(_logSplitter);

            // 4. Collapsible & Resizable Live Log Drawer
            _logDrawerPanel = new Border
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Margin = new Thickness(0, 2, 0, 0),
                Padding = new Thickness(10, 8, 10, 8)
            };
            var logGrid = new Grid();
            logGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            logGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

            _lblLogDrawerTitle = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(2, 0, 0, 6)
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
                Padding = new Thickness(8, 6, 8, 6),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 11.5
            };
            Grid.SetRow(_txtLog, 1);
            logGrid.Children.Add(_txtLog);
            _logDrawerPanel.Child = logGrid;

            Grid.SetRow(_logDrawerPanel, 4);
            wsGrid.Children.Add(_logDrawerPanel);

            return wsGrid;
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
                Padding = new Thickness(12, 8, 12, 8)
            };
            var stack = new StackPanel();
            lblTitle = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.SemiBold
            };
            lblValue = new TextBlock
            {
                Foreground = valueBrush,
                FontSize = 21,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 4, 0, 3),
                Text = "0"
            };
            lblSub = new TextBlock
            {
                Foreground = BrushTextMuted,
                FontSize = 11,
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
                Padding = new Thickness(16, 7, 16, 7)
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
            var cb = new CheckBox { IsChecked = true, Margin = new Thickness(0, 3, 0, 3) };
            cb.Checked += OnScopeFilterChanged;
            cb.Unchecked += OnScopeFilterChanged;
            _scopeCheckboxes.Add(cb);
            return cb;
        }

        private static Button CreateActionButton(Brush bg, Brush border, Brush fg)
        {
            return new Button
            {
                Padding = new Thickness(13, 7, 13, 7),
                Margin = new Thickness(0, 2, 7, 2),
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

            if (index == 4)
            {
                _workspacePanel.Visibility = Visibility.Collapsed;
                _aboutPanel.Visibility = Visibility.Visible;
            }
            else
            {
                _aboutPanel.Visibility = Visibility.Collapsed;
                _workspacePanel.Visibility = Visibility.Visible;
                _viewScanSection.Visibility = (index == 0) ? Visibility.Visible : Visibility.Collapsed;
                _viewPlanCard.Visibility = (index == 1) ? Visibility.Visible : Visibility.Collapsed;
                _viewCleanCard.Visibility = (index == 2) ? Visibility.Visible : Visibility.Collapsed;
                _viewVerifyCard.Visibility = (index == 3) ? Visibility.Visible : Visibility.Collapsed;
            }

            UpdatePlanCleanVerifyCards();
            UpdateContextBanner();
        }

        private void UpdateContextBanner()
        {
            var s = Localization.GetStrings(_lang);
            if (_demoAudit && _activeNavIndex != 4)
            {
                _lblContextBanner.Text = s["DemoBanner"];
                return;
            }
            if (_activeNavIndex == 0) _lblContextBanner.Text = s["NavBannerScan"];
            else if (_activeNavIndex == 1) _lblContextBanner.Text = s["NavBannerPlan"];
            else if (_activeNavIndex == 2) _lblContextBanner.Text = s["NavBannerClean"];
            else if (_activeNavIndex == 3) _lblContextBanner.Text = s["NavBannerVerify"];
            else _lblContextBanner.Text = s["NavBannerAbout"];
        }

        private void UpdateLogDrawerVisibility()
        {
            if (_logsExpanded)
            {
                double maxAllowed = ActualHeight > 200 ? Math.Max(110.0, Math.Floor(ActualHeight * 0.60)) : 480.0;
                _logDrawerRow.MinHeight = 80;
                _logDrawerRow.MaxHeight = maxAllowed;
                _logDrawerRow.Height = new GridLength(_lastLogHeight >= 80 ? _lastLogHeight : 115);
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
            UpdatePlanCleanVerifyCards();
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
            UpdatePlanCleanVerifyCards();
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

        private void UpdatePlanCleanVerifyCards()
        {
            if (_txtPlanShaValue == null) return;
            var s = Localization.GetStrings(_lang);
            string policy = GetActivePolicy();
            bool armed = _hasScanned && _hasPlan && _readyCount > 0 && !string.IsNullOrEmpty(_planSha256);

            _txtPlanShaValue.Text = string.IsNullOrEmpty(_planSha256) ? s["PlanShaNone"] : _planSha256;
            _btnClean.IsEnabled = armed;
            if (_btnCleanViewExecute != null)
            {
                _btnCleanViewExecute.IsEnabled = armed;
            }
            if (_lblCleanGateStatus != null)
            {
                if (armed)
                {
                    string shortSha = _planSha256.Length >= 12 ? _planSha256.Substring(0, 12) : _planSha256;
                    _lblCleanGateStatus.Text = string.Format(s["CleanGateReady"], _readyCount, policy, shortSha);
                    _lblCleanGateStatus.Foreground = BrushSafetyFg;
                }
                else
                {
                    _lblCleanGateStatus.Text = s["CleanGateLocked"];
                    _lblCleanGateStatus.Foreground = BrushBadgeReadyFg;
                }
            }
            if (_lblVerifySummary != null)
            {
                _lblVerifySummary.Text = string.IsNullOrEmpty(_lastVerifySummaryText)
                    ? s["VerifySummaryNone"]
                    : _lastVerifySummaryText;
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
            _lblVersionBadge.Text = s["VersionBadge"];
            _lblSafetyPill.Text = s["SafetyPill"];
            _lblPrivilegeBadge.Text = _isElevated ? s["PrivilegeAdmin"] : s["PrivilegeStandard"];
            _lblPositioning.Text = s["Positioning"];
            _btnRestartAdmin.Content = s["BtnRestartAdmin"];
            _btnLangToggle.Content = s["LangButton"];
            _btnAbout.Content = s["AboutButton"];
            UpdatePolicyPillText();

            _lblSidebarSection.Text = s["SidebarSectionTitle"];
            if (_navButtons.Count >= 5)
            {
                _navButtons[0].Content = s["NavScan"];
                _navButtons[1].Content = s["NavPlan"];
                _navButtons[2].Content = s["NavClean"];
                _navButtons[3].Content = s["NavVerify"];
                _navButtons[4].Content = s["NavAbout"];
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

            _lblPlanViewTitle.Text = s["PlanViewTitle"];
            _lblPlanViewSub.Text = s["PlanViewSub"];
            _lblPlanShaLabel.Text = s["PlanShaLabel"];
            _btnPlanViewGenerate.Content = s["BtnPlan"];
            _btnPlanViewSwitchAccount.Content = s["PresetAccountBtn"];
            _btnPlanViewSwitchFull.Content = s["PresetFullBtn"];

            _lblCleanViewTitle.Text = s["CleanViewTitle"];
            _lblCleanViewSub.Text = s["CleanViewSub"];
            _btnCleanViewExecute.Content = s["BtnClean"];

            _lblVerifyViewTitle.Text = s["VerifyViewTitle"];
            _lblVerifyViewSub.Text = s["VerifyViewSub"];
            _btnVerifyViewRun.Content = s["BtnVerify"];
            _btnVerifyViewExport.Content = s["BtnExportSummary"];
            _btnVerifyViewFolder.Content = s["BtnOpenFolder"];

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
            UpdatePlanCleanVerifyCards();
            UpdateContextBanner();

            if (!_hasScanned)
            {
                _lblStatusBar.Text = s["StatusIdle"];
            }
            else if (_demoAudit)
            {
                _lblStatusBar.Text = string.Format(s["StatusScanned"], _allRows.Count, CountActiveRows());
            }
        }

        private static void ClassifyNonReadyToneAndLabel(
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
                if (string.Equals(r.Decision, "Ready", StringComparison.OrdinalIgnoreCase))
                {
                    bool inScope = string.Equals(activePolicy, "FullRemoval", StringComparison.OrdinalIgnoreCase) ||
                                   string.Equals(r.Policy, "AccountData", StringComparison.OrdinalIgnoreCase);
                    r.StatusTone = inScope ? "Ready" : "Excluded";
                    r.Status = inScope ? s["FoundLabel"] : s["ExcludedLabel"];
                }
                else if (r.StatusTone == "ReadOnly")
                {
                    r.Status = s["ReadOnlyLabel"];
                }
                else if (r.StatusTone == "Clean")
                {
                    r.Status = s["CleanLabel"];
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

            AddDemoRow(true, true, "ClaudeCode", "AccountData", "cli-credentials", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude\.credentials.json", s["FoundLabel"], "Ready", "Ready", "[AccountData] Claude OAuth credentials cache", 18432);
            AddDemoRow(true, true, "ClaudeCode", "AccountData", "cli-global", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude.json", s["FoundLabel"], "Ready", "Ready", "[AccountData] Account UUID & auth metadata (.claude.json)", 42190);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-buddy-tokens", "File", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\buddy-tokens.json", s["FoundLabel"], "Ready", "Ready", "[AccountData] Claude Desktop buddy token residual", 12288);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-cache", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Cache", s["FoundLabel"], "Ready", "Ready", "[AccountData] Electron GPU/HTTP cache directory", 124620800);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-network", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Network", s["FoundLabel"], "Ready", "Ready", "[AccountData] Session cookies & network state", 2450112);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-logs", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Local\Claude\logs", s["FoundLabel"], "Ready", "Ready", "[AccountData] Desktop diagnostic log files", 845312);

            AddDemoRow(false, true, "ClaudeCode", "FullRemoval", "npm-claude-code", "NpmPackage", "npm Global Package", @"C:\Users\<USERNAME>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code", s["ExcludedLabel"], "Excluded", "Ready", "[FullRemoval] @anthropic-ai/claude-code package binary (switch to FullRemoval)", 38450120);
            AddDemoRow(false, true, "VsCodeExtensions", "FullRemoval", "vscode-ext", "VsCodeExtension", "VS Code Extension", @"C:\Users\<USERNAME>\.vscode\extensions\anthropic.claude-code-2.1.40", s["ExcludedLabel"], "Excluded", "Ready", "[FullRemoval] anthropic.claude-code IDE extension (switch to FullRemoval)", 48210400);
            AddDemoRow(false, true, "VsCodeExtensions", "FullRemoval", "chrome-native-host", "RegistryKey", "Browser Native Host", @"HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.anthropic.claude_browser_extension", s["ExcludedLabel"], "Excluded", "Ready", "[FullRemoval] Exact HKCU Chrome NativeMessagingHosts key (switch to FullRemoval)", 0);
            AddDemoRow(false, false, "ClaudeDesktop", "FullRemoval", "desktop-msix-data", "Directory", "OS-managed MSIX data", @"C:\Users\<USERNAME>\AppData\Local\Packages\Claude_pzs8sxrjxfjjc", s["ProtectedLabel"], "Protected", "Blocked", "[OS Protected] WindowsApps / MSIX OS-managed junction folder (never direct-deleted)", 0);

            AddDemoRow(false, false, "CredentialManager", "ReadOnly", "cred-manager", "CredentialManager", "Credential Manager", "Claude* targets (count: 2)", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Credential Manager Claude* target count: 2 (secret values never read)", 0);
            AddDemoRow(false, false, "EnvironmentVars", "ReadOnly", "env-0", "EnvVar", "Env (User)", "ANTHROPIC_API_KEY", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Environment variable name only (secret value never read)", 0);

            _hasScanned = true;
            _hasPlan = false;
            _readyCount = 0;
            _btnClean.IsEnabled = false;
            RefreshVisibleRows();
            UpdateMetricCards();
            UpdateAccountIdCard();
            SyncSelectAllCheckbox();

            AppendLog("[DEMO] Populated sanitized mock audit inventory (12 entries; 3 non-secret UUIDs detected).");
            AppendLog("[DEMO] Ready (AccountData): 6 | FullRemoval Scope: 3 | OS Protected: 1 | Read-Only: 2.");
            AppendLog("[DEMO] Clean button remains locked until a verified SHA-256 plan is generated.");
        }

        public void ApplyDemoVerifiedState()
        {
            if (!_dryRun) return;
            var s = Localization.GetStrings(_lang);
            _allRows.Clear();
            _accountIdRecords.Clear();

            AddDemoRow(false, false, "ClaudeCode", "AccountData", "cli-credentials", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude\.credentials.json", s["CleanLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0);
            AddDemoRow(false, false, "ClaudeCode", "AccountData", "cli-global", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude.json", s["CleanLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-buddy-tokens", "File", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\buddy-tokens.json", s["CleanLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-cache", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Cache", s["CleanLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-network", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Network", s["CleanLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-logs", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Local\Claude\logs", s["CleanLabel"], "Clean", "Absent", "[VerifiedAbsent] Removed via Win32 handle-bound deletion", 0);

            AddDemoRow(false, false, "ClaudeDesktop", "FullRemoval", "desktop-msix-data", "Directory", "OS-managed MSIX data", @"C:\Users\<USERNAME>\AppData\Local\Packages\Claude_pzs8sxrjxfjjc", s["ProtectedLabel"], "Protected", "Blocked", "[OS Protected] WindowsApps / MSIX OS-managed junction folder (untouched)", 0);
            AddDemoRow(false, false, "CredentialManager", "ReadOnly", "cred-manager", "CredentialManager", "Credential Manager", "Claude* targets (count: 2)", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Read-only target count (secret values never read)", 0);
            AddDemoRow(false, false, "EnvironmentVars", "ReadOnly", "env-0", "EnvVar", "Env (User)", "ANTHROPIC_API_KEY", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Environment variable name only (secret value never read)", 0);

            _hasScanned = true;
            _hasPlan = false;
            _readyCount = 0;
            _planSha256 = string.Empty;
            _btnClean.IsEnabled = false;
            _lastVerifySummaryText = string.Format(s["StatusVerified"], 6, 0);
            _logsExpanded = true;
            UpdateLogDrawerVisibility();
            RefreshVisibleRows();
            UpdateMetricCards();
            UpdateAccountIdCard();
            UpdatePlanCleanVerifyCards();
            SyncSelectAllCheckbox();
            _lblStatusBar.Text = _lastVerifySummaryText;

            AppendLog("[DEMO] Cleanup applied for Policy=AccountData (6/6 Ready items removed via Win32 handle).");
            AppendLog("[DEMO] VERIFICATION.md updated atomically; 0 cleanable residuals remaining.");
        }

        private void AddDemoRow(bool selected, bool canSelect, string scopeKey, string policy, string itemId, string kind, string category, string path, string status, string tone, string decision, string details, long sizeBytes)
        {
            _allRows.Add(new ResidualGridRow
            {
                Selected = selected,
                CanSelect = canSelect,
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
                if (_allRows[i].StatusTone != "Clean") count++;
            }
            return count;
        }

        private void UpdateMetricCards()
        {
            if (_lblMetricScannedValue == null) return;
            int total = _allRows.Count;
            int active = 0;
            long totalBytes = 0;
            for (int i = 0; i < _allRows.Count; i++)
            {
                ResidualGridRow r = _allRows[i];
                if (r.StatusTone != "Clean") active++;
                if (r.SizeBytes > 0 && r.StatusTone == "Ready")
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
                ThemeStyle = "AdobeDarkSlate",
                HasGridSplitter = (_logSplitter != null),
                HasAccountIdCard = (_accountIdCard != null && _btnCopyAccountId != null),
                HorizontalScrollEnabled = (_gridResults != null && _gridResults.HorizontalScrollBarVisibility == ScrollBarVisibility.Auto),
                AccountIdCount = _accountIdRecords.Count,
                HasWindowIcon = _hasWindowIcon,
                IsElevated = _isElevated,
                PrivilegeBadgeText = (_lblPrivilegeBadge != null) ? _lblPrivilegeBadge.Text : string.Empty,
                HasRestartAdminButton = (_btnRestartAdmin != null)
            };
        }

        private void OnLangToggleClick(object sender, RoutedEventArgs e)
        {
            ToggleLanguage();
        }

        private void OnAboutClick(object sender, RoutedEventArgs e)
        {
            SelectNavTab(4);
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
                // Fallback for .NET Core / PS 7 reflection tests where System.Web.Extensions is absent
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
                    using (var proc = Process.Start(psi))
                    {
                        res.StdOut = proc.StandardOutput.ReadToEnd();
                        res.StdErr = StripAnsiEscapeCodes(proc.StandardError.ReadToEnd());
                        proc.WaitForExit();
                        res.ExitCode = proc.ExitCode;
                    }
                }
                catch (Exception ex)
                {
                    res.ExitCode = -1;
                    res.StdErr = ex.Message;
                    res.StdOut = string.Empty;
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
                UpdatePlanCleanVerifyCards();
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
                UpdatePlanCleanVerifyCards();
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

                ExecuteCleanApply(policy, closeRunningProcesses);
            });
        }

        private void ExecuteCleanApply(string policy, bool closeRunningProcesses)
        {
            var s = Localization.GetStrings(_lang);
            _lblStatusBar.Text = s["StatusApplying"];
            AppendLog("User confirmed SHA256=" + _planSha256 + ". Executing ClaudeCleanup.ps1 -Apply" + (closeRunningProcesses ? " -CloseRunningProcesses" : string.Empty) + "...");

            var applyArgs = new List<string>(new string[]
            {
                "-Apply", "-Policy", policy, "-ApprovedManifestSha256", _planSha256,
                "-Language", _lang, "-OutputFormat", "Json", "-Confirm:$false"
            });
            if (closeRunningProcesses)
            {
                applyArgs.Add("-CloseRunningProcesses");
            }

            RunBackendAsync(applyArgs.ToArray(), delegate(BackendRunResult applyRes)
            {
                if (applyRes.ExitCode != 0)
                {
                    if (!closeRunningProcesses && IsClaudeRunningError(applyRes.StdErr))
                    {
                        if (ConfirmCloseRunningClaudeProcesses(applyRes.StdErr))
                        {
                            AppendLog("User authorized closing running Claude processes; retrying Apply...");
                            ExecuteCleanApply(policy, true);
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
                        UpdatePlanCleanVerifyCards();
                        AppendLog("[WARN] Partial cleanup completed (some files locked); invoking Verify...");
                        MessageBox.Show(this, partialMsg, s["PartialFailureTitle"], MessageBoxButton.OK, MessageBoxImage.Warning);
                        OnVerifyClick(null, null);
                        return;
                    }
                    ShowBackendErrorDialog("[ERROR] Cleanup exited " + applyRes.ExitCode + ": ", applyRes.StdErr);
                    return;
                }
                _hasPlan = false;
                _readyCount = 0;
                _planSha256 = string.Empty;
                UpdatePlanCleanVerifyCards();
                AppendLog("Cleanup complete; invoking automatic Verify...");
                OnVerifyClick(null, null);
            });
        }

        private void OnVerifyClick(object sender, RoutedEventArgs e)
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
                int currentCount = 0;
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
                        currentCount = ((ArrayList)ciObj).Count;
                    }
                }
                _lastVerifySummaryText = string.Format(s["StatusVerified"], checkedCount, currentCount);
                UpdatePlanCleanVerifyCards();
                _lblStatusBar.Text = _lastVerifySummaryText;
                AppendLog(string.Format("Verify finished: checked={0}, remaining={1}.", checkedCount, currentCount));
            });
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
                    sb.AppendLine("# claude-cleanup Demo Audit Report (Sanitized)");
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
                PromptOpenExportedAudit(targetPath, s);
            });
        }

        private void PromptOpenExportedAudit(string exportedPath, Dictionary<string, string> s)
        {
            _lblStatusBar.Text = string.Format(s["StatusExported"], exportedPath);
            AppendLog("Exported sanitized AUDIT report: " + exportedPath);
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
                else if (string.Equals(a, "--demo-verified", StringComparison.OrdinalIgnoreCase))
                {
                    demoVerified = true;
                }
                else if (string.Equals(a, "--nav", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                {
                    int parsedNav;
                    if (int.TryParse(args[++i], out parsedNav))
                    {
                        initialNavIndex = (parsedNav >= 0 && parsedNav <= 4) ? parsedNav : 0;
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
                if (demoVerified && dryRun)
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
                if (demoVerified && dryRun)
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
            app.Run(mainWindow);
            return 0;
        }
    }
}
