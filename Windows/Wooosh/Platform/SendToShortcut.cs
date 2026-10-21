using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace Wooosh.Platform;

/// <summary>
/// The Windows entry point for sharing (DESIGN.md §8). An unpackaged app has no share
/// target, so Send puts itself in Explorer's Send To menu instead. Rewritten on every
/// launch so the entry follows Send.exe if it is moved. There is no uninstaller to remove
/// it: deleting Send.exe leaves a dead entry until the user deletes Send.lnk.
/// </summary>
public static class SendToShortcut
{
    public static void Ensure()
    {
        var target = Environment.ProcessPath;
        if (target is null)
        {
            return;
        }

        // The product name is never translated (COPY_STYLE.md §2), so neither is the entry.
        var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.SendTo), "Send.lnk");

        var link = (IShellLinkW)new ShellLink();
        try
        {
            link.SetPath(target);
            link.SetWorkingDirectory(Path.GetDirectoryName(target)!);
            link.SetIconLocation(target, 0);
            ((IPersistFile)link).Save(path, true);
        }
        finally
        {
            Marshal.ReleaseComObject(link);
        }
    }

    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    private class ShellLink
    {
    }

    /// <summary>Vtable order matters: every method up to SetPath must be declared, in order.</summary>
    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    private interface IShellLinkW
    {
        void GetPath(IntPtr file, int maxPath, IntPtr findData, uint flags);
        void GetIDList(out IntPtr idList);
        void SetIDList(IntPtr idList);
        void GetDescription(IntPtr name, int maxName);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string name);
        void GetWorkingDirectory(IntPtr dir, int maxPath);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string dir);
        void GetArguments(IntPtr args, int maxPath);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string args);
        void GetHotkey(out short hotkey);
        void SetHotkey(short hotkey);
        void GetShowCmd(out int showCmd);
        void SetShowCmd(int showCmd);
        void GetIconLocation(IntPtr iconPath, int maxPath, out int icon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string iconPath, int icon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string relativePath, uint reserved);
        void Resolve(IntPtr hwnd, uint flags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string file);
    }
}
