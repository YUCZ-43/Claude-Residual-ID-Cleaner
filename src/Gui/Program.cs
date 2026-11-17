using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace ClaudeResidualIdCleaner
{
    public sealed class ResidualGridRow
    {
        public bool Selected { get; set; }
        public bool CanSelect { get; set; }
        public string ScopeKey { get; set; }
        public string Policy { get; set; }
        public string ItemId { get; set; }
        public string Kind { get; set; }
        public string Category { get; set; }
        public string PathOrPackage { get; set; }
        public string Status { get; set; }
        public string StatusTone { get; set; }
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
                return MainWindow.BrushBadgeProtectedFg;
            }
        }
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
        internal static readonly Brush BrushBadgeProtectedBg = CreateBrush(46, 46, 52);
        internal static readonly Brush BrushBadgeProtectedBorder = CreateBrush(107, 114, 128);
        internal static readonly Brush BrushBadgeProtectedFg = CreateBrush(209, 213, 219);

        private string _lang;
        private string _toolkitRoot;
        private readonly bool _dryRun;
        private readonly bool _demoAudit;
        private int _activeNavIndex;
        private bool _logsExpanded;
        private bool _hasScanned;
        private bool _hasPlan;
        private string _planSha256 = string.Empty;
        private int _readyCount;

        private readonly ObservableCollection<ResidualGridRow> _allRows = new ObservableCollection<ResidualGridRow>();
        private readonly ObservableCollection<ResidualGridRow> _visibleRows = new ObservableCollection<ResidualGridRow>();

        private readonly List<Button> _navButtons = new List<Button>();
        private readonly List<Border> _navIndicators = new List<Border>();
        private readonly List<Border> _metricCards = new List<Border>();
        private readonly List<CheckBox> _scopeCheckboxes = new List<CheckBox>();

        private TextBlock _lblBrandName;
        private TextBlock _lblHeaderTitle;
        private TextBlock _lblVersionBadge;
        private TextBlock _lblSafetyPill;
        private TextBlock _lblPositioning;
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

        private DataGrid _gridResults;
        private DataGridCheckBoxColumn _colSelect;
        private DataGridTextColumn _colCategory;
        private DataGridTextColumn _colPath;
        private DataGridTemplateColumn _colStatus;
        private DataGridTextColumn _colDetails;
        private TextBlock _lblGridEmptyHint;

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
            _activeNavIndex = (initialNavIndex >= 0 && initialNavIndex <= 4) ? initialNavIndex : 0;
            _logsExpanded = demoAudit;
            _toolkitRoot = ResolveToolkitRoot(toolkitRootOverride);

            Width = 1320;
            Height = 840;
            MinWidth = 1040;
            MinHeight = 700;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = BrushBgOuter;
            Foreground = BrushTextPrimary;
            FontFamily = new FontFamily("Microsoft YaHei UI, Segoe UI");
            FontSize = 12.5;
            UseLayoutRounding = true;
            SnapsToDevicePixels = true;
            TextOptions.SetTextFormattingMode(this, TextFormattingMode.Display);
            TextOptions.SetTextRenderingMode(this, TextRenderingMode.Grayscale);

            ApplyDarkResources();
            BuildLayout();
            if (_demoAudit)
            {
                PopulateDemoAuditData();
            }
            ApplyLanguage(_lang);
            SelectNavTab(_activeNavIndex);
            UpdateLogDrawerVisibility();
            UpdateMetricCards();
            AppendLog("Toolkit root: " + (string.IsNullOrEmpty(_toolkitRoot) ? "<not resolved>" : _toolkitRoot));
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
                HorizontalAlignment=""Left"">
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

            // Geometric App Mark Badge
            var appMark = new Border
            {
                Width = 42,
                Height = 42,
                CornerRadius = new CornerRadius(8),
                Background = BrushAccent,
                BorderBrush = BrushAccentBright,
                BorderThickness = new Thickness(1),
                Margin = new Thickness(0, 0, 14, 0),
                VerticalAlignment = VerticalAlignment.Center
            };
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
                Margin = new Thickness(0, 2, 0, 2),
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblSafetyPill = new TextBlock
            {
                Foreground = BrushSafetyFg,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold
            };
            safetyBorder.Child = _lblSafetyPill;

            titleRow.Children.Add(brandPill);
            titleRow.Children.Add(_lblHeaderTitle);
            titleRow.Children.Add(versionBorder);
            titleRow.Children.Add(safetyBorder);

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

            // Right: Policy Quick Pill + Language Toggle + Safety/About
            var rightControls = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(14, 0, 0, 0)
            };

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
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 0: 4 KPI Metric Cards
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 1: Scope + Policy 2-col row
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // 2: Action Toolbar
            wsGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // 3: DataGrid
            _logDrawerRow = new RowDefinition { Height = GridLength.Auto };
            wsGrid.RowDefinitions.Add(_logDrawerRow); // 4: Collapsible Log Drawer

            // 0. 4 KPI Metric Summary Cards
            var metricsGrid = new Grid { Margin = new Thickness(0, 0, 0, 10) };
            for (int c = 0; c < 4; c++)
            {
                metricsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                if (c < 3)
                {
                    metricsGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(12) });
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

            Grid.SetRow(metricsGrid, 0);
            wsGrid.Children.Add(metricsGrid);

            // 1. Scope Checklist + Policy Selector (2-column card row)
            var topCards = new Grid { Margin = new Thickness(0, 0, 0, 10) };
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.65, GridUnitType.Star) });
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(12) });
            topCards.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.0, GridUnitType.Star) });

            var scopeCard = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(14, 10, 14, 10)
            };
            var scopeStack = new StackPanel();
            _lblScopeHeader = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 0, 0, 7)
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
                Padding = new Thickness(14, 10, 14, 10)
            };
            var policyStack = new StackPanel();
            _lblPolicyHeader = new TextBlock
            {
                Foreground = BrushTextSecondary,
                FontSize = 11.5,
                FontWeight = FontWeights.Bold,
                Margin = new Thickness(0, 0, 0, 8)
            };
            policyStack.Children.Add(_lblPolicyHeader);

            _lblPolicyAccountText = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = BrushTextPrimary, FontSize = 12 };
            _rbAccountData = new RadioButton { IsChecked = true, Content = _lblPolicyAccountText, Margin = new Thickness(0, 2, 0, 10) };
            _rbAccountData.Checked += OnPolicyRadioChanged;

            _lblPolicyFullText = new TextBlock { TextWrapping = TextWrapping.Wrap, Foreground = BrushTextPrimary, FontSize = 12 };
            _rbFullRemoval = new RadioButton { IsChecked = false, Content = _lblPolicyFullText, Margin = new Thickness(0, 2, 0, 2) };
            _rbFullRemoval.Checked += OnPolicyRadioChanged;

            policyStack.Children.Add(_rbAccountData);
            policyStack.Children.Add(_rbFullRemoval);
            policyCard.Child = policyStack;
            Grid.SetColumn(policyCard, 2);
            topCards.Children.Add(policyCard);

            Grid.SetRow(topCards, 1);
            wsGrid.Children.Add(topCards);

            // 2. Action Toolbar
            var toolbarBorder = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(10, 7, 10, 7),
                Margin = new Thickness(0, 0, 0, 10)
            };
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
            toolbarBorder.Child = toolbarGrid;
            Grid.SetRow(toolbarBorder, 2);
            wsGrid.Children.Add(toolbarBorder);

            // 3. Styled Multi-Column DataGrid inside Card Container
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
                IsReadOnly = false,
                HeadersVisibility = DataGridHeadersVisibility.Column,
                GridLinesVisibility = DataGridGridLinesVisibility.Horizontal,
                ItemsSource = _visibleRows
            };

            var ellipsisTextStyle = new Style(typeof(TextBlock));
            ellipsisTextStyle.Setters.Add(new Setter(TextBlock.TextTrimmingProperty, TextTrimming.CharacterEllipsis));

            var selectBinding = new Binding("Selected") { UpdateSourceTrigger = UpdateSourceTrigger.PropertyChanged };
            _colSelect = new DataGridCheckBoxColumn { Binding = selectBinding, Width = 70 };
            _colCategory = new DataGridTextColumn { Binding = new Binding("Category"), IsReadOnly = true, Width = 148, ElementStyle = ellipsisTextStyle };
            _colPath = new DataGridTextColumn { Binding = new Binding("PathOrPackage"), IsReadOnly = true, Width = new DataGridLength(1.45, DataGridLengthUnitType.Star), ElementStyle = ellipsisTextStyle };
            _colStatus = new DataGridTemplateColumn
            {
                Width = 156,
                IsReadOnly = true,
                CellTemplate = (DataTemplate)Resources["StatusBadgeTemplate"]
            };
            _colDetails = new DataGridTextColumn { Binding = new Binding("Details"), IsReadOnly = true, Width = new DataGridLength(1.25, DataGridLengthUnitType.Star), ElementStyle = ellipsisTextStyle };

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

            // 4. Collapsible Live Log Drawer
            _logDrawerPanel = new Border
            {
                Background = BrushBgChrome,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Margin = new Thickness(0, 10, 0, 0),
                Padding = new Thickness(10, 8, 10, 8)
            };
            var logGrid = new Grid();
            logGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            logGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(78) });

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

        private Border CreateMetricCard(out TextBlock lblTitle, out TextBlock lblValue, out TextBlock lblSub, Brush valueBrush)
        {
            var card = new Border
            {
                Background = BrushBgCard,
                BorderBrush = BrushBorderSubtle,
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(6),
                Padding = new Thickness(14, 11, 14, 11)
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
            }

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
            _logDrawerPanel.Visibility = _logsExpanded ? Visibility.Visible : Visibility.Collapsed;
        }

        private void OnToggleLogsClick(object sender, RoutedEventArgs e)
        {
            _logsExpanded = !_logsExpanded;
            UpdateLogDrawerVisibility();
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
            _lblPositioning.Text = s["Positioning"];
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

            _colSelect.Header = s["ColSelect"];
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

        private void RelocalizeExistingRows(Dictionary<string, string> s)
        {
            for (int i = 0; i < _allRows.Count; i++)
            {
                ResidualGridRow r = _allRows[i];
                if (r.StatusTone == "Ready") r.Status = s["FoundLabel"];
                else if (r.StatusTone == "ReadOnly") r.Status = s["ReadOnlyLabel"];
                else if (r.StatusTone == "Clean") r.Status = s["CleanLabel"];
                else r.Status = s["ProtectedLabel"];
            }
        }

        private void PopulateDemoAuditData()
        {
            var s = Localization.GetStrings(_lang);
            _allRows.Clear();

            AddDemoRow(true, true, "ClaudeCode", "AccountData", "cli-credentials", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude\.credentials.json", s["FoundLabel"], "Ready", "Ready", "[AccountData] Confirmed Claude auth credentials cache", 18432);
            AddDemoRow(false, false, "ClaudeCode", "FullRemoval", "cli-user-json", "File", "Claude Code CLI", @"C:\Users\<USERNAME>\.claude.json", s["ProtectedLabel"], "Protected", "ReviewOnly", "[AccountData] Preserved by AccountData; ReviewOnly under FullRemoval", 42190);
            AddDemoRow(true, true, "ClaudeCode", "FullRemoval", "npm-claude-code", "NpmPackage", "npm Global Package", @"C:\Users\<USERNAME>\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code", s["FoundLabel"], "Ready", "Ready", "[FullRemoval] @anthropic-ai/claude-code package residue", 38450120);

            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-cache", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Cache", s["FoundLabel"], "Ready", "Ready", "[AccountData] Electron GPU/HTTP cache directory", 124620800);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-network", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Network", s["FoundLabel"], "Ready", "Ready", "[AccountData] Session cookies & network state", 2450112);
            AddDemoRow(true, true, "ClaudeDesktop", "AccountData", "desktop-logs", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Local\Claude\logs", s["FoundLabel"], "Ready", "Ready", "[AccountData] Desktop diagnostic log files", 845312);
            AddDemoRow(false, false, "ClaudeDesktop", "AccountData", "desktop-local-storage", "Directory", "Claude Desktop", @"C:\Users\<USERNAME>\AppData\Roaming\Claude\Local Storage", s["ProtectedLabel"], "Protected", "ReviewOnly", "[AccountData] Protected mixed storage (preserved by default)", 15820000);

            AddDemoRow(true, true, "VsCodeExtensions", "FullRemoval", "vscode-ext", "VsCodeExtension", "VS Code Extension", @"C:\Users\<USERNAME>\.vscode\extensions\anthropic.claude-code-2.1.40", s["FoundLabel"], "Ready", "Ready", "[FullRemoval] anthropic.claude-code extension cache", 48210400);
            AddDemoRow(true, true, "VsCodeExtensions", "FullRemoval", "chrome-native-host", "RegistryKey", "Browser Native Host", @"HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.anthropic.claude_browser_extension", s["FoundLabel"], "Ready", "Ready", "[FullRemoval] Exact HKCU Chrome NativeMessagingHosts key", 0);

            AddDemoRow(false, false, "CredentialManager", "ReadOnly", "cred-manager", "CredentialManager", "Credential Manager", "Claude* targets (count: 2)", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Credential Manager Claude* target count: 2 (secret values never read)", 0);
            AddDemoRow(false, false, "EnvironmentVars", "ReadOnly", "env-0", "EnvVar", "Env (User)", "ANTHROPIC_API_KEY", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Environment variable name only (secret value never read)", 0);
            AddDemoRow(false, false, "EnvironmentVars", "ReadOnly", "env-1", "EnvVar", "Env (User)", "CLAUDE_CODE_USE_BEDROCK", s["ReadOnlyLabel"], "ReadOnly", "ReadOnly", "Environment variable name only (secret value never read)", 0);

            _hasScanned = true;
            _hasPlan = false;
            _readyCount = 0;
            _btnClean.IsEnabled = false;
            RefreshVisibleRows();
            UpdateMetricCards();

            AppendLog("[DEMO] Populated sanitized mock audit inventory (12 entries; zero host disk access).");
            AppendLog("[DEMO] Ready targets: 7 | Protected/ReviewOnly: 2 | Read-Only Audit: 3.");
            AppendLog("[DEMO] Clean button remains locked until a verified SHA-256 plan is generated.");
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
                ThemeStyle = "AdobeDarkSlate"
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
            _btnScan.IsEnabled = !busy;
            _btnPlan.IsEnabled = !busy;
            _btnVerify.IsEnabled = !busy;
            _btnLangToggle.IsEnabled = !busy;
            _btnExportSummary.IsEnabled = !busy;
            _btnPolicyPill.IsEnabled = !busy;
            _btnClean.IsEnabled = (!busy) && _hasScanned && _hasPlan && (_readyCount > 0);
        }

        private void AppendLog(string message)
        {
            if (_txtLog == null) return;
            string line = string.Format("[{0}] {1}{2}", DateTime.Now.ToString("HH:mm:ss"), message, Environment.NewLine);
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
                    using (var proc = Process.Start(psi))
                    {
                        res.StdOut = proc.StandardOutput.ReadToEnd();
                        res.StdErr = proc.StandardError.ReadToEnd();
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
                    AppendLog("[ERROR] Scan failed: " + res.StdErr);
                    MessageBox.Show(this, res.StdErr, Title, MessageBoxButton.OK, MessageBoxImage.Error);
                    return;
                }

                var doc = ParseJsonObject(res.StdOut);
                _allRows.Clear();
                int activeCount = 0;

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
                        if (ready) activeCount++;

                        _allRows.Add(new ResidualGridRow
                        {
                            Selected = ready,
                            CanSelect = ready,
                            ScopeKey = ClassifyScope(id, cat, path),
                            Policy = policy,
                            ItemId = id,
                            Kind = kind,
                            Category = cat,
                            PathOrPackage = path,
                            Status = ready ? s["FoundLabel"] : s["ProtectedLabel"],
                            StatusTone = ready ? "Ready" : "Protected",
                            Decision = decision,
                            Details = string.Format("[{0}] {1}", policy, reason),
                            SizeBytes = sizeBytes
                        });
                    }
                }

                object sumObj;
                if (doc.TryGetValue("Summary", out sumObj) && sumObj is Dictionary<string, object>)
                {
                    var sumDict = (Dictionary<string, object>)sumObj;
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
                _lblStatusBar.Text = string.Format(s["StatusScanned"], _allRows.Count, activeCount);
                AppendLog(string.Format("Scan finished: {0} total entries inspected.", _allRows.Count));
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
                    AppendLog("[ERROR] Plan failed: " + res.StdErr);
                    MessageBox.Show(this, res.StdErr, Title, MessageBoxButton.OK, MessageBoxImage.Error);
                    return;
                }

                var planDoc = ParseJsonObject(res.StdOut);
                _planSha256 = GetDictString(planDoc, "Sha256");
                _readyCount = GetDictInt(planDoc, "Ready");
                _hasPlan = !string.IsNullOrEmpty(_planSha256);

                string shortSha = _planSha256.Length >= 12 ? _planSha256.Substring(0, 12) : _planSha256;
                _lblStatusBar.Text = string.Format(s["StatusPlanned"], _readyCount, shortSha);
                AppendLog(string.Format("CLEANUP-PLAN.md written | Ready={0} | SHA256={1}", _readyCount, _planSha256));
            });
        }

        private void OnCleanClick(object sender, RoutedEventArgs e)
        {
            if (_demoAudit) return;
            if (!EnsureBackend()) return;
            var s = Localization.GetStrings(_lang);
            if (!_hasScanned || !_hasPlan || string.IsNullOrEmpty(_planSha256)) return;

            string policy = (_rbFullRemoval.IsChecked == true) ? "FullRemoval" : "AccountData";
            AppendLog("Running -WhatIf preview before confirmation dialog...");

            RunBackendAsync(new string[] { "-Apply", "-Policy", policy, "-ApprovedManifestSha256", _planSha256, "-Language", _lang, "-OutputFormat", "Json", "-WhatIf" }, delegate(BackendRunResult previewRes)
            {
                if (previewRes.ExitCode != 0)
                {
                    AppendLog("[ERROR] Preview failed: " + previewRes.StdErr);
                    MessageBox.Show(this, previewRes.StdErr, Title, MessageBoxButton.OK, MessageBoxImage.Error);
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

                _lblStatusBar.Text = s["StatusApplying"];
                AppendLog("User confirmed SHA256=" + _planSha256 + ". Executing ClaudeCleanup.ps1 -Apply...");
                RunBackendAsync(new string[] { "-Apply", "-Policy", policy, "-ApprovedManifestSha256", _planSha256, "-Language", _lang, "-OutputFormat", "Json", "-Confirm:$false" }, delegate(BackendRunResult applyRes)
                {
                    if (applyRes.ExitCode != 0)
                    {
                        AppendLog("[ERROR] Cleanup exited " + applyRes.ExitCode + ": " + applyRes.StdErr);
                        MessageBox.Show(this, applyRes.StdErr, Title, MessageBoxButton.OK, MessageBoxImage.Error);
                        return;
                    }
                    _hasPlan = false;
                    _readyCount = 0;
                    AppendLog("Cleanup complete; invoking automatic Verify...");
                    OnVerifyClick(null, null);
                });
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
                    AppendLog("[ERROR] Verify failed: " + res.StdErr);
                    MessageBox.Show(this, res.StdErr, Title, MessageBoxButton.OK, MessageBoxImage.Error);
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
                _lblStatusBar.Text = string.Format(s["StatusVerified"], checkedCount, currentCount);
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
            if (_demoAudit)
            {
                MessageBox.Show(this, s["DemoPlanNotice"], Title, MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            if (!EnsureBackend()) return;
            RunBackendAsync(new string[] { "-Audit", "-Language", _lang, "-SaveAuditReport", "-OutputFormat", "Json" }, delegate(BackendRunResult res)
            {
                if (res.ExitCode != 0)
                {
                    MessageBox.Show(this, res.StdErr, Title, MessageBoxButton.OK, MessageBoxImage.Error);
                    return;
                }
                string auditPath = Path.Combine(_toolkitRoot, "AUDIT.md");
                _lblStatusBar.Text = string.Format(s["StatusExported"], auditPath);
                AppendLog("Exported AUDIT.md: " + auditPath);
            });
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
                captureWin.WindowStartupLocation = WindowStartupLocation.Manual;
                captureWin.Left = -32000;
                captureWin.Top = -32000;
                captureWin.ShowInTaskbar = false;
                captureWin.Width = 1360;
                captureWin.Height = 860;
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
