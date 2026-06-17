using System.Text;
using System.Text.RegularExpressions;

namespace OneCord.Installer;

internal static class IniConfig
{
    private static readonly Regex ProxyLine = new(
        @"(?is)\[(?:onecord|drover)\].*?^\s*proxy\s*=\s*(.+?)\s*$",
        RegexOptions.Multiline | RegexOptions.Compiled);

    public static string? ReadProxy(string path)
    {
        if (!File.Exists(path)) return null;
        var text = File.ReadAllText(path);
        var match = ProxyLine.Match(text);
        return match.Success ? match.Groups[1].Value.Trim() : string.Empty;
    }

    public static void WriteProxy(string path, string proxy)
    {
        var content = new StringBuilder()
            .AppendLine("[onecord]")
            .Append("proxy = ")
            .AppendLine(proxy)
            .ToString();
        File.WriteAllText(path, content, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
    }
}
