namespace OneCord.Installer.Controls;

internal static class ThemedMessageBox
{
    private const int DialogW = 400;
    private const int DialogH = 180;
    private const int ConfirmDialogW = 440;
    private const int ConfirmDialogH = 210;
    private const int Pad = 20;
    private const int AccentH = 1;
    private const int ButtonW = 96;
    private const int ButtonH = 32;

    public static DialogResult ShowConfirm(
        IWin32Window? owner,
        string message,
        string title,
        bool destructive = false)
    {
        using var dlg = new Form
        {
            Text = title,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            StartPosition = FormStartPosition.CenterParent,
            ClientSize = new Size(ConfirmDialogW, ConfirmDialogH),
            BackColor = Theme.Bg,
            ForeColor = Theme.Foreground,
            Font = Theme.InputFont,
            MinimizeBox = false,
            MaximizeBox = false,
            ShowInTaskbar = false,
            AutoSize = false,
            KeyPreview = true
        };

        var accent = destructive ? Theme.Destructive : Theme.Primary;
        var accentBar = new Panel
        {
            Dock = DockStyle.Top,
            Height = AccentH,
            BackColor = accent
        };

        var body = new Label
        {
            Text = message,
            ForeColor = Theme.Foreground,
            Location = new Point(Pad, Pad + AccentH),
            Size = new Size(ConfirmDialogW - Pad * 2,
                ConfirmDialogH - Pad * 2 - ButtonH - Theme.Gap - AccentH),
            AutoSize = false
        };

        var no = new GradientButton
        {
            Text = "No",
            Style = ButtonStyle.Secondary,
            Size = new Size(ButtonW, ButtonH),
            Location = new Point(ConfirmDialogW - Pad - ButtonW, ConfirmDialogH - Pad - ButtonH)
        };
        no.Click += (_, _) => dlg.DialogResult = DialogResult.No;

        var yes = new GradientButton
        {
            Text = "Yes",
            Style = destructive ? ButtonStyle.Destructive : ButtonStyle.Primary,
            Size = new Size(ButtonW, ButtonH),
            Location = new Point(ConfirmDialogW - Pad - ButtonW * 2 - Theme.Gap, ConfirmDialogH - Pad - ButtonH)
        };
        yes.Click += (_, _) => dlg.DialogResult = DialogResult.Yes;

        dlg.KeyDown += (_, e) =>
        {
            if (e.KeyCode == Keys.Escape)
            {
                dlg.DialogResult = DialogResult.No;
                e.Handled = true;
            }
        };
        dlg.Shown += (_, _) => no.Focus();

        dlg.Controls.AddRange([body, yes, no, accentBar]);
        return dlg.ShowDialog(owner);
    }

    public static DialogResult Show(IWin32Window? owner, string message, string title, MessageBoxIcon icon)
    {
        using var dlg = new Form
        {
            Text = title,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            StartPosition = FormStartPosition.CenterParent,
            ClientSize = new Size(DialogW, DialogH),
            BackColor = Theme.Bg,
            ForeColor = Theme.Foreground,
            Font = Theme.InputFont,
            MinimizeBox = false,
            MaximizeBox = false,
            ShowInTaskbar = false,
            AutoSize = false
        };

        var accent = icon == MessageBoxIcon.Error ? Theme.Destructive : Theme.Primary;
        var accentBar = new Panel
        {
            Dock = DockStyle.Top,
            Height = AccentH,
            BackColor = accent
        };

        var body = new Label
        {
            Text = message,
            ForeColor = Theme.Foreground,
            Location = new Point(Pad, Pad + AccentH),
            Size = new Size(DialogW - Pad * 2, DialogH - Pad * 2 - ButtonH - Theme.Gap - AccentH),
            AutoSize = false
        };

        var ok = new GradientButton
        {
            Text = "OK",
            Style = ButtonStyle.Primary,
            Size = new Size(ButtonW, ButtonH),
            Location = new Point(DialogW - Pad - ButtonW, DialogH - Pad - ButtonH)
        };
        ok.Click += (_, _) => dlg.DialogResult = DialogResult.OK;

        dlg.Controls.AddRange([body, ok, accentBar]);
        return dlg.ShowDialog(owner);
    }
}
