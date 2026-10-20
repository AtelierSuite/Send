using Wooosh.Core.Interop;
using Wooosh.Localization;

namespace Wooosh.Core;

/// <summary>The relayed per-file limit (PROTOCOL.md §9.6), from the core so the copy cannot
/// drift from the rule. Only read once an internet peer exists, so the DLL is loaded.</summary>
public static class RelayLimit
{
    private static string? _text;

    public static string Text => _text ??= Formatters.ByteSize(
        (long)UniffiCall.Rust((ref RustCallStatus status) =>
            NativeMethods.uniffi_wooosh_core_fn_func_relay_max_file_bytes(ref status)));
}
