# EPOS on PAX A8900 and PAX A930 (PosEase)

This document describes how the **PosEase** Flutter app integrates **Data Bank EPOS Open API** on **PAX A8900** and **PAX A930** Android terminals. Implementation lives under `android/app/src/main/kotlin/mn/posease/mobile/terminal/pos/`.

## Summary

| Hardware                         | Profile              | How EPOS / payment works                                      |
|---------------------------------|----------------------|---------------------------------------------------------------|
| PAX **A8900**                   | `EPOS_OPEN_IN_APP`   | EPOS Open API JAR **in-process** inside PosEase               |
| PAX **A930** (non-RTX)          | `EPOS_OPEN_IN_APP`   | Same as A8900                                                 |
| PAX **A930RTX** (RTX firmware)  | `NEPTUNE_PAX`        | **Not** EPOS Open JAR path — uses Neptune / `pax_sdk` stack   |
| Other terminals                 | `LEGACY_INTENT`      | UniPOS or EPOS via `ACTION_SEND` to external terminal apps    |

A8900 and non-RTX A930 are treated the **same** by design.

## Hardware detection

`TerminalProfile.kt` builds an uppercased string from `Build.MODEL`, `Build.DEVICE`, and `Build.PRODUCT`:

1. **RTX first** — strings containing `A930RTX`, `930RTX`, or both `A930` and `RTX` → `NEPTUNE_PAX`.
2. **`A8900` or `8900`** → `EPOS_OPEN_IN_APP`.
3. **`A930`** → `EPOS_OPEN_IN_APP`.
4. Otherwise → `LEGACY_INTENT`.

To see what a device reports at runtime, use the Flutter method channel method `terminal.hardwareProfile` (implemented in `MainActivity.kt`).

## EPOS Open API (in-app) — A8900 & A930

### Dependency

Place **`EposOpenAPIv9_release.jar`** (Data Bank EPOS Open SDK) in `android/app/libs/`. See `android/app/libs/README_TERMINAL.md`. Without the JAR, builds that compile `EposOpenInAppHelper.kt` will fail.

### Startup

When the profile is `EPOS_OPEN_IN_APP`, `MainActivity` constructs `EposOpenInAppHelper`. If initialization throws, the app logs an error and **`eposInApp` is set to `null`**, which falls back to intent-based EPOS / Neptune behavior where applicable.

### Card purchase (Flutter → native)

- Dart calls `UniPosService.purchase` → method channel `android.unipos.purchase` (see `lib/services/unipos_service.dart`).
- **If `eposInApp` is non-null**, native code does **not** launch the UniPOS app. It calls EPOS **`SaleNoReceiptMsg`** via `EposOpenInAppHelper.startSaleNoReceipt` (amount in **minor units**, e.g. tögrög × 100).
- **If `eposInApp` is null**, the existing UniPOS `ACTION_SEND` flow is used.

### Printing and health check

- Bitmap print and related EPOS task paths use `EposOpenInAppHelper` (`startPrintBitmap`, `startHealthCheck`) when `eposInApp` is active.
- Direct Neptune thermal printing for bitmaps is **skipped** on the EPOS-in-app profile when the helper is ready (`shouldUseNeptuneDirectForThermal()` in `MainActivity.kt`).

### Results

EPOS Open API uses `IEposTransAPI.onResult(...)` in `onActivityResult`. `EposOpenInAppHelper.tryDeliverActivityResult` maps responses to maps/strings for Flutter (including `paymentType: CARD` when `rspCode` indicates success).

### Flutter validation

`UniPosService.requireSuccessfulTerminalCardPayment` enforces `rspCode` and **`paymentType`** because EPOS in-app can return a structure that must still be interpreted as a real approved card payment. See comments in `lib/services/unipos_service.dart`.

## PAX A930RTX (not EPOS Open JAR)

**A930RTX** uses **`NEPTUNE_PAX`**: payment/print stack differs (Neptune / bundled PAX SDK path). It is **not** the same as the A8900 / A930 EPOS Open in-process integration above.

## Debugging

- Log tag: `PosEase POSEpos` (see `MainActivity.kt`).
- Suggested logcat filter (from code comments): `adb logcat -s PosAppEpos` where applicable.

## Related files

| File | Role |
|------|------|
| `TerminalProfile.kt` | Model → `TerminalHardwareProfile` |
| `MainActivity.kt` | Method channel, routing, fallbacks |
| `EposOpenInAppHelper.kt` | EPOS Open API factory, sale, print, health |
| `lib/services/unipos_service.dart` | Flutter purchase + payment validation |
| `android/app/libs/README_TERMINAL.md` | JAR placement |
| `epossdk.md` | Data Bank EPOS SDK reference material in repo |

---

*Generated for PosEase; align with bank/SDK updates when upgrading `EposOpenAPI` JAR or firmware profiles.*
