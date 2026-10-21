using System.Runtime.InteropServices;
using System.Runtime.InteropServices.Marshalling;

namespace Wooosh.Platform;

/// <summary>
/// The Windows entry point for sharing (DESIGN.md §8). An unpackaged app has no share
/// target, so Send puts itself in Explorer's Send To menu instead. Rewritten on every
/// launch so the entry follows Send.exe if it is moved. There is no uninstaller to remove
/// it: deleting Send.exe leaves a dead entry until the user deletes Send.lnk.
/// </summary>
/// <remarks>
/// Trimming turns off built-in COM interop ([ComImport]), so the shell link is created
/// with CoCreateInstance and wrapped by source-generated COM interfaces.
/// </remarks>
public static partial class SendToShortcut
{
    private static readonly Guid ShellLinkClass = new("00021401-0000-0000-C000-000000000046");
    private static readonly Guid UnknownInterface = new("00000000-0000-0000-C000-000000000046");
    private const uint InProcessServer = 1;

    public static void Ensure()
    {
        var target = Environment.ProcessPath;
        if (target is null)
        {
            return;
        }

        // The product name is never translated (COPY_STYLE.md §2), so neither is the entry.
        var path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.SendTo), "Send.lnk");

        Marshal.ThrowExceptionForHR(
            CoCreateInstance(ShellLinkClass, IntPtr.Zero, InProcessServer, UnknownInterface, out var unknown));
        var link = new StrategyBasedComWrappers()
            .GetOrCreateObjectForComInstance(unknown, CreateObjectFlags.UniqueInstance);
        Marshal.Release(unknown);
        try
        {
            var shellLink = (IShellLinkW)link;
            shellLink.SetPath(target);
            shellLink.SetWorkingDirectory(Path.GetDirectoryName(target)!);
            shellLink.SetIconLocation(target, 0);
            ((IPersistFile)link).Save(path, true);
        }
        finally
        {
            ((ComObject)link).FinalRelease();
        }
    }

    [LibraryImport("ole32.dll")]
    private static partial int CoCreateInstance(in Guid classId, IntPtr outer, uint context, in Guid interfaceId, out IntPtr instance);
}

/// <summary>Vtable order matters: every method up to SetPath must be declared, in order.</summary>
[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("000214F9-0000-0000-C000-000000000046")]
internal partial interface IShellLinkW
{
    void GetPath(IntPtr file, int maxPath, IntPtr findData, uint flags);
    void GetIDList(out IntPtr idList);
    void SetIDList(IntPtr idList);
    void GetDescription(IntPtr name, int maxName);
    void SetDescription(string name);
    void GetWorkingDirectory(IntPtr dir, int maxPath);
    void SetWorkingDirectory(string dir);
    void GetArguments(IntPtr args, int maxPath);
    void SetArguments(string args);
    void GetHotkey(out short hotkey);
    void SetHotkey(short hotkey);
    void GetShowCmd(out int showCmd);
    void SetShowCmd(int showCmd);
    void GetIconLocation(IntPtr iconPath, int maxPath, out int icon);
    void SetIconLocation(string iconPath, int icon);
    void SetRelativePath(string relativePath, uint reserved);
    void Resolve(IntPtr hwnd, uint flags);
    void SetPath(string file);
}

/// <summary>GetClassID is inherited from IPersist and comes first in the vtable.</summary>
[GeneratedComInterface(StringMarshalling = StringMarshalling.Utf16)]
[Guid("0000010B-0000-0000-C000-000000000046")]
internal partial interface IPersistFile
{
    void GetClassID(out Guid classId);
    [PreserveSig]
    int IsDirty();
    void Load(string fileName, uint mode);
    void Save(string fileName, [MarshalAs(UnmanagedType.Bool)] bool remember);
}
