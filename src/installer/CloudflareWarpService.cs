using System.Diagnostics;
using System.Net.Sockets;
using System.ServiceProcess;

namespace OneCord.Installer;

internal static class CloudflareWarpService
{
    private const string WarpCliDefaultPath = @"C:\Program Files\Cloudflare\Cloudflare WARP\warp-cli.exe";
    private const string WarpMsiUrl = "https://1111-releases.cloudflareclient.com/windows/Cloudflare_WARP_Release-x64.msi";
    private const string WarpServiceName = "CloudflareWARP";
    private const string ProxyHost = "127.0.0.1";

    public static Task RunFullSetupAsync(
        int port,
        IProgress<string>? progress = null,
        CancellationToken cancellationToken = default)
    {
        return Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            progress?.Report("Checking Cloudflare WARP...");

            if (FindWarpCli() is null)
            {
                progress?.Report("Downloading Cloudflare WARP...");
                var msiPath = DownloadMsiAsync(cancellationToken).GetAwaiter().GetResult();
                OneCordLog.Write($"WARP MSI downloaded to {msiPath}");

                progress?.Report("Installing Cloudflare WARP...");
                InstallMsi(msiPath);
                OneCordLog.Write("WARP MSI installed");
            }

            if (!IsProxyListening(port))
            {
                progress?.Report("Configuring WARP proxy mode...");
                ConfigureProxyMode(port);
                OneCordLog.Write($"WARP proxy configured on {ProxyHost}:{port}");
            }
            else
            {
                OneCordLog.Write($"WARP proxy already listening on {ProxyHost}:{port}");
            }

            if (!IsProxyListening(port))
                throw new InvalidOperationException(
                    $"WARP proxy is not listening on {ProxyHost}:{port}.\n" +
                    "Open Cloudflare WARP and make sure local proxy mode is available.");
        }, cancellationToken);
    }

    public static bool IsInstalled() => FindWarpCli() is not null;

    public static bool IsProxyListeningOnPort(int port) => IsProxyListening(port);

    public static bool IsProxyReady(int port) =>
        FindWarpCli() is not null && IsProxyListening(port);

    public static WarpStatus GetStatus(int port) =>
        new(IsInstalled(), IsProxyListening(port));

    public static Task RemoveSetupAsync(CancellationToken cancellationToken = default)
    {
        return Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (FindWarpCli() is null)
            {
                OneCordLog.Write("WARP remove skipped: warp-cli not found");
                return;
            }

            TryWarpCommand(ignoreFailure: true, "disconnect");
            TryWarpCommand(ignoreFailure: true, "mode warp", "set-mode warp");
            OneCordLog.Write("WARP proxy mode removed (disconnected, mode set to warp)");
        }, cancellationToken);
    }

    internal readonly record struct WarpStatus(bool Installed, bool ProxyListening);

    private static async Task<string> DownloadMsiAsync(CancellationToken cancellationToken)
    {
        var msiPath = Path.Combine(Path.GetTempPath(), "Cloudflare_WARP.msi");
        if (File.Exists(msiPath))
            File.Delete(msiPath);

        using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        await using var stream = await client.GetStreamAsync(WarpMsiUrl, cancellationToken);
        await using var file = File.Create(msiPath);
        await stream.CopyToAsync(file, cancellationToken);

        if (new FileInfo(msiPath).Length <= 0)
            throw new InvalidOperationException("Downloaded WARP installer is empty.");

        return msiPath;
    }

    private static void InstallMsi(string msiPath)
    {
        AdminProcess.ProcessResult result;

        if (AdminProcess.IsAdministrator())
        {
            result = AdminProcess.RunProcess(
                "msiexec.exe",
                $"/i \"{msiPath}\" /quiet /norestart");
        }
        else
        {
            result = AdminProcess.RunProcess(
                "msiexec.exe",
                $"/i \"{msiPath}\" /quiet /norestart",
                elevated: true);
        }

        if (result.ExitCode != 0)
            throw new InvalidOperationException(
                $"WARP installation failed (exit code {result.ExitCode}). Run as Administrator.");

        var deadline = DateTime.UtcNow.AddSeconds(45);
        while (DateTime.UtcNow < deadline)
        {
            if (FindWarpCli() is not null)
                return;
            Thread.Sleep(1000);
        }

        throw new InvalidOperationException("WARP was installed but warp-cli.exe was not found.");
    }

    private static void ConfigureProxyMode(int port)
    {
        WaitForService(35);
        InitializeWarpRegistration();
        SetWarpModeProxyCommands(port);

        if (WaitForLocalPort(port, 55))
            return;

        RestartServiceSafe();
        InitializeWarpRegistration();
        SetWarpModeProxyCommands(port);

        if (WaitForLocalPort(port, 35))
            return;

        var status = InvokeWarpCli("status").Output;
        var settings = InvokeWarpCli("settings").Output;

        var message = $"WARP proxy is not listening on {ProxyHost}:{port}";
        if (!string.IsNullOrWhiteSpace(status))
            message += $"\nstatus: {status.Trim()}";
        if (!string.IsNullOrWhiteSpace(settings))
            message += $"\nsettings: {settings.Trim()}";
        message += "\nOpen Cloudflare WARP and make sure local proxy mode is available, then try again.";

        throw new InvalidOperationException(message);
    }

    private static void InitializeWarpRegistration()
    {
        TryWarpCommand(
            ignoreFailure: true,
            "--accept-tos registration new",
            "--accept-tos register",
            "registration new",
            "register");
    }

    private static void SetWarpModeProxyCommands(int port)
    {
        TryWarpCommand("mode proxy", "set-mode proxy");
        TryWarpCommand($"proxy port {port}", $"set-proxy-port {port}");
        TryWarpCommand(ignoreFailure: true, "connect");
    }

    private static void TryWarpCommand(params string[] commandLines) =>
        TryWarpCommand(ignoreFailure: false, commandLines);

    private static void TryWarpCommand(bool ignoreFailure, params string[] commandLines)
    {
        foreach (var line in commandLines)
        {
            var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var result = InvokeWarpCli(parts);
            if (result.ExitCode == 0)
                return;
        }

        if (!ignoreFailure)
        {
            var last = commandLines[^1];
            throw new InvalidOperationException($"warp-cli command failed: {last}");
        }
    }

    private static string? FindWarpCli()
    {
        if (File.Exists(WarpCliDefaultPath))
            return WarpCliDefaultPath;

        var pathEnv = Environment.GetEnvironmentVariable("PATH") ?? "";
        foreach (var dir in pathEnv.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            var candidate = Path.Combine(dir.Trim(), "warp-cli.exe");
            if (File.Exists(candidate))
                return candidate;
        }

        const string cloudflareRoot = @"C:\Program Files\Cloudflare";
        if (!Directory.Exists(cloudflareRoot))
            return null;

        try
        {
            return Directory.EnumerateFiles(cloudflareRoot, "warp-cli.exe", SearchOption.AllDirectories)
                .FirstOrDefault();
        }
        catch
        {
            return null;
        }
    }

    private static WarpCliResult InvokeWarpCli(params string[] args)
    {
        var path = FindWarpCli();
        if (path is null)
            return new WarpCliResult(-1, "", string.Join(' ', args));

        var psi = new ProcessStartInfo
        {
            FileName = path,
            Arguments = string.Join(' ', args.Select(EscapeArg)),
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = Process.Start(psi);
        if (process is null)
            return new WarpCliResult(-1, "", string.Join(' ', args));

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        var output = string.IsNullOrWhiteSpace(stderr) ? stdout : $"{stdout}\n{stderr}";
        return new WarpCliResult(process.ExitCode, output.Trim(), string.Join(' ', args));
    }

    private static string EscapeArg(string arg) =>
        arg.Contains(' ') ? $"\"{arg}\"" : arg;

    private static bool IsProxyListening(int port) =>
        TestLocalTcpPort(ProxyHost, port, 900);

    private static bool TestLocalTcpPort(string host, int port, int timeoutMs)
    {
        try
        {
            using var client = new TcpClient();
            var task = client.ConnectAsync(host, port);
            if (!task.Wait(timeoutMs))
                return false;
            return client.Connected;
        }
        catch
        {
            return false;
        }
    }

    private static bool WaitForLocalPort(int port, int timeoutSec)
    {
        var deadline = DateTime.UtcNow.AddSeconds(timeoutSec);
        while (DateTime.UtcNow < deadline)
        {
            if (IsProxyListening(port))
                return true;
            Thread.Sleep(700);
        }
        return false;
    }

    private static void WaitForService(int timeoutSec)
    {
        ServiceController? service = null;
        var deadline = DateTime.UtcNow.AddSeconds(timeoutSec);

        while (DateTime.UtcNow < deadline && service is null)
        {
            try
            {
                service = new ServiceController(WarpServiceName);
                service.Refresh();
            }
            catch
            {
                Thread.Sleep(500);
            }
        }

        if (service is null)
            throw new InvalidOperationException("Cloudflare WARP service was not found.");

        try
        {
            if (service.Status != ServiceControllerStatus.Running)
            {
                if (!AdminProcess.IsAdministrator())
                {
                    AdminProcess.RunElevatedPowerShell(
                        $"Start-Service -Name '{WarpServiceName}' -ErrorAction Stop");
                }
                else
                {
                    service.Start();
                }
            }

            deadline = DateTime.UtcNow.AddSeconds(timeoutSec);
            while (DateTime.UtcNow < deadline)
            {
                service.Refresh();
                if (service.Status == ServiceControllerStatus.Running)
                {
                    WaitForProcess("warp-svc", 5);
                    return;
                }
                Thread.Sleep(700);
            }

            throw new InvalidOperationException("Cloudflare WARP service did not start.");
        }
        finally
        {
            service.Dispose();
        }
    }

    private static void RestartServiceSafe()
    {
        try
        {
            if (!AdminProcess.IsAdministrator())
            {
                AdminProcess.RunElevatedPowerShell(
                    $"Restart-Service -Name '{WarpServiceName}' -Force -ErrorAction Stop");
            }
            else
            {
                using var service = new ServiceController(WarpServiceName);
                service.Stop();
                service.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(25));
                service.Start();
            }

            WaitForService(25);
        }
        catch
        {
            // Best-effort restart.
        }
    }

    private static void WaitForProcess(string name, int timeoutSec)
    {
        var deadline = DateTime.UtcNow.AddSeconds(timeoutSec);
        while (DateTime.UtcNow < deadline)
        {
            if (Process.GetProcessesByName(name).Length > 0)
                return;
            Thread.Sleep(500);
        }
    }

    private readonly record struct WarpCliResult(int ExitCode, string Output, string Command);
}
