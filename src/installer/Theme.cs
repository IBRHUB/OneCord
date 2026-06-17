namespace OneCord.Installer;

internal static class Theme
{
    // Surfaces — pure black (alpha must be 255; WinForms TextBox rejects A=0)
    public static readonly Color Bg = Color.FromArgb(255, 0, 0, 0);
    public static readonly Color Surface = Color.FromArgb(255, 0, 0, 0);

    // Text
    public static readonly Color Foreground = Color.White;
    public static readonly Color TextMuted = Color.FromArgb(179, 255, 255, 255);   // ~70%
    public static readonly Color TextSubtle = Color.FromArgb(140, 255, 255, 255);  // ~55%

    // Primary (blue)
    public static readonly Color Primary = Color.FromArgb(37, 99, 235);
    public static readonly Color PrimaryHover = Color.FromArgb(59, 130, 246);
    public static readonly Color PrimaryPressed = Color.FromArgb(29, 78, 216);
    public static readonly Color PrimaryDisabled = Color.FromArgb(102, 37, 99, 235);

    // Destructive (red)
    public static readonly Color Destructive = Color.FromArgb(239, 68, 68);
    public static readonly Color DestructiveHoverBg = Color.FromArgb(20, 239, 68, 68);

    // Chrome
    public static readonly Color Border = Color.FromArgb(46, 255, 255, 255);       // ~18%
    public static readonly Color BorderFocus = Primary;
    public static readonly Color DividerAccent = Color.FromArgb(128, 37, 99, 235); // blue @ 50%

    public const int Pad = 24;
    public const int Gap = 16;
    public const int ControlHeight = 32;
    public const int SegmentHeight = 32;

    // Typography (pt)
    public const float TitleSize = 18f;
    public const float SubtitleSize = 9f;
    public const float SectionTitleSize = 11f;
    public const float SectionSubtitleSize = 9f;
    public const float FieldLabelSize = 9f;
    public const float InputSize = 10f;
    public const float ButtonPrimarySize = 10f;
    public const float ButtonSecondarySize = 9.5f;
    public const float LinkSize = 9f;

    public static Font UiFont(float size, FontStyle style = FontStyle.Regular) =>
        new("Segoe UI", size, style, GraphicsUnit.Point);

    public static Font TitleFont => UiFont(TitleSize, FontStyle.Bold);
    public static Font SubtitleFont => UiFont(SubtitleSize);
    public static Font SectionTitleFont => UiFont(SectionTitleSize, FontStyle.Bold);
    public static Font SectionSubtitleFont => UiFont(SectionSubtitleSize);
    public static Font FieldLabelFont => UiFont(FieldLabelSize);
    public static Font InputFont => UiFont(InputSize);
    public static Font ButtonPrimaryFont => UiFont(ButtonPrimarySize, FontStyle.Bold);
    public static Font ButtonSecondaryFont => UiFont(ButtonSecondarySize);
    public static Font LinkFont => UiFont(LinkSize);

    public static void EnableDoubleBuffer(Control control)
    {
        control.GetType().GetProperty("DoubleBuffered",
                System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic)?
            .SetValue(control, true);
    }
}
