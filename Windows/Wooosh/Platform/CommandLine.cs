using System.Runtime.InteropServices;

namespace Wooosh.Platform;

/// <summary>Files arrive as command-line arguments from Send To, the shell's own quoting rules.</summary>
public static partial class CommandLine
{
    public static string[] Split(string commandLine)
    {
        if (string.IsNullOrWhiteSpace(commandLine))
        {
            return [];
        }

        var argv = CommandLineToArgvW(commandLine, out var count);
        if (argv == IntPtr.Zero)
        {
            return [];
        }

        try
        {
            var result = new string[count];
            for (var i = 0; i < count; i++)
            {
                result[i] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(argv, i * IntPtr.Size)) ?? "";
            }
            return result;
        }
        finally
        {
            LocalFree(argv);
        }
    }

    /// <summary>
    /// Whether a redirected launch's arguments include the executable varies, so it is
    /// dropped by path rather than by position. Anything that is not on disk is ignored.
    /// </summary>
    public static IReadOnlyList<string> ExistingPaths(IEnumerable<string> arguments)
    {
        var self = Environment.ProcessPath;
        return arguments
            .Where(a => !string.Equals(a, self, StringComparison.OrdinalIgnoreCase))
            .Where(a => File.Exists(a) || Directory.Exists(a))
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    [LibraryImport("shell32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial IntPtr CommandLineToArgvW(string commandLine, out int count);

    [LibraryImport("kernel32.dll")]
    private static partial IntPtr LocalFree(IntPtr memory);
}
