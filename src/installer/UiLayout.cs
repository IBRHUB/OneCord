namespace OneCord.Installer;

/// <summary>Layout grid on a 4px spacing scale Proxy card and form height are computed per mode</summary>
internal static class UiLayout
{
    public const int FormWidth = 500;

    public const int HeaderHeight = 56;
    public const int HeaderTitleH = 28;
    public const int HeaderTitleY = (HeaderHeight - HeaderTitleH) / 2;

    public const int ContentPadV = 16;

    public const int ContentMargin = 40;
    public const int CardWidth = FormWidth - ContentMargin * 2;
    public const int ContentColumnX = ContentMargin;
    public const int CardInset = 16;
    public const int FieldFullW = CardWidth - CardInset * 2;

    // Layout-only spacing (4px grid)
    public const int RowTitleH = 22;
    public const int RowSubtitleH = 18;
    public const int RowLabelH = 18;
    public const int TitleToSubtitleGap = 4;
    public const int SubtitleToContentGap = 8;
    public const int LabelToInputGap = 4;
    public const int BlockGap = 8;
    public const int SectionGap = 16;
    public const int SectionDividerH = 1;
    public const int FooterGap = 16;
    public const int FooterAfterDividerGap = 16;
    public const int AuthCheckH = 24;
    public const int DirectNoteH = 40;
    public const int WarpButtonH = Theme.ControlHeight;
    public const int WarpStatusLineCount = 3;
    public const int WarpStatusLineH = RowSubtitleH;
    public const int WarpStatusBlockH = WarpStatusLineCount * WarpStatusLineH;
    public const int WarpCheckButtonH = Theme.ControlHeight;
    public const int WarpRemoveButtonH = Theme.ControlHeight;

    // Shared section header rows (inside cards)
    public const int CardTitleY = CardInset;
    public const int CardSubtitleY = CardTitleY + RowTitleH + TitleToSubtitleGap;

    // Protocol section
    public const int SegmentTrackPad = CardInset;
    public const int SegmentTrackY = CardSubtitleY + RowSubtitleH + SubtitleToContentGap;
    public const int SegmentTrackH = Theme.ControlHeight;
    public const int SegmentW = FieldFullW / 3;

    public const int ProtocolCardY = 0;
    public const int ProtocolCardH = SegmentTrackY + SegmentTrackH + CardInset;

    public const int ProxyCardY = ProtocolCardY + ProtocolCardH + SectionGap;

    // Proxy section — host/port (relative to proxy card top)
    public const int FieldLabelY = CardSubtitleY + RowSubtitleH + SubtitleToContentGap;
    public const int FieldInputY = FieldLabelY + RowLabelH + LabelToInputGap;
    public const int FieldColumnGap = 12;
    public const int PortW = 96;
    public const int HostW = FieldFullW - FieldColumnGap - PortW;
    public const int PortX = CardInset + HostW + FieldColumnGap;

    public const int WarpButtonY = FieldInputY + Theme.ControlHeight + BlockGap;

    public const int DirectNoteY = CardSubtitleY + RowSubtitleH + SubtitleToContentGap;

    // Footer action block
    public const int PrimaryButtonH = 40;
    public const int SecondaryButtonH = 32;
    public const int ButtonGap = 12;
    public const int AboutGap = 10;
    public const int AboutH = 20;
    public const int AboutW = 220;
    public const int AboutX = ContentColumnX + (CardWidth - AboutW) / 2;

    internal readonly struct Snapshot
    {
        public int ProxyCardH { get; init; }
        public int FormHeight { get; init; }
        public int DirectNoteY { get; init; }
        public int DirectNoteH { get; init; }
        public int WarpButtonY { get; init; }
        public int WarpStatusY { get; init; }
        public int WarpCheckButtonY { get; init; }
        public int WarpRemoveButtonY { get; init; }
        public int AuthY { get; init; }
        public int ProxyHintY { get; init; }
        public int ProxyHintH { get; init; }
        public int LoginLabelY { get; init; }
        public int LoginInputY { get; init; }
        public int PasswordLabelY { get; init; }
        public int PasswordInputY { get; init; }
        public int FooterDividerY { get; init; }
        public int ActionsY { get; init; }
        public int SecondaryButtonY { get; init; }
        public int AboutY { get; init; }
    }

    public static Snapshot Compute(ProtocolMode mode, bool authChecked, string hintText, bool showWarpButton)
    {
        int proxyCardH;
        int proxyHintY;
        int proxyHintH;
        int loginLabelY;
        int loginInputY;
        int passwordLabelY;
        int passwordInputY;
        int warpButtonY = WarpButtonY;
        int warpStatusY = 0;
        int warpCheckButtonY = 0;
        int warpRemoveButtonY = 0;
        int authY;
        int directNoteY = DirectNoteY;
        int directNoteH = DirectNoteH;

        if (mode == ProtocolMode.Direct)
        {
            proxyCardH = directNoteY + directNoteH + CardInset;
            proxyHintY = proxyHintH = 0;
            authY = 0;
            loginLabelY = loginInputY = passwordLabelY = passwordInputY = 0;
        }
        else
        {
            if (showWarpButton)
            {
                warpStatusY = warpButtonY + WarpButtonH + BlockGap;
                warpCheckButtonY = warpStatusY + WarpStatusBlockH + BlockGap;
                warpRemoveButtonY = warpCheckButtonY + WarpCheckButtonH + BlockGap;
                authY = warpRemoveButtonY + WarpRemoveButtonH + BlockGap;
            }
            else
            {
                authY = FieldInputY + Theme.ControlHeight + BlockGap;
            }

            var showAuthFields = mode == ProtocolMode.Http && authChecked;
            if (showAuthFields)
            {
                loginLabelY = authY + AuthCheckH + BlockGap;
                loginInputY = loginLabelY + RowLabelH + LabelToInputGap;
                passwordLabelY = loginInputY + Theme.ControlHeight + BlockGap;
                passwordInputY = passwordLabelY + RowLabelH + LabelToInputGap;
                proxyCardH = passwordInputY + Theme.ControlHeight + CardInset;
                proxyHintY = proxyHintH = 0;
            }
            else
            {
                proxyHintY = authY + AuthCheckH + BlockGap;
                proxyHintH = MeasureHintHeight(hintText);
                proxyCardH = proxyHintY + proxyHintH + CardInset;
                loginLabelY = loginInputY = passwordLabelY = passwordInputY = 0;
            }
        }

        var footerDividerY = ProxyCardY + proxyCardH + FooterGap;
        var actionsY = footerDividerY + SectionDividerH + FooterAfterDividerGap;
        var secondaryButtonY = actionsY + PrimaryButtonH + ButtonGap;
        var aboutY = secondaryButtonY + SecondaryButtonH + AboutGap;

        var formHeight = HeaderHeight + ContentPadV + aboutY + AboutH + ContentPadV;

        return new Snapshot
        {
            ProxyCardH = proxyCardH,
            FormHeight = formHeight,
            DirectNoteY = directNoteY,
            DirectNoteH = directNoteH,
            WarpButtonY = warpButtonY,
            WarpStatusY = warpStatusY,
            WarpCheckButtonY = warpCheckButtonY,
            WarpRemoveButtonY = warpRemoveButtonY,
            AuthY = authY,
            ProxyHintY = proxyHintY,
            ProxyHintH = proxyHintH,
            LoginLabelY = loginLabelY,
            LoginInputY = loginInputY,
            PasswordLabelY = passwordLabelY,
            PasswordInputY = passwordInputY,
            FooterDividerY = footerDividerY,
            ActionsY = actionsY,
            SecondaryButtonY = secondaryButtonY,
            AboutY = aboutY
        };
    }

    public static int MeasureHintHeight(string text)
    {
        if (string.IsNullOrEmpty(text)) return RowSubtitleH;
        using var bmp = new Bitmap(1, 1);
        using var g = Graphics.FromImage(bmp);
        var size = TextRenderer.MeasureText(g, text, Theme.SectionSubtitleFont,
            new Size(FieldFullW, int.MaxValue),
            TextFormatFlags.WordBreak | TextFormatFlags.TextBoxControl);
        return Math.Max(size.Height, RowSubtitleH);
    }
}
