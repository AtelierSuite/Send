namespace Wooosh.Platform;

/// <summary>
/// Send runs unpackaged, so <c>ApplicationData.Current</c> throws. Everything it keeps on
/// disk lives here instead. The folder keeps the internal name: on-disk state directories
/// must never move, or an update would mint a new identity and trip KEY_CHANGED on every peer.
/// </summary>
public static class AppDataDirectory
{
    public static string Root { get; } = Create();

    private static string Create()
    {
        var root = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Wooosh");
        Directory.CreateDirectory(root);
        return root;
    }
}
