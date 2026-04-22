# Terminal SDKs on `android/app/libs`

## EPOS Open API (PAX A930, A8900)

Place **`EposOpenAPIv9_release.jar`** here (Data Bank EPOS Open SDK). The app auto-detects hardware (see `TerminalProfile.kt`) and runs this JAR **in-process** on those models.

Without the JAR, **release/debug builds fail** at compile time when `EposOpenInAppHelper` is compiled.

## PAX Neptune (A930RTX and legacy thermal)

NeptuneLite `.aar` / `.jar` files you already drop here are used when the profile is **not** `EPOS_OPEN_IN_APP` (see `MainActivity.kt`).
