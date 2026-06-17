using System.Drawing.Text;

namespace OneCord.Installer.Controls;

internal enum ButtonStyle
{
    Primary,
    Secondary,
    Destructive
}

internal sealed class GradientButton : Control
{
    private bool _hover;
    private bool _pressed;

    public ButtonStyle Style { get; set; } = ButtonStyle.Primary;

    public GradientButton()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer |
                 ControlStyles.ResizeRedraw | ControlStyles.UserPaint |
                 ControlStyles.SupportsTransparentBackColor | ControlStyles.Selectable, true);
        Cursor = Cursors.Hand;
        TabStop = true;
        BackColor = Color.Transparent;
    }

    protected override void OnMouseEnter(EventArgs e)
    {
        base.OnMouseEnter(e);
        _hover = true;
        Invalidate();
    }

    protected override void OnMouseLeave(EventArgs e)
    {
        base.OnMouseLeave(e);
        _hover = false;
        _pressed = false;
        Invalidate();
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button == MouseButtons.Left && Enabled)
        {
            _pressed = true;
            Invalidate();
        }
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        _pressed = false;
        Invalidate();
    }

    protected override void OnEnabledChanged(EventArgs e)
    {
        base.OnEnabledChanged(e);
        Invalidate();
    }

    protected override void OnGotFocus(EventArgs e)
    {
        base.OnGotFocus(e);
        Invalidate();
    }

    protected override void OnLostFocus(EventArgs e)
    {
        base.OnLostFocus(e);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

        var rect = new Rectangle(0, 0, Width - 1, Height - 1);
        Color fill;
        Color border;
        Color text;
        Font labelFont;

        switch (Style)
        {
            case ButtonStyle.Destructive:
                fill = _hover && Enabled ? Theme.DestructiveHoverBg : Theme.Bg;
                border = Theme.Destructive;
                text = Theme.Destructive;
                labelFont = Theme.ButtonSecondaryFont;
                break;
            case ButtonStyle.Secondary:
                fill = _hover && Enabled ? Color.FromArgb(20, 255, 255, 255) : Theme.Bg;
                border = Theme.Border;
                text = Theme.TextMuted;
                labelFont = Theme.ButtonSecondaryFont;
                break;
            default:
                if (!Enabled)
                {
                    fill = Theme.Bg;
                    border = Theme.PrimaryDisabled;
                    text = Theme.TextSubtle;
                }
                else if (_pressed)
                {
                    fill = Theme.PrimaryPressed;
                    border = Theme.PrimaryPressed;
                    text = Theme.Foreground;
                }
                else if (_hover)
                {
                    fill = Theme.PrimaryHover;
                    border = Theme.PrimaryHover;
                    text = Theme.Foreground;
                }
                else
                {
                    fill = Theme.Primary;
                    border = Theme.Primary;
                    text = Theme.Foreground;
                }
                labelFont = Theme.ButtonPrimaryFont;
                break;
        }

        using (var brush = new SolidBrush(fill))
            g.FillRectangle(brush, rect);
        using (var pen = new Pen(border))
            g.DrawRectangle(pen, rect);

        if (Focused && Enabled)
        {
            var focusRect = Rectangle.Inflate(rect, -2, -2);
            using var focusPen = new Pen(Theme.BorderFocus);
            g.DrawRectangle(focusPen, focusRect);
        }

        var flags = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter |
                    TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding;
        TextRenderer.DrawText(g, Text, labelFont, rect, text, flags);
    }
}
