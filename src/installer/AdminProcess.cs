using System.Diagnostics;
using System.Security.Principal;

namespace OneCord.Installer;

internal static class AdminProcess
{
    public static bool IsAdministrator()
    {
        using var identity = WindowsIdentity.GetCurrent();
        var principal = new WindowsPrincipal(identity);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

    public static ProcessResult RunElevatedPowerShell(string script)
    {
        var encoded = Convert.ToBase64String(
            System.Text.Encoding.Unicode.GetBytes(script));

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = $"-NoProfile -ExecutionPolicy Bypass -EncodedCommand {encoded}",
            UseShellExecute = true,
            Verb = "runas",
            WindowStyle = ProcessWindowStyle.Hidden
        };

        using var process = Process.Start(psi);
        if (process is null)
            throw new InvalidOperationException("Administrator approval is required to continue.");

        process.WaitForExit();
        return new ProcessResult(process.ExitCode, "");
    }

    public static ProcessResult RunProcess(string fileName, string arguments, bool elevated = false)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            UseShellExecute = elevated,
            RedirectStandardOutput = !elevated,
            RedirectStandardError = !elevated,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };

        if (elevated)
            psi.Verb = "runas";

        using var process = Process.Start(psi);
        if (process is null)
            throw new InvalidOperationException($"Failed to start {fileName}.");

        var stdout = elevated ? "" : process.StandardOutput.ReadToEnd();
        var stderr = elevated ? "" : process.StandardError.ReadToEnd();
        process.WaitForExit();

        var output = string.IsNullOrWhiteSpace(stderr)
            ? stdout.Trim()
            : $"{stdout.Trim()}\n{stderr.Trim()}".Trim();

        return new ProcessResult(process.ExitCode, output);
    }

    internal readonly record struct ProcessResult(int ExitCode, string Output);
}
