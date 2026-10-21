using System.Runtime.InteropServices;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Wooosh.Core;
using Wooosh.Platform;
using Wooosh.Settings;
using Wooosh.ViewModels;

namespace Wooosh;

public partial class App : Application
{
    /// <summary>On the application, not the window: the core and peer list outlive a minimise to tray.</summary>
    public static MainViewModel? ViewModel { get; private set; }

    /// <summary>WinUI 3 pickers are window-owned and throw without an HWND.</summary>
    public static IntPtr MainWindowHandle { get; private set; }

    private static App? _instance;

    private readonly DispatcherQueue _dispatcher;
    private MainWindow? _window;

    public App()
    {
        InitializeComponent();
        _instance = this;
        _dispatcher = DispatcherQueue.GetForCurrentThread();
    }

    /// <summary>A second launch redirected here (Program.Main). Called off the UI thread.</summary>
    public static void OnActivatedAgain(IReadOnlyList<string> files)
    {
        var app = _instance;
        app?._dispatcher.TryEnqueue(() => app.Receive(files));
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        MainWindowHandle = WinRT.Interop.WindowNative.GetWindowHandle(_window);

        var settings = new SettingsRepository();
        var core = new NativeWoooshCore();
        ViewModel = new MainViewModel(_window.DispatcherQueue, core, settings);

        _window.Activate();

        // Fire and forget: failures surface through StartupError, and awaiting only delays the window.
        _ = ViewModel.StartAsync();

        try
        {
            SendToShortcut.Ensure();
        }
        catch (Exception e) when (e is COMException or IOException or UnauthorizedAccessException)
        {
            // Send To is a convenience; a locked-down profile must not stop Send from starting.
            System.Diagnostics.Debug.WriteLine($"[Wooosh] Send To shortcut not written: {e.Message}");
        }

        var files = CommandLine.ExistingPaths(Environment.GetCommandLineArgs().Skip(1));
        if (files.Count > 0)
        {
            Receive(files);
        }
    }

    /// <summary>Send To entry point (DESIGN.md §8), first launch or handed over.</summary>
    private void Receive(IReadOnlyList<string> files)
    {
        _window?.ShowWindow();
        if (files.Count == 0)
        {
            return;
        }

        // TODO(share): put these in front of the device picker once the send flow (TODO(send))
        // exists. They are the user's own files in place, so unlike a share target there is
        // nothing to stage and no source app waiting on completion.
        System.Diagnostics.Debug.WriteLine($"[Wooosh] {files.Count} file(s) from Send To; not handled yet.");
    }
}
