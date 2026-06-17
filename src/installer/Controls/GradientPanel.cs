namespace OneCord.Installer.Controls;

internal sealed class GradientPanel : Panel
{
    public Color FillColor { get; set; } = Theme.Bg;

    public GradientPanel()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
        BackColor = Theme.Bg;
    }

    protected override void OnPaintBackground(PaintEventArgs e)
    {
        var rect = ClientRectangle;
        if (rect.Width <= 0 || rect.Height <= 0) return;

        using var brush = new SolidBrush(FillColor);
        e.Graphics.FillRectangle(brush, rect);
    }
}
