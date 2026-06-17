using System.Diagnostics;

namespace OneCord.Installer;

internal static class DiscordNrptService
{
    private const string NrptTag = "Discord-CF";

    private static readonly string[] Domains =
    [
        "discord.com",
        "discordapp.com",
        "discordapp.net",
        "discord.gg",
        "discord.media",
        "discordstatus.com"
    ];

    private static readonly string[] DnsServers = ["1.1.1.1", "1.0.0.1"];

    /// <summary>Read-only NRPT check; does not require elevation.</summary>
    public static bool IsEnabled()
    {
        try
        {
            var script =
                $"$c = @(Get-DnsClientNrptRule -ErrorAction SilentlyContinue | Where-Object {{ $_.Comment -eq '{NrptTag}' }}).Count; Write-Output $c";
            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{script}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process is null)
                return false;

            var output = process.StandardOutput.ReadToEnd().Trim();
            process.WaitForExit();
            if (process.ExitCode != 0 || !int.TryParse(output, out var count))
                return false;

            return count >= Domains.Length;
        }
        catch
        {
            return false;
        }
    }

    public static Task EnableAsync(CancellationToken cancellationToken = default)
    {
        return Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            var script = BuildEnableScript();
            var result = AdminProcess.RunElevatedPowerShell(script);

            if (result.ExitCode != 0)
                throw new InvalidOperationException(
                    $"Failed to apply Discord DNS rules.\n{result.Output}".Trim());

            OneCordLog.Write($"NRPT rules enabled for {Domains.Length} domains");
        }, cancellationToken);
    }

    public static Task DisableAsync(CancellationToken cancellationToken = default)
    {
        return Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            var script = BuildDisableScript();
            var result = AdminProcess.RunElevatedPowerShell(script);

            if (result.ExitCode != 0)
                throw new InvalidOperationException(
                    $"Failed to remove Discord DNS rules.\n{result.Output}".Trim());

            OneCordLog.Write("NRPT rules removed");
        }, cancellationToken);
    }

    private static string BuildEnableScript()
    {
        var domainLines = string.Join("\n", Domains.Select(d =>
            $"Add-DnsClientNrptRule -Namespace '.{d}' -NameServers @('{DnsServers[0]}','{DnsServers[1]}') -Comment '{NrptTag}' | Out-Null"));

        return $@"
$ErrorActionPreference = 'Stop'
$rules = @(Get-DnsClientNrptRule -ErrorAction SilentlyContinue | Where-Object {{ $_.Comment -eq '{NrptTag}' }})
foreach ($rule in $rules) {{
    Remove-DnsClientNrptRule -Name $rule.Name -Force | Out-Null
}}
{domainLines}
Clear-DnsClientCache
";
    }

    private static string BuildDisableScript() =>
        $@"
$ErrorActionPreference = 'Stop'
$rules = @(Get-DnsClientNrptRule -ErrorAction SilentlyContinue | Where-Object {{ $_.Comment -eq '{NrptTag}' }})
foreach ($rule in $rules) {{
    Remove-DnsClientNrptRule -Name $rule.Name -Force | Out-Null
}}
if ($rules.Count -gt 0) {{
    Clear-DnsClientCache
}}
";
}
