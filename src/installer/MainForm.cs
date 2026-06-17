using System.Diagnostics;
using System.Text.RegularExpressions;
using OneCord.Installer.Controls;

namespace OneCord.Installer;

internal enum ProtocolMode
{
    Http,
    Socks5,
    Direct
}

internal sealed class MainForm : Form
{
    private const string DllName = "version.dll";
    private const string IniName = "onecord.ini";
    private const string PacketName = "drover-packet.bin";

    private readonly string _processDir;
    private ProtocolMode _protocol = ProtocolMode.Socks5;

    private readonly CardPanel _protocolCard;
    private readonly CardPanel _proxyCard;
    private readonly Label _directNote;
    private readonly Label _proxyHint;
    private readonly Button _btnHttp;
    private readonly Button _btnSocks;
    private readonly Button _btnDirect;
    private readonly Label _hostLabel;
    private readonly Label _portLabel;
    private readonly TextBox _host;
    private readonly TextBox _port;
    private readonly CheckBox _auth;
    private readonly TextBox _login;
    private readonly TextBox _password;
    private readonly Label _loginLabel;
    private readonly Label _passwordLabel;
    private readonly GradientButton _btnInstall;
    private readonly GradientButton _btnUninstall;
    private readonly GradientButton _btnWarpSetup;
    private readonly GradientButton _btnWarpCheck;
    private readonly GradientButton _btnWarpRemove;
    private readonly Label _warpInstalledStatus;
    private readonly Label _warpProxyStatus;
    private readonly Label _warpNrptStatus;
    private readonly LinkLabel _about;
    private readonly Panel _footerDivider;

    public MainForm()
    {
        _processDir = Path.GetDirectoryName(Environment.ProcessPath) ?? AppContext.BaseDirectory;
        if (!_processDir.EndsWith('\\')) _processDir += "\\";

        Text = "OneCord";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = true;
        StartPosition = FormStartPosition.CenterScreen;
        AutoSize = false;
        BackColor = Theme.Bg;
        ForeColor = Theme.Foreground;
        Font = Theme.InputFont;
        Theme.EnableDoubleBuffer(this);

        var header = new GradientPanel
        {
            Dock = DockStyle.Top,
            Height = UiLayout.HeaderHeight,
            FillColor = Theme.Bg
        };
        header.Controls.Add(new Label
        {
            Text = "OneCord",
            Location = new Point(0, UiLayout.HeaderTitleY),
            Size = new Size(UiLayout.FormWidth, UiLayout.HeaderTitleH),
            TextAlign = ContentAlignment.MiddleCenter,
            ForeColor = Theme.Foreground,
            Font = Theme.TitleFont,
            BackColor = Theme.Bg
        });

        var content = new Panel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(0, UiLayout.ContentPadV, 0, UiLayout.ContentPadV),
            BackColor = Theme.Bg
        };
        Theme.EnableDoubleBuffer(content);

        _protocolCard = CreateCard(UiLayout.CardWidth, UiLayout.ProtocolCardH);
        _protocolCard.Location = new Point(UiLayout.ContentColumnX, UiLayout.ProtocolCardY);
        var segmentTrack = BuildSegmentTrack(out _btnHttp, out _btnSocks, out _btnDirect);
        _protocolCard.Controls.AddRange([
            CardTitle("Connection type", new Point(UiLayout.CardInset, UiLayout.CardTitleY)),
            CardSubtitle("How Discord reaches the network", new Point(UiLayout.CardInset, UiLayout.CardSubtitleY)),
            segmentTrack
        ]);

        _proxyCard = CreateCard(UiLayout.CardWidth, 1);
        _proxyCard.Location = new Point(UiLayout.ContentColumnX, UiLayout.ProxyCardY);

        _directNote = FixedLabel(
            "Direct mode routes voice only.\nProxy host and port are ignored.",
            new Point(UiLayout.CardInset, UiLayout.DirectNoteY),
            Theme.InputFont,
            Theme.TextMuted,
            new Size(UiLayout.FieldFullW, UiLayout.DirectNoteH));
        _directNote.TextAlign = ContentAlignment.TopCenter;
        _directNote.Visible = false;

        _proxyHint = FixedLabel(
            "",
            new Point(UiLayout.CardInset, 0),
            Theme.SectionSubtitleFont,
            Theme.TextSubtle,
            new Size(UiLayout.FieldFullW, UiLayout.RowSubtitleH));

        _hostLabel = FieldLabel("Host", new Point(UiLayout.CardInset, UiLayout.FieldLabelY), new Size(UiLayout.HostW, UiLayout.RowLabelH));
        _portLabel = FieldLabel("Port", new Point(UiLayout.PortX, UiLayout.FieldLabelY), new Size(UiLayout.PortW, UiLayout.RowLabelH));
        _host = CreateInput(new Point(UiLayout.CardInset, UiLayout.FieldInputY), new Size(UiLayout.HostW, Theme.ControlHeight));
        _port = CreateInput(new Point(UiLayout.PortX, UiLayout.FieldInputY), new Size(UiLayout.PortW, Theme.ControlHeight));
        _port.Text = "1080";

        _btnWarpSetup = new GradientButton
        {
            Text = "Set up Cloudflare WARP",
            Style = ButtonStyle.Secondary,
            Location = new Point(UiLayout.CardInset, UiLayout.WarpButtonY),
            Size = new Size(UiLayout.FieldFullW, UiLayout.WarpButtonH),
            Visible = false
        };
        _btnWarpSetup.Click += OnWarpSetupClick;

        _warpInstalledStatus = WarpStatusLabel("WARP installed: —");
        _warpProxyStatus = WarpStatusLabel("Proxy listening: —");
        _warpNrptStatus = WarpStatusLabel("Discord DNS rules (NRPT): —");

        _btnWarpCheck = new GradientButton
        {
            Text = "Check status",
            Style = ButtonStyle.Secondary,
            Visible = false
        };
        _btnWarpCheck.Click += OnWarpCheckClick;

        _btnWarpRemove = new GradientButton
        {
            Text = "Remove WARP setup",
            Style = ButtonStyle.Destructive,
            Visible = false
        };
        _btnWarpRemove.Click += OnWarpRemoveClick;

        _auth = new CheckBox
        {
            Text = "Use authentication (HTTP only)",
            Location = new Point(UiLayout.CardInset, 0),
            Size = new Size(UiLayout.FieldFullW, 24),
            ForeColor = Theme.TextMuted,
            BackColor = Color.Transparent,
            Font = Theme.FieldLabelFont
        };
        _auth.CheckedChanged += (_, _) => ApplyAuthVisibility();

        _loginLabel = FieldLabel("Login", new Point(UiLayout.CardInset, 0), new Size(UiLayout.FieldFullW, UiLayout.RowLabelH));
        _passwordLabel = FieldLabel("Password", new Point(UiLayout.CardInset, 0), new Size(UiLayout.FieldFullW, UiLayout.RowLabelH));
        _login = CreateInput(new Point(UiLayout.CardInset, 0), new Size(UiLayout.FieldFullW, Theme.ControlHeight));
        _password = CreateInput(new Point(UiLayout.CardInset, 0), new Size(UiLayout.FieldFullW, Theme.ControlHeight));
        _password.UseSystemPasswordChar = true;

        _proxyCard.Controls.AddRange([
            CardTitle("Proxy settings", new Point(UiLayout.CardInset, UiLayout.CardTitleY)),
            CardSubtitle("Local proxy address (e.g. WARP 127.0.0.1:1080)", new Point(UiLayout.CardInset, UiLayout.CardSubtitleY)),
            _hostLabel, _portLabel, _host, _port, _btnWarpSetup,
            _warpInstalledStatus, _warpProxyStatus, _warpNrptStatus, _btnWarpCheck, _btnWarpRemove, _auth,
            _loginLabel, _passwordLabel, _login, _password,
            _proxyHint, _directNote
        ]);

        _footerDivider = new Panel
        {
            Location = new Point(UiLayout.ContentColumnX, 0),
            Size = new Size(UiLayout.CardWidth, UiLayout.SectionDividerH),
            BackColor = Theme.Border
        };

        _btnInstall = new GradientButton
        {
            Text = "Install to Discord",
            Style = ButtonStyle.Primary,
            Location = new Point(UiLayout.ContentColumnX, 0),
            Size = new Size(UiLayout.CardWidth, UiLayout.PrimaryButtonH)
        };
        _btnUninstall = new GradientButton
        {
            Text = "Remove from Discord",
            Style = ButtonStyle.Destructive,
            Location = new Point(UiLayout.ContentColumnX, 0),
            Size = new Size(UiLayout.CardWidth, UiLayout.SecondaryButtonH)
        };
        _btnInstall.Click += (_, _) => Install();
        _btnUninstall.Click += (_, _) => Uninstall();

        _about = new LinkLabel
        {
            Text = "View OneCord on GitHub",
            Location = new Point(UiLayout.AboutX, 0),
            Size = new Size(UiLayout.AboutW, UiLayout.AboutH),
            TextAlign = ContentAlignment.MiddleCenter,
            LinkColor = Theme.Primary,
            ActiveLinkColor = Theme.PrimaryHover,
            VisitedLinkColor = Theme.Primary,
            LinkBehavior = LinkBehavior.HoverUnderline,
            BackColor = Color.Transparent,
            Font = Theme.LinkFont
        };
        _about.LinkClicked += (_, _) =>
            Process.Start(new ProcessStartInfo("https://github.com/IBRHUB/OneCord") { UseShellExecute = true });

        content.Controls.AddRange([
            _protocolCard, _proxyCard, _footerDivider,
            _btnInstall, _btnUninstall, _about
        ]);
        Controls.AddRange([content, header]);

        LoadSettings();
        SetProtocol(_protocol);
    }

    private Panel BuildSegmentTrack(out Button http, out Button socks, out Button direct)
    {
        var track = new Panel
        {
            Location = new Point(UiLayout.SegmentTrackPad, UiLayout.SegmentTrackY),
            Size = new Size(UiLayout.FieldFullW, UiLayout.SegmentTrackH),
            BackColor = Theme.Bg
        };
        track.Paint += (_, e) =>
        {
            var g = e.Graphics;
            var rect = new Rectangle(0, 0, track.Width - 1, track.Height - 1);
            using var pen = new Pen(Theme.Border);
            g.DrawRectangle(pen, rect);
            var x = UiLayout.SegmentW;
            g.DrawLine(pen, x, 0, x, track.Height - 1);
            g.DrawLine(pen, x * 2, 0, x * 2, track.Height - 1);
        };

        http = SegmentButton("HTTP", new Point(0, 0), new Size(UiLayout.SegmentW, Theme.SegmentHeight));
        socks = SegmentButton("WARP", new Point(UiLayout.SegmentW, 0), new Size(UiLayout.SegmentW, Theme.SegmentHeight));
        direct = SegmentButton("Direct", new Point(UiLayout.SegmentW * 2, 0), new Size(UiLayout.SegmentW, Theme.SegmentHeight));
        http.Click += (_, _) => SetProtocol(ProtocolMode.Http);
        socks.Click += (_, _) => SetProtocol(ProtocolMode.Socks5);
        direct.Click += (_, _) => SetProtocol(ProtocolMode.Direct);
        track.Controls.AddRange([http, socks, direct]);
        return track;
    }

    private void LoadSettings()
    {
        string? iniPath = null;
        var discordDirs = DiscordPaths.FindAppDirectories();
        if (discordDirs.Count > 0)
            iniPath = Path.Combine(discordDirs[^1], IniName);

        iniPath ??= Path.Combine(_processDir, IniName);
        var proxy = IniConfig.ReadProxy(iniPath) ?? "socks5://127.0.0.1:1080";
        ApplyProxy(proxy);
    }

    private void ApplyProxy(string proxy)
    {
        if (string.IsNullOrWhiteSpace(proxy))
        {
            SetProtocol(ProtocolMode.Direct);
            return;
        }

        var match = Regex.Match(proxy.Trim(),
            @"^(?i)([a-z\d]+)://(?:(.+):(.+)@)?([^:]+):(\d+)\s*$");
        if (!match.Success)
        {
            SetProtocol(ProtocolMode.Socks5);
            _host.Text = "127.0.0.1";
            _port.Text = "1080";
            return;
        }

        var proto = match.Groups[1].Value.ToLowerInvariant();
        SetProtocol(proto is "http" or "https" ? ProtocolMode.Http : ProtocolMode.Socks5);
        _host.Text = match.Groups[4].Value;
        _port.Text = match.Groups[5].Value;
        _auth.Checked = match.Groups[2].Success && !string.IsNullOrEmpty(match.Groups[2].Value);
        _login.Text = match.Groups[2].Value;
        _password.Text = match.Groups[3].Value;
    }

    private void SetProtocol(ProtocolMode mode)
    {
        _protocol = mode;
        StyleSegment(_btnHttp, mode == ProtocolMode.Http);
        StyleSegment(_btnSocks, mode == ProtocolMode.Socks5);
        StyleSegment(_btnDirect, mode == ProtocolMode.Direct);

        var direct = mode == ProtocolMode.Direct;
        var http = mode == ProtocolMode.Http;

        _proxyCard.Dimmed = direct;
        _directNote.Visible = direct;

        _hostLabel.Visible = !direct;
        _portLabel.Visible = !direct;
        _host.Visible = !direct;
        _port.Visible = !direct;
        _auth.Visible = !direct;
        _btnWarpSetup.Visible = mode == ProtocolMode.Socks5;
        _warpInstalledStatus.Visible = mode == ProtocolMode.Socks5;
        _warpProxyStatus.Visible = mode == ProtocolMode.Socks5;
        _warpNrptStatus.Visible = mode == ProtocolMode.Socks5;
        _btnWarpCheck.Visible = mode == ProtocolMode.Socks5;
        _btnWarpRemove.Visible = mode == ProtocolMode.Socks5;

        if (!direct)
        {
            _host.Enabled = true;
            _port.Enabled = true;
            _auth.Enabled = http;
            StyleInput(_host, enabled: true);
            StyleInput(_port, enabled: true);
            _auth.ForeColor = http ? Theme.TextMuted : Theme.TextSubtle;
            if (!http && _auth.Checked)
                _auth.Checked = false;
        }

        UpdateProxyHint();
        ApplyAuthVisibility();
        _proxyCard.Invalidate();

        if (mode == ProtocolMode.Socks5)
            RefreshWarpStatus();
    }

    private void ApplyAuthVisibility()
    {
        var showAuth = _auth.Checked && _protocol == ProtocolMode.Http;
        _loginLabel.Visible = showAuth;
        _passwordLabel.Visible = showAuth;
        _login.Visible = showAuth;
        _password.Visible = showAuth;
        StyleInput(_login, showAuth);
        StyleInput(_password, showAuth);
        UpdateProxyHint();
        ApplyLayout();
    }

    private void ApplyLayout()
    {
        var showWarp = _protocol == ProtocolMode.Socks5;
        var layout = UiLayout.Compute(_protocol, _auth.Checked, GetProxyHintText(), showWarp);

        _proxyCard.Size = new Size(UiLayout.CardWidth, layout.ProxyCardH);

        _directNote.Location = new Point(UiLayout.CardInset, layout.DirectNoteY);
        _directNote.Size = new Size(UiLayout.FieldFullW, layout.DirectNoteH);

        _btnWarpSetup.Location = new Point(UiLayout.CardInset, layout.WarpButtonY);
        _btnWarpSetup.Size = new Size(UiLayout.FieldFullW, UiLayout.WarpButtonH);
        _btnWarpSetup.Visible = showWarp;

        _warpInstalledStatus.Location = new Point(UiLayout.CardInset, layout.WarpStatusY);
        _warpInstalledStatus.Size = new Size(UiLayout.FieldFullW, UiLayout.WarpStatusLineH);
        _warpInstalledStatus.Visible = showWarp;

        _warpProxyStatus.Location = new Point(UiLayout.CardInset, layout.WarpStatusY + UiLayout.WarpStatusLineH);
        _warpProxyStatus.Size = new Size(UiLayout.FieldFullW, UiLayout.WarpStatusLineH);
        _warpProxyStatus.Visible = showWarp;

        _warpNrptStatus.Location = new Point(UiLayout.CardInset, layout.WarpStatusY + UiLayout.WarpStatusLineH * 2);
        _warpNrptStatus.Size = new Size(UiLayout.FieldFullW, UiLayout.WarpStatusLineH);
        _warpNrptStatus.Visible = showWarp;

        _btnWarpCheck.Location = new Point(UiLayout.CardInset, layout.WarpCheckButtonY);
        _btnWarpCheck.Size = new Size(UiLayout.FieldFullW, UiLayout.WarpCheckButtonH);
        _btnWarpCheck.Visible = showWarp;

        _btnWarpRemove.Location = new Point(UiLayout.CardInset, layout.WarpRemoveButtonY);
        _btnWarpRemove.Size = new Size(UiLayout.FieldFullW, UiLayout.WarpRemoveButtonH);
        _btnWarpRemove.Visible = showWarp;

        _auth.Location = new Point(UiLayout.CardInset, layout.AuthY);

        _proxyHint.Location = new Point(UiLayout.CardInset, layout.ProxyHintY);
        _proxyHint.Size = new Size(UiLayout.FieldFullW, layout.ProxyHintH);

        _loginLabel.Location = new Point(UiLayout.CardInset, layout.LoginLabelY);
        _login.Location = new Point(UiLayout.CardInset, layout.LoginInputY);
        _passwordLabel.Location = new Point(UiLayout.CardInset, layout.PasswordLabelY);
        _password.Location = new Point(UiLayout.CardInset, layout.PasswordInputY);

        _footerDivider.Location = new Point(UiLayout.ContentColumnX, layout.FooterDividerY);
        _btnInstall.Location = new Point(UiLayout.ContentColumnX, layout.ActionsY);
        _btnUninstall.Location = new Point(UiLayout.ContentColumnX, layout.SecondaryButtonY);
        _about.Location = new Point(UiLayout.AboutX, layout.AboutY);

        ClientSize = new Size(UiLayout.FormWidth, layout.FormHeight);
    }

    private string GetProxyHintText()
    {
        if (_protocol == ProtocolMode.Direct) return "";
        if (_auth.Checked && _protocol == ProtocolMode.Http) return "";
        return _protocol == ProtocolMode.Socks5
            ? "Use Set up Cloudflare WARP for automatic WARP proxy and Discord DNS routing."
            : "Enable authentication only if your HTTP proxy requires a username and password.";
    }

    private async void OnWarpSetupClick(object? sender, EventArgs e)
    {
        if (!TryParsePort(out var port))
            return;

        _btnWarpSetup.Enabled = false;
        SetWarpButtonsEnabled(false);
        _btnWarpSetup.Text = "Setting up WARP...";
        OneCordLog.Write($"WARP setup started (port {port})");

        try
        {
            var progress = new Progress<string>(_ => { });
            await CloudflareWarpService.RunFullSetupAsync(port, progress);
            await DiscordNrptService.EnableAsync();

            _host.Text = ProxyHost;
            OneCordLog.Write($"WARP setup completed (port {port})");
            ThemedMessageBox.Show(this,
                $"Cloudflare WARP is ready.\nProxy listening on 127.0.0.1:{port}",
                Text, MessageBoxIcon.Information);
            RefreshWarpStatus();
        }
        catch (Exception ex)
        {
            OneCordLog.Write($"WARP setup failed: {ex.Message}");
            ThemedMessageBox.Show(this, ex.Message, Text, MessageBoxIcon.Error);
        }
        finally
        {
            _btnWarpSetup.Text = "Set up Cloudflare WARP";
            SetWarpButtonsEnabled(_protocol == ProtocolMode.Socks5);
        }
    }

    private async void OnWarpRemoveClick(object? sender, EventArgs e)
    {
        var confirm = ThemedMessageBox.ShowConfirm(this,
            "Remove OneCord's WARP route setup?\n\n" +
            "This removes Discord DNS rules (NRPT) and disconnects WARP proxy mode.\n" +
            "Cloudflare WARP stays installed; OneCord is not removed from Discord.",
            Text,
            destructive: true);

        if (confirm != DialogResult.Yes)
            return;

        SetWarpButtonsEnabled(false);
        _btnWarpRemove.Text = "Removing WARP setup...";
        OneCordLog.Write("WARP remove started");

        try
        {
            await DiscordNrptService.DisableAsync();
            await CloudflareWarpService.RemoveSetupAsync();

            OneCordLog.Write("WARP remove completed");
            ThemedMessageBox.Show(this,
                "WARP route setup removed.\nDiscord DNS rules cleared and WARP proxy mode disabled.",
                Text, MessageBoxIcon.Information);
            RefreshWarpStatus();
        }
        catch (Exception ex)
        {
            OneCordLog.Write($"WARP remove failed: {ex.Message}");
            ThemedMessageBox.Show(this, ex.Message, Text, MessageBoxIcon.Error);
        }
        finally
        {
            _btnWarpRemove.Text = "Remove WARP setup";
            SetWarpButtonsEnabled(_protocol == ProtocolMode.Socks5);
        }
    }

    private void SetWarpButtonsEnabled(bool enabled)
    {
        _btnWarpSetup.Enabled = enabled;
        _btnWarpCheck.Enabled = enabled;
        _btnWarpRemove.Enabled = enabled;
    }

    private async void OnWarpCheckClick(object? sender, EventArgs e)
    {
        if (!TryParsePort(out var port, showError: true))
            return;

        await RunWarpStatusCheckAsync(port, showCheckingState: true);
    }

    private void RefreshWarpStatus()
    {
        if (_protocol != ProtocolMode.Socks5)
            return;

        if (!TryParsePort(out var port, showError: false))
        {
            SetWarpStatusLabels(null, null, null);
            return;
        }

        _ = RunWarpStatusCheckAsync(port, showCheckingState: false);
    }

    private async Task RunWarpStatusCheckAsync(int port, bool showCheckingState)
    {
        if (showCheckingState)
        {
            SetWarpButtonsEnabled(false);
            _btnWarpCheck.Text = "Checking...";
            SetWarpStatusChecking();
        }

        OneCordLog.Write($"WARP status check started (port {port})");

        bool? installed = null;
        bool? proxyListening = null;
        bool? nrptActive = null;

        try
        {
            (installed, proxyListening, nrptActive) = await Task.Run(() =>
            {
                var warp = CloudflareWarpService.GetStatus(port);
                var nrpt = DiscordNrptService.IsEnabled();
                return ((bool?)warp.Installed, (bool?)warp.ProxyListening, (bool?)nrpt);
            });

            OneCordLog.Write(
                $"WARP status: installed={installed}, proxy={proxyListening}, nrpt={nrptActive}");
        }
        catch (Exception ex)
        {
            OneCordLog.Write($"WARP status check failed: {ex.Message}");
        }

        if (IsDisposed)
            return;

        SetWarpStatusLabels(installed, proxyListening, nrptActive);

        if (showCheckingState)
        {
            _btnWarpCheck.Text = "Check status";
            SetWarpButtonsEnabled(_protocol == ProtocolMode.Socks5);
        }
    }

    private void SetWarpStatusChecking()
    {
        if (InvokeRequired)
        {
            BeginInvoke(SetWarpStatusChecking);
            return;
        }

        _warpInstalledStatus.Text = "WARP installed: …";
        _warpProxyStatus.Text = "Proxy listening: …";
        _warpNrptStatus.Text = "Discord DNS rules (NRPT): …";
    }

    private void SetWarpStatusLabels(bool? installed, bool? proxyListening, bool? nrptActive)
    {
        if (InvokeRequired)
        {
            BeginInvoke(() => SetWarpStatusLabels(installed, proxyListening, nrptActive));
            return;
        }

        _warpInstalledStatus.Text = installed switch
        {
            true => "WARP installed: yes",
            false => "WARP installed: no",
            _ => "WARP installed: —"
        };

        var portText = _port.Text.Trim();
        _warpProxyStatus.Text = proxyListening switch
        {
            true => $"Proxy listening on 127.0.0.1:{portText}: yes",
            false => $"Proxy listening on 127.0.0.1:{portText}: no",
            _ => "Proxy listening: —"
        };

        _warpNrptStatus.Text = nrptActive switch
        {
            true => "Discord DNS rules (NRPT): active",
            false => "Discord DNS rules (NRPT): inactive",
            _ => "Discord DNS rules (NRPT): —"
        };
    }

    private bool TryParsePort(out int port, bool showError = true)
    {
        if (int.TryParse(_port.Text.Trim(), out port) && port is >= 1 and <= 65535)
            return true;

        if (showError)
            ThemedMessageBox.Show(this, "Invalid port specified.", Text, MessageBoxIcon.Error);
        port = 0;
        return false;
    }

    private const string ProxyHost = "127.0.0.1";

    private void UpdateProxyHint()
    {
        if (_protocol == ProtocolMode.Direct)
        {
            _proxyHint.Visible = false;
            return;
        }

        if (_auth.Checked && _protocol == ProtocolMode.Http)
        {
            _proxyHint.Visible = false;
            return;
        }

        _proxyHint.Visible = true;
        _proxyHint.Text = GetProxyHintText();
    }

    private string BuildProxyUrl()
    {
        if (_protocol == ProtocolMode.Direct) return string.Empty;

        var proto = _protocol == ProtocolMode.Http ? "http" : "socks5";
        var host = _host.Text.Trim();
        if (string.IsNullOrWhiteSpace(host))
            throw new InvalidOperationException("Invalid host specified.");

        if (!int.TryParse(_port.Text.Trim(), out var port) || port is < 1 or > 65535)
            throw new InvalidOperationException("Invalid port specified.");

        if (_auth.Checked)
        {
            if (_protocol == ProtocolMode.Socks5)
                throw new InvalidOperationException(
                    "Authentication for WARP is not supported. Use HTTP or an unprotected proxy.");
            if (string.IsNullOrWhiteSpace(_login.Text) || string.IsNullOrWhiteSpace(_password.Text))
                throw new InvalidOperationException("Fill in Login and Password or uncheck Authentication.");
        }

        var url = $"{proto}://";
        if (_auth.Checked)
            url += $"{_login.Text.Trim()}:{_password.Text}@";
        url += $"{host}:{port}";
        return url;
    }

    private void Install()
    {
        try
        {
            var dll = Path.Combine(_processDir, DllName);
            if (!File.Exists(dll))
                throw new InvalidOperationException($"The file '{DllName}' is missing next to the installer.");

            if (DiscordPaths.IsDiscordRunning())
                throw new InvalidOperationException("Please exit Discord before proceeding.");

            var proxy = BuildProxyUrl();
            var dirs = DiscordPaths.FindAppDirectories();
            if (dirs.Count == 0)
                throw new InvalidOperationException("The Discord folder was not found.");

            var errors = new List<string>();
            var localIni = Path.Combine(_processDir, IniName);
            try { IniConfig.WriteProxy(localIni, proxy); }
            catch { errors.Add(localIni); }

            var packetSrc = Path.Combine(_processDir, PacketName);
            foreach (var dir in dirs)
            {
                var ini = Path.Combine(dir, IniName);
                try { IniConfig.WriteProxy(ini, proxy); }
                catch { errors.Add(ini); }

                var dstDll = Path.Combine(dir, DllName);
                try { File.Copy(dll, dstDll, overwrite: true); }
                catch { errors.Add(dstDll); }

                if (File.Exists(packetSrc))
                {
                    var dstPacket = Path.Combine(dir, PacketName);
                    try { File.Copy(packetSrc, dstPacket, overwrite: true); }
                    catch { errors.Add(dstPacket); }
                }
            }

            if (errors.Count > 0)
                throw new InvalidOperationException("Some files could not be written:\n" + string.Join("\n", errors));

            ThemedMessageBox.Show(this,
                "OneCord installed successfully.\nRestart Discord to apply changes.",
                Text, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            ThemedMessageBox.Show(this, ex.Message, Text, MessageBoxIcon.Error);
        }
    }

    private void Uninstall()
    {
        try
        {
            if (DiscordPaths.IsDiscordRunning())
                throw new InvalidOperationException("Please exit Discord before proceeding.");

            var names = new[] { IniName, "drover.ini", DllName, PacketName, "onecord-packet.bin" };
            var errors = new List<string>();
            foreach (var dir in DiscordPaths.FindAppDirectories())
            {
                foreach (var name in names)
                {
                    var path = Path.Combine(dir, name);
                    if (!File.Exists(path)) continue;
                    try { File.Delete(path); }
                    catch { errors.Add(path); }
                }
            }

            if (errors.Count > 0)
                throw new InvalidOperationException("Some files could not be deleted:\n" + string.Join("\n", errors));

            ThemedMessageBox.Show(this,
                "OneCord removed from Discord.\nRestart Discord to finish cleanup.",
                Text, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            ThemedMessageBox.Show(this, ex.Message, Text, MessageBoxIcon.Error);
        }
    }

    private static CardPanel CreateCard(int width, int height) =>
        new() { Size = new Size(width, height), BackColor = Color.Transparent };

    private static Label CardTitle(string text, Point location) =>
        new()
        {
            Text = text,
            Location = location,
            Size = new Size(UiLayout.FieldFullW, UiLayout.RowTitleH),
            AutoSize = false,
            ForeColor = Theme.Foreground,
            Font = Theme.SectionTitleFont,
            BackColor = Color.Transparent
        };

    private static Label CardSubtitle(string text, Point location) =>
        new()
        {
            Text = text,
            Location = location,
            Size = new Size(UiLayout.FieldFullW, UiLayout.RowSubtitleH),
            AutoSize = false,
            ForeColor = Theme.TextSubtle,
            Font = Theme.SectionSubtitleFont,
            BackColor = Color.Transparent
        };

    private static Label FieldLabel(string text, Point location, Size size) =>
        new()
        {
            Text = text,
            Location = location,
            Size = size,
            AutoSize = false,
            ForeColor = Theme.TextMuted,
            Font = Theme.FieldLabelFont,
            BackColor = Color.Transparent
        };

    private static Label CenteredLabel(string text, Point location, Font font, Color color, Size size) =>
        new()
        {
            Text = text,
            Location = location,
            Size = size,
            AutoSize = false,
            TextAlign = ContentAlignment.MiddleCenter,
            ForeColor = color,
            Font = font,
            BackColor = Color.Transparent
        };

    private static Label WarpStatusLabel(string text) =>
        new()
        {
            Text = text,
            AutoSize = false,
            ForeColor = Theme.TextSubtle,
            Font = Theme.SectionSubtitleFont,
            BackColor = Color.Transparent,
            Visible = false
        };

    private static Label FixedLabel(string text, Point location, Font font, Color color, Size size) =>
        new()
        {
            Text = text,
            Location = location,
            Size = size,
            AutoSize = false,
            ForeColor = color,
            Font = font,
            BackColor = Color.Transparent
        };

    private static TextBox CreateInput(Point location, Size size)
    {
        var input = new TextBox
        {
            Location = location,
            Size = size,
            BackColor = Theme.Bg,
            ForeColor = Theme.Foreground,
            BorderStyle = BorderStyle.FixedSingle,
            Font = Theme.InputFont
        };
        input.Enter += (_, _) => StyleInput(input, true, focused: true);
        input.Leave += (_, _) => StyleInput(input, input.Enabled, focused: false);
        return input;
    }

    private static void StyleInput(TextBox input, bool enabled, bool focused = false)
    {
        input.ForeColor = enabled ? Theme.Foreground : Theme.TextSubtle;
        input.BackColor = focused && enabled ? InputFocusBackColor() : Theme.Bg;
    }

    /// <summary>Opaque equivalent of Color.FromArgb(8, Theme.Primary) — TextBox rejects alpha &lt; 255.</summary>
    private static Color InputFocusBackColor()
    {
        const int overlayAlpha = 8;
        var t = overlayAlpha / 255f;
        var r = (byte)(Theme.Bg.R + (Theme.Primary.R - Theme.Bg.R) * t);
        var g = (byte)(Theme.Bg.G + (Theme.Primary.G - Theme.Bg.G) * t);
        var b = (byte)(Theme.Bg.B + (Theme.Primary.B - Theme.Bg.B) * t);
        return Color.FromArgb(255, r, g, b);
    }

    private static Button SegmentButton(string text, Point location, Size size) =>
        new()
        {
            Text = text,
            Location = location,
            Size = size,
            FlatStyle = FlatStyle.Flat,
            TabStop = false,
            Font = Theme.InputFont,
            Cursor = Cursors.Default,
            BackColor = Theme.Bg,
            ForeColor = Theme.Foreground
        };

    private static void StyleSegment(Button button, bool selected)
    {
        button.FlatAppearance.BorderSize = 0;
        if (selected)
        {
            button.BackColor = Theme.Primary;
            button.ForeColor = Theme.Foreground;
            button.Font = Theme.UiFont(Theme.InputSize, FontStyle.Bold);
        }
        else
        {
            button.BackColor = Theme.Bg;
            button.ForeColor = Theme.Foreground;
            button.Font = Theme.InputFont;
        }
    }
}
