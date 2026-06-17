namespace OneCord.Installer.Controls;

internal sealed class CardPanel : Panel
{
    public Color FillColor { get; set; } = Theme.Bg;
    public Color BorderColor { get; set; } = Theme.Border;
    public bool Dimmed { get; set; }

    public CardPanel()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
        BackColor = Color.Transparent;
        Padding = Padding.Empty;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        var rect = new Rectangle(0, 0, Width - 1, Height - 1);

        using (var fill = new SolidBrush(FillColor))
            g.FillRectangle(fill, rect);
        using (var border = new Pen(BorderColor))
            g.DrawRectangle(border, rect);

        if (Dimmed)
        {
            using var veil = new SolidBrush(Color.FromArgb(140, Theme.Bg));
            g.FillRectangle(veil, rect);
        }
    }
}
