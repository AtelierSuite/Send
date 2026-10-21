using System.Text.Json;
using System.Text.Json.Serialization;
using Wooosh.Core;
using Wooosh.Platform;

namespace Wooosh.Settings;

public sealed record WoooshSettings
{
    public required string DisplayName { get; init; }

    public required CoreVisibility Visibility { get; init; }

    /// <summary>On by default: a receiver that quits with its window is one that misses transfers.</summary>
    public required bool KeepRunningInBackground { get; init; }
}

/// <summary>
/// Three values, read once and written through. Anything that must survive a reinstall
/// (the identity key, the trust store) belongs to the core, not here.
/// </summary>
public sealed partial class SettingsRepository
{
    private static readonly string FilePath = Path.Combine(AppDataDirectory.Root, "settings.json");

    private readonly Stored _store = Load();

    public event Action? Changed;

    public SettingsRepository()
    {
        Current = new WoooshSettings
        {
            DisplayName = _store.DisplayName is { Length: > 0 } name
                ? name
                : Environment.MachineName,
            // Paired only by default: a fresh install must not accept strangers unopted-in.
            Visibility = _store.Visibility switch
            {
                "everyone" => CoreVisibility.Everyone,
                "off" => CoreVisibility.Off,
                _ => CoreVisibility.PairedOnly,
            },
            KeepRunningInBackground = _store.KeepRunningInBackground ?? true,
        };
    }

    public WoooshSettings Current { get; private set; }

    public void SetDisplayName(string value)
    {
        var trimmed = value.Trim();
        if (trimmed.Length == 0 || trimmed == Current.DisplayName)
        {
            return;
        }

        _store.DisplayName = trimmed;
        Save();
        Current = Current with { DisplayName = trimmed };
        Changed?.Invoke();
    }

    public void SetVisibility(CoreVisibility value)
    {
        if (value == Current.Visibility)
        {
            return;
        }

        _store.Visibility = value switch
        {
            CoreVisibility.PairedOnly => "pairedOnly",
            CoreVisibility.Off => "off",
            _ => "everyone",
        };
        Save();
        Current = Current with { Visibility = value };
        Changed?.Invoke();
    }

    public void SetKeepRunningInBackground(bool value)
    {
        if (value == Current.KeepRunningInBackground)
        {
            return;
        }

        _store.KeepRunningInBackground = value;
        Save();
        Current = Current with { KeepRunningInBackground = value };
        Changed?.Invoke();
    }

    private static Stored Load()
    {
        try
        {
            return JsonSerializer.Deserialize(File.ReadAllText(FilePath), StoredContext.Default.Stored) ?? new Stored();
        }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException)
        {
            // Missing or unreadable: defaults, which are the safe values (paired only).
            return new Stored();
        }
    }

    private void Save()
    {
        // Temp-and-swap: a crash mid-write must not leave a truncated file that resets visibility.
        var temporary = FilePath + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(_store, StoredContext.Default.Stored));
        File.Move(temporary, FilePath, overwrite: true);
    }

    private sealed class Stored
    {
        [JsonPropertyName("displayName")]
        public string? DisplayName { get; set; }

        [JsonPropertyName("visibility")]
        public string? Visibility { get; set; }

        [JsonPropertyName("keepRunningInBackground")]
        public bool? KeepRunningInBackground { get; set; }
    }

    // Trimming disables reflection-based serialization, so the converter is generated.
    [JsonSerializable(typeof(Stored))]
    private sealed partial class StoredContext : JsonSerializerContext
    {
    }
}
