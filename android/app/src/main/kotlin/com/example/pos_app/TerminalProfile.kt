package com.example.pos_app

import android.os.Build
import java.util.Locale

/**
 * Picks how this APK talks to the payment / print stack on the device.
 *
 * - **EPOS_OPEN_IN_APP**: PAX A930 (non-RTX) and A8900 — Data Bank EPOS Open API JAR in-process
 *   ([EposTransAPIFactory]), not a separate EPOS consumer app.
 * - **NEPTUNE_PAX**: PAX A930RTX — Neptune / `pax_sdk` path (different firmware stack).
 * - **LEGACY_INTENT**: everything else — UniPOS / EPOS `ACTION_SEND` handlers as today.
 *
 * Add new models here when you ship another POS with another SDK.
 */
enum class TerminalHardwareProfile {
    EPOS_OPEN_IN_APP,
    NEPTUNE_PAX,
    LEGACY_INTENT,
    ;

    companion object {
        fun detect(): TerminalHardwareProfile {
            val m = "${Build.MODEL} ${Build.DEVICE} ${Build.PRODUCT}".uppercase(Locale.US)
            // RTX first — model string may contain both "A930" and "RTX".
            if (m.contains("A930RTX") || m.contains("930RTX") || (m.contains("A930") && m.contains("RTX"))) {
                return NEPTUNE_PAX
            }
            if (m.contains("A8900") || m.contains("8900")) {
                return EPOS_OPEN_IN_APP
            }
            if (m.contains("A930")) {
                return EPOS_OPEN_IN_APP
            }
            return LEGACY_INTENT
        }
    }
}
