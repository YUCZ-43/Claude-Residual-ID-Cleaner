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
using System.Windows.Media;

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
        public string Decision { get; set; }
        public string Details { get; set; }
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
    }

    public sealed class MainWindow : Window
    {
        private string _lang;
        private string _toolkitRoot;
        private readonly bool _dryRun;
        private bool _hasScanned;
        private bool _hasPlan;
        private string _planSha256 = string.Empty;
        private int _readyCount;

        private readonly ObservableCollection<ResidualGridRow> _allRows = new ObservableCollection<ResidualGridRow>();
        private readonly ObservableCollection<ResidualGridRow> _visibleRows = new ObservableCollection<ResidualGridRow>();

        private TextBlock _lblHeaderTitle;
        private TextBlock _lblVersionBadge;
        private TextBlock _lblSafetyPill;
        private TextBlock _lblPositioning;
        private Button _btnLangToggle;
        private Button _btnAbout;

        private GroupBox _grpScope;
        private CheckBox _chkCli;
        private CheckBox _chkDesktop;
        private CheckBox _chkVsCode;
        private CheckBox _chkCred;
        private CheckBox _chkEnv;

        private GroupBox _grpPolicy;
        private RadioButton _rbAccountData;
        private RadioButton _rbFullRemoval;

        private Button _btnScan;
        private Button _btnPlan;
        private Button _btnClean;
        private Button _btnVerify;
        private Button _btnOpenFolder;
        private Button _btnExportSummary;

        private DataGrid _gridResults;
        private DataGridCheckBoxColumn _colSelect;
        private DataGridTextColumn _colCategory;
        private DataGridTextColumn _colPath;
        private DataGridTextColumn _colStatus;
        private DataGridTextColumn _colDetails;

        private TextBox _txtLog;
        private TextBlock _lblStatusBar;

        public MainWindow(string initialLanguage, string toolkitRootOverride, bool dryRun)
        {
            _lang = string.IsNullOrEmpty(initialLanguage)
                ? Localization.DetectDefaultLanguage()
                : initialLanguage;
            _dryRun = dryRun;
            _toolkitRoot = ResolveToolkitRoot(toolkitRootOverride);

            Width = 1080;
            Height = 760;
            MinWidth = 920;
            MinHeight = 660;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = new SolidColorBrush(Color.FromRgb(244, 246, 250));
            FontFamily = new FontFamily("Microsoft YaHei UI");
            FontSize = 12.5;

            BuildLayout();
            ApplyLanguage(_lang);
            AppendLog("Toolkit root: " + (string.IsNullOrEmpty(_toolkitRoot) ? "<not resolved>" : _toolkitRoot));
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
            var rootGrid = new Grid();
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Header
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Scope + Policy
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Action Toolbar
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(2, GridUnitType.Star) }); // Results Grid
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }); // Log Drawer
            rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto }); // Status Bar

            // 1. Header Banner
            var headerBorder = new Border
            {
                Background = new SolidColorBrush(Color.FromRgb(22, 34, 58)),
                Padding = new Thickness(18, 12, 18, 12)
            };
            var headerGrid = new Grid();
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var headerLeft = new StackPanel { Orientation = Orientation.Vertical };
            var titleRow = new StackPanel { Orientation = Orientation.Horizontal };
            _lblHeaderTitle = new TextBlock
            {
                Foreground = Brushes.White,
                FontSize = 18,
                FontWeight = FontWeights.Bold,
                VerticalAlignment = VerticalAlignment.Center
            };
            var versionBorder = new Border
            {
                Background = new SolidColorBrush(Color.FromRgb(51, 65, 85)),
                CornerRadius = new CornerRadius(4),
                Padding = new Thickness(8, 2, 8, 2),
                Margin = new Thickness(12, 0, 0, 0),
                VerticalAlignment = VerticalAlignment.Center
            };
            _lblVersionBadge = new TextBlock
            {
                Foreground = new SolidColorBrush(Color.FromRgb(226, 232, 240)),
                FontSize = 11.5
            };
            versionBorder.Child = _lblVersionBadge;
            titleRow.Children.Add(_lblHeaderTitle);
            titleRow.Children.Add(versionBorder);

            var pillBorder = new Border
            {
                Background = new SolidColorBrush(Color.FromRgb(20, 83, 45)),
                BorderBrush = new SolidColorBrush(Color.FromRgb(74, 222, 128)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(12),
                Padding = new Thickness(10, 3, 10, 3),
                Margin = new Thickness(0, 6, 0, 4),
                HorizontalAlignment = HorizontalAlignment.Left
            };
            _lblSafetyPill = new TextBlock
            {
                Foreground = new SolidColorBrush(Color.FromRgb(187, 247, 208)),
                FontSize = 12,
                FontWeight = FontWeights.SemiBold
            };
            pillBorder.Child = _lblSafetyPill;

            _lblPositioning = new TextBlock
            {
                Foreground = new SolidColorBrush(Color.FromRgb(203, 213, 225)),
                FontSize = 12,
                TextWrapping = TextWrapping.Wrap
            };

            headerLeft.Children.Add(titleRow);
            headerLeft.Children.Add(pillBorder);
            headerLeft.Children.Add(_lblPositioning);

            var headerRight = new StackPanel
            {
                Orientation = Orientation.Vertical,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(14, 0, 0, 0)
            };
            _btnLangToggle = new Button
            {
                Padding = new Thickness(14, 7, 14, 7),
                Background = new SolidColorBrush(Color.FromRgb(37, 99, 235)),
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            _btnLangToggle.Click += OnLangToggleClick;

            _btnAbout = new Button
            {
                Padding = new Thickness(10, 5, 10, 5),
                Margin = new Thickness(0, 6, 0, 0),
                Background = new SolidColorBrush(Color.FromRgb(51, 65, 85)),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
            _btnAbout.Click += OnAboutClick;

            headerRight.Children.Add(_btnLangToggle);
            headerRight.Children.Add(_btnAbout);

            Grid.SetColumn(headerLeft, 0);
            Grid.SetColumn(headerRight, 1);
            headerGrid.Children.Add(headerLeft);
            headerGrid.Children.Add(headerRight);
            headerBorder.Child = headerGrid;
            Grid.SetRow(headerBorder, 0);
            rootGrid.Children.Add(headerBorder);

            // 2. Scope + Policy Panel
            var topPanels = new Grid { Margin = new Thickness(14, 10, 14, 6) };
            topPanels.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(2.2, GridUnitType.Star) });
            topPanels.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(12) });
            topPanels.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1.0, GridUnitType.Star) });

            _grpScope = new GroupBox { Padding = new Thickness(8, 6, 8, 6), Background = Brushes.White };
            var scopeStack = new StackPanel();
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
            _grpScope.Content = scopeStack;
            Grid.SetColumn(_grpScope, 0);
            topPanels.Children.Add(_grpScope);

            _grpPolicy = new GroupBox { Padding = new Thickness(8, 6, 8, 6), Background = Brushes.White };
            var policyStack = new StackPanel();
            _rbAccountData = new RadioButton { IsChecked = true, Margin = new Thickness(2, 6, 2, 10) };
            _rbFullRemoval = new RadioButton { IsChecked = false, Margin = new Thickness(2, 4, 2, 4) };
            policyStack.Children.Add(_rbAccountData);
            policyStack.Children.Add(_rbFullRemoval);
            _grpPolicy.Content = policyStack;
            Grid.SetColumn(_grpPolicy, 2);
            topPanels.Children.Add(_grpPolicy);

            Grid.SetRow(topPanels, 1);
            rootGrid.Children.Add(topPanels);

            // 3. Action Toolbar
            var toolbarBorder = new Border
            {
                Margin = new Thickness(14, 2, 14, 8),
                Padding = new Thickness(8),
                Background = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromRgb(226, 232, 240)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(4)
            };
            var toolbarGrid = new Grid();
            toolbarGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            toolbarGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var mainActions = new WrapPanel { Orientation = Orientation.Horizontal };
            _btnScan = CreateActionButton(Color.FromRgb(37, 99, 235), Brushes.White);
            _btnScan.Click += OnScanClick;

            _btnPlan = CreateActionButton(Color.FromRgb(13, 148, 136), Brushes.White);
            _btnPlan.Click += OnPlanClick;

            _btnClean = CreateActionButton(Color.FromRgb(185, 28, 28), Brushes.White);
            _btnClean.IsEnabled = false;
            _btnClean.Click += OnCleanClick;

            _btnVerify = CreateActionButton(Color.FromRgb(71, 85, 105), Brushes.White);
            _btnVerify.Click += OnVerifyClick;

            mainActions.Children.Add(_btnScan);
            mainActions.Children.Add(_btnPlan);
            mainActions.Children.Add(_btnClean);
            mainActions.Children.Add(_btnVerify);

            var utilActions = new WrapPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
            _btnOpenFolder = CreateActionButton(Color.FromRgb(241, 245, 249), Brushes.Black);
            _btnOpenFolder.BorderBrush = new SolidColorBrush(Color.FromRgb(203, 213, 225));
            _btnOpenFolder.BorderThickness = new Thickness(1);
            _btnOpenFolder.Click += OnOpenFolderClick;

            _btnExportSummary = CreateActionButton(Color.FromRgb(241, 245, 249), Brushes.Black);
            _btnExportSummary.BorderBrush = new SolidColorBrush(Color.FromRgb(203, 213, 225));
            _btnExportSummary.BorderThickness = new Thickness(1);
            _btnExportSummary.Click += OnExportSummaryClick;

            utilActions.Children.Add(_btnOpenFolder);
            utilActions.Children.Add(_btnExportSummary);

            Grid.SetColumn(mainActions, 0);
            Grid.SetColumn(utilActions, 1);
            toolbarGrid.Children.Add(mainActions);
            toolbarGrid.Children.Add(utilActions);
            toolbarBorder.Child = toolbarGrid;
            Grid.SetRow(toolbarBorder, 2);
            rootGrid.Children.Add(toolbarBorder);

            // 4. Center Results DataGrid
            _gridResults = new DataGrid
            {
                Margin = new Thickness(14, 0, 14, 8),
                AutoGenerateColumns = false,
                CanUserAddRows = false,
                CanUserDeleteRows = false,
                IsReadOnly = false,
                HeadersVisibility = DataGridHeadersVisibility.Column,
                GridLinesVisibility = DataGridGridLinesVisibility.Horizontal,
                Background = Brushes.White,
                ItemsSource = _visibleRows
            };
            _colSelect = new DataGridCheckBoxColumn { Binding = new Binding("Selected"), Width = 60 };
            _colCategory = new DataGridTextColumn { Binding = new Binding("Category"), IsReadOnly = true, Width = 175 };
            _colPath = new DataGridTextColumn { Binding = new Binding("PathOrPackage"), IsReadOnly = true, Width = new DataGridLength(1.4, DataGridLengthUnitType.Star) };
            _colStatus = new DataGridTextColumn { Binding = new Binding("Status"), IsReadOnly = true, Width = 120 };
            _colDetails = new DataGridTextColumn { Binding = new Binding("Details"), IsReadOnly = true, Width = new DataGridLength(1.2, DataGridLengthUnitType.Star) };

            _gridResults.Columns.Add(_colSelect);
            _gridResults.Columns.Add(_colCategory);
            _gridResults.Columns.Add(_colPath);
            _gridResults.Columns.Add(_colStatus);
            _gridResults.Columns.Add(_colDetails);
            Grid.SetRow(_gridResults, 3);
            rootGrid.Children.Add(_gridResults);

            // 5. Log Drawer
            _txtLog = new TextBox
            {
                Margin = new Thickness(14, 0, 14, 8),
                IsReadOnly = true,
                AcceptsReturn = true,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                Background = new SolidColorBrush(Color.FromRgb(15, 23, 42)),
                Foreground = new SolidColorBrush(Color.FromRgb(226, 232, 240)),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 12
            };
            Grid.SetRow(_txtLog, 4);
            rootGrid.Children.Add(_txtLog);

            // 6. Status Bar
            var statusBorder = new Border
            {
                Background = new SolidColorBrush(Color.FromRgb(226, 232, 240)),
                Padding = new Thickness(14, 6, 14, 6)
            };
            _lblStatusBar = new TextBlock { FontSize = 12 };
            statusBorder.Child = _lblStatusBar;
            Grid.SetRow(statusBorder, 5);
            rootGrid.Children.Add(statusBorder);

            Content = rootGrid;
        }

        private CheckBox CreateScopeCheckbox()
        {
            var cb = new CheckBox { IsChecked = true, Margin = new Thickness(2, 3, 2, 3) };
            cb.Checked += OnScopeFilterChanged;
            cb.Unchecked += OnScopeFilterChanged;
            return cb;
        }

        private static Button CreateActionButton(Color bg, Brush fg)
        {
            return new Button
            {
                Padding = new Thickness(12, 7, 12, 7),
                Margin = new Thickness(4, 2, 4, 2),
                Background = new SolidColorBrush(bg),
                Foreground = fg,
                FontWeight = FontWeights.SemiBold,
                BorderThickness = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };
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
            _lblHeaderTitle.Text = s["HeaderTitle"];
            _lblVersionBadge.Text = s["VersionBadge"];
            _lblSafetyPill.Text = s["SafetyPill"];
            _lblPositioning.Text = s["Positioning"];
            _btnLangToggle.Content = s["LangButton"];
            _btnAbout.Content = s["AboutButton"];

            _grpScope.Header = s["ScopeHeader"];
            _chkCli.Content = s["ChkCli"];
            _chkDesktop.Content = s["ChkDesktop"];
            _chkVsCode.Content = s["ChkVsCode"];
            _chkCred.Content = s["ChkCred"];
            _chkEnv.Content = s["ChkEnv"];

            _grpPolicy.Header = s["PolicyHeader"];
            _rbAccountData.Content = new TextBlock { Text = s["PolicyAccount"], TextWrapping = TextWrapping.Wrap };
            _rbFullRemoval.Content = new TextBlock { Text = s["PolicyFull"], TextWrapping = TextWrapping.Wrap };

            _btnScan.Content = s["BtnScan"];
            _btnPlan.Content = s["BtnPlan"];
            _btnClean.Content = s["BtnClean"];
            _btnVerify.Content = s["BtnVerify"];
            _btnOpenFolder.Content = s["BtnOpenFolder"];
            _btnExportSummary.Content = s["BtnExportSummary"];

            _colSelect.Header = s["ColSelect"];
            _colCategory.Header = s["ColCategory"];
            _colPath.Header = s["ColPath"];
            _colStatus.Header = s["ColStatus"];
            _colDetails.Header = s["ColDetails"];

            if (!_hasScanned)
            {
                _lblStatusBar.Text = s["StatusIdle"];
            }
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
                ScopeCheckboxCount = 5,
                DataGridColumnCount = _gridResults.Columns.Count,
                InitialCleanButtonEnabled = initClean,
                BackendFound = !string.IsNullOrEmpty(_toolkitRoot),
                ResolvedToolkitRoot = _toolkitRoot,
                DryRun = _dryRun
            };
        }

        private void OnLangToggleClick(object sender, RoutedEventArgs e)
        {
            ToggleLanguage();
        }

        private void OnAboutClick(object sender, RoutedEventArgs e)
        {
            var s = Localization.GetStrings(_lang);
            MessageBox.Show(this, s["AboutBody"], s["AboutTitle"], MessageBoxButton.OK, MessageBoxImage.Information);
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
            _btnClean.IsEnabled = (!busy) && _hasScanned && _hasPlan && (_readyCount > 0);
        }

        private void AppendLog(string message)
        {
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

        private void OnScanClick(object sender, RoutedEventArgs e)
        {
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
                            Decision = decision,
                            Details = string.Format("[{0}] {1}", policy, reason)
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
                                Status = s["FoundLabel"],
                                Decision = "ReadOnly",
                                Details = s["ReadOnlyLabel"]
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
                                Status = zero ? s["CleanLabel"] : s["FoundLabel"],
                                Decision = "ReadOnly",
                                Details = l
                            });
                        }
                    }
                }

                _hasScanned = true;
                RefreshVisibleRows();
                _lblStatusBar.Text = string.Format(s["StatusScanned"], _allRows.Count, activeCount);
                AppendLog(string.Format("Scan finished: {0} total entries inspected.", _allRows.Count));
            });
        }

        private void OnPlanClick(object sender, RoutedEventArgs e)
        {
            if (!EnsureBackend()) return;
            var s = Localization.GetStrings(_lang);
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
            if (!EnsureBackend()) return;
            var s = Localization.GetStrings(_lang);
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
            if (!EnsureBackend()) return;
            var s = Localization.GetStrings(_lang);
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
    }

    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            string language = null;
            string toolkitRoot = null;
            string selfTestOut = null;
            bool headless = false;
            bool dryRun = false;

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
            }

            if (headless || !string.IsNullOrEmpty(selfTestOut))
            {
                var win = new MainWindow(language, toolkitRoot, dryRun);
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

            var app = new Application();
            var mainWindow = new MainWindow(language, toolkitRoot, dryRun);
            app.Run(mainWindow);
            return 0;
        }
    }
}
