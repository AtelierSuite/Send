using System.Runtime.InteropServices;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.Windows.AppLifecycle;
using Wooosh.Platform;

namespace Wooosh;

/// <summary>
/// Replaces the XAML-generated Main (DISABLE_XAML_GENERATED_MAIN) so a second launch can
/// hand its files to the running instance before it creates a window of its own. Send To
/// starts a new process for every selection, and two instances would fight over the
/// listener port and the identity key.
/// </summary>
public static partial class Program
{
    [STAThread]
    private static int Main()
    {
        WinRT.ComWrappersSupport.InitializeComWrappers();

        var primary = AppInstance.FindOrRegisterForKey("main");
        if (!primary.IsCurrent)
        {
            Redirect(AppInstance.GetCurrent().GetActivatedEventArgs(), primary);
            return 0;
        }

        primary.Activated += OnRedirected;

        Application.Start(_ =>
        {
            SynchronizationContext.SetSynchronizationContext(
                new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread()));
            _ = new App();
        });
        return 0;
    }

    /// <summary>Raised on a background thread in the primary instance.</summary>
    private static void OnRedirected(object? sender, AppActivationArguments args)
    {
        IReadOnlyList<string> files = Array.Empty<string>();
        if (args.Kind == ExtendedActivationKind.Launch
            && args.Data is Windows.ApplicationModel.Activation.ILaunchActivatedEventArgs launch)
        {
            files = CommandLine.ExistingPaths(CommandLine.Split(launch.Arguments));
        }
        App.OnActivatedAgain(files);
    }

    /// <summary>
    /// RedirectActivationToAsync must not be awaited on this STA thread, which would deadlock
    /// the COM call it makes; the documented pattern waits with a pumping CoWait instead.
    /// </summary>
    private static void Redirect(AppActivationArguments args, AppInstance primary)
    {
        var done = CreateEventW(IntPtr.Zero, true, false, null);
        Task.Run(() =>
        {
            primary.RedirectActivationToAsync(args).AsTask().Wait();
            SetEvent(done);
        });
        _ = CoWaitForMultipleObjects(0, uint.MaxValue, 1, [done], out _);
        CloseHandle(done);
    }

    [LibraryImport("kernel32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial IntPtr CreateEventW(IntPtr attributes, [MarshalAs(UnmanagedType.Bool)] bool manualReset, [MarshalAs(UnmanagedType.Bool)] bool initialState, string? name);

    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool SetEvent(IntPtr handle);

    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CloseHandle(IntPtr handle);

    [LibraryImport("ole32.dll")]
    private static partial int CoWaitForMultipleObjects(uint flags, uint timeout, uint count, IntPtr[] handles, out uint index);
}
