using System.Diagnostics;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace OneCord.Installer;

internal static class DiscordPaths
{
    private static readonly string[] AppNames = ["Discord", "DiscordCanary", "DiscordPTB"];

    public static IReadOnlyList<string> FindAppDirectories()
    {
        var dirs = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var app in AppNames)
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                $@"Software\Microsoft\Windows\CurrentVersion\Uninstall\{app}");
            var loc = key?.GetValue("InstallLocation") as string;
            if (string.IsNullOrWhiteSpace(loc)) continue;
            AddAppDirs(dirs, Path.GetFullPath(loc));
        }

        using (var cmdKey = Registry.CurrentUser.OpenSubKey(@"Software\Classes\Discord\shell\open\command"))
        {
            var cmd = cmdKey?.GetValue(null) as string;
            var match = cmd is null ? null : Regex.Match(cmd, @"""(.+\\)app-");
            if (match is { Success: true })
                AddAppDirs(dirs, Path.GetFullPath(match.Groups[1].Value));
        }

        return dirs.OrderBy(d => d, StringComparer.OrdinalIgnoreCase).ToList();
    }

    public static bool IsDiscordRunning() =>
        Process.GetProcessesByName("Discord")
            .Concat(Process.GetProcessesByName("DiscordCanary"))
            .Concat(Process.GetProcessesByName("DiscordPTB"))
            .Any(p =>
            {
                try
                {
                    return p.MainModule?.FileName?.Contains(@"\app-", StringComparison.OrdinalIgnoreCase) == true;
                }
                catch
                {
                    return false;
                }
            });

    private static void AddAppDirs(HashSet<string> dirs, string baseDir)
    {
        if (!Directory.Exists(baseDir)) return;
        foreach (var appDir in Directory.GetDirectories(baseDir, "app-*"))
        {
            if (File.Exists(Path.Combine(appDir, "Discord.exe")))
                dirs.Add(appDir.TrimEnd('\\') + "\\");
        }
    }
}
