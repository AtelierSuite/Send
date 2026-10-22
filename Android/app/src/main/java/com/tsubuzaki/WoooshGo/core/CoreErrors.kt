package com.tsubuzaki.WoooshGo.core

import android.content.Context
import com.tsubuzaki.WoooshGo.R
import uniffi.wooosh_core.relayMaxFileBytes

/** From the core so the copy cannot drift from the rule. */
fun relayLimitText(context: Context): String =
    android.text.format.Formatter.formatShortFileSize(context, relayMaxFileBytes().toLong())

/** The core's outcome tokens are untranslatable and log-shaped; never shown verbatim. */
fun transferErrorMessage(context: Context, raw: String?): String {
    val text = raw?.lowercase().orEmpty()
    if (text.contains("relay_file_too_large")) {
        return context.getString(R.string.error_relay_file_too_large, relayLimitText(context))
    }
    internetErrorRes(text)?.let { return context.getString(it) }
    return context.getString(
        when {

            text.contains("declined") || text.contains("rejected") ->
                R.string.error_declined_by_peer

            text.contains("cancelled by peer") || text.contains("canceled by peer") ->
                R.string.error_cancelled_by_peer

            text.contains("cancel") -> R.string.transfer_state_cancelled
            text.contains("timed out") || text.contains("timeout") -> R.string.error_no_answer
            text.contains("pairing_required") -> R.string.error_pairing_required
            text.contains("version") -> R.string.error_version_mismatch
            text.contains("key_changed") -> R.string.error_key_changed
            else -> R.string.error_transfer_failed
        }
    )
}

/** Rendezvous outcomes reach the shell as core error text on both events and failures. */
private fun internetErrorRes(text: String): Int? = when {
    text.contains("relay_unavailable") -> R.string.error_relay_unavailable
    text.contains("rendezvous_quota") -> R.string.error_internet_quota
    text.contains("rendezvous_unavailable") -> R.string.error_internet_unavailable
    else -> null
}

/**
 * Every pairing failure, from an event or a thrown call, arrives as the core's English text.
 * Close-code tokens come first: their prose also contains words the later cases match.
 */
fun pairingErrorMessage(context: Context, raw: String?): String {
    val text = raw?.lowercase().orEmpty()
    internetErrorRes(text)?.let { return context.getString(it) }
    return context.getString(
        when {
            text.contains("pairing_required") -> R.string.error_pairing_needs_code
            text.contains("qr_key_mismatch") -> R.string.error_qr_key_mismatch
            text.contains("key_changed") -> R.string.error_key_changed
            text.contains("version_mismatch") -> R.string.error_version_mismatch
            text.contains("token_invalid") -> R.string.error_pairing_code_rejected
            text.contains("invalid qr payload") -> R.string.error_invalid_qr
            text.contains("expired") -> R.string.error_pairing_code_expired_detail
            text.contains("sas confirmation timed out") -> R.string.error_sas_timeout
            text.contains("timed out") -> R.string.error_pairing_timeout
            text.contains("rejected locally") -> R.string.error_pairing_failed
            text.contains("rejected") -> R.string.error_pairing_declined
            text.contains("closed") -> R.string.error_pairing_dropped
            text.startsWith("connect failed") || text.startsWith("i/o error") ->
                R.string.error_pairing_timeout
            else -> R.string.error_pairing_failed
        }
    )
}
