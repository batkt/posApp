import 'dart:async';
import 'dart:ui';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'terminal_barimt_signal_service.dart';
import 'terminal_session_store.dart';
import 'terminal_tulbur_signal_service.dart';

/// Same key [KioskTerminalBarimtSignalListener] writes on every foreground poll.
const String terminalWatchdogHeartbeatKey = 'terminal_watchdog_heartbeat';

const String _appPackage = 'mn.posease.mobile.terminal.pos';
const String _mainActivity = '$_appPackage.MainActivity';

/// Keep-alive + watchdog for the POS terminal only — NOT a headless print path.
///
/// The EPOS Open API terminal hardware (`EPOS_OPEN_IN_APP` profile, see
/// `TerminalProfile.kt`/`EposOpenInAppHelper.kt`) requires a live Android
/// `Activity` to print — a background isolate cannot call it. So this service
/// never renders receipts or completes jobs itself; it only (a) exists as a
/// foreground service so Android is less likely to kill the process, and
/// (b) relaunches `MainActivity` when there is pending print work and the
/// foreground UI has gone quiet, so [KioskTerminalBarimtSignalListener] can
/// resume and finish the job exactly as it always has.
class BackgroundWatchdogService {
  BackgroundWatchdogService._();
  static final BackgroundWatchdogService instance =
      BackgroundWatchdogService._();

  Future<void> configure() async {
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStartBackgroundWatchdog,
        // Started explicitly from CashierMainScreen once logged into a kiosk —
        // never on a plain phone install, see cashier_main_screen.dart.
        autoStart: false,
        // Resumes headlessly after reboot once a terminal session was persisted.
        autoStartOnBoot: true,
        isForegroundMode: true,
        // Leave notificationChannelId unset: BackgroundService.java only self-creates
        // its notification channel when this is null (defaults to "FOREGROUND_DEFAULT").
        // A custom id here with no matching channel ever created triggers
        // "RemoteServiceException: Bad notification for startForeground" on stricter
        // OEM ROMs (observed on the A930RTX terminal) and kills the whole process.
        initialNotificationTitle: 'PosEase терминал',
        initialNotificationContent: 'Терминал идэвхтэй ажиллаж байна',
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  Future<void> ensureStarted() async {
    final running = await FlutterBackgroundService().isRunning();
    debugPrint('>>> [BackgroundWatchdogService] ensureStarted: alreadyRunning=$running');
    if (!running) {
      await FlutterBackgroundService().startService();
      debugPrint('>>> [BackgroundWatchdogService] startService() called');
    }
  }
}

@pragma('vm:entry-point')
void onStartBackgroundWatchdog(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  debugPrint('>>> [BackgroundWatchdogService] onStart: entrypoint alive');
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  Timer.periodic(const Duration(seconds: 10), (_) async {
    try {
      await _watchdogTick();
    } catch (e) {
      debugPrint('>>> [BackgroundWatchdogService] tick error: $e');
    }
  });
}

Future<void> _watchdogTick() async {
  debugPrint('>>> [BackgroundWatchdogService] tick');
  final session = await TerminalSessionStore.instance.restore();
  if (session == null) {
    debugPrint('>>> [BackgroundWatchdogService] no persisted terminal session — idle');
    return;
  }

  final token = session['token']?.toString() ?? '';
  final baiguullagiinId = session['baiguullagiinId']?.toString() ?? '';
  final salbariinId = session['salbariinId']?.toString() ?? '';
  if (token.isEmpty || baiguullagiinId.isEmpty || salbariinId.isEmpty) {
    debugPrint('>>> [BackgroundWatchdogService] persisted session missing fields — idle');
    return;
  }

  // posApiService is a separate global in THIS isolate (flutter_background_service
  // runs a distinct Dart isolate/engine) — the main isolate's setToken() call never
  // reaches it, so every request here was going out unauthenticated ("Нэвтрэх
  // шаардлагатай") until this is set explicitly on every tick.
  posApiService.setToken(token);

  final pendingPrint = await TerminalBarimtSignalService().fetchPending(
    baiguullagiinId: baiguullagiinId,
    salbariinId: salbariinId,
  );
  int pendingCount = pendingPrint.length;

  try {
    final pendingPay = await TerminalTulburSignalService().fetchPending(
      baiguullagiinId: baiguullagiinId,
      salbariinId: salbariinId,
    );
    pendingCount += pendingPay.length;
  } catch (_) {}

  debugPrint('>>> [BackgroundWatchdogService] pendingPrint=${pendingPrint.length}, totalPending=$pendingCount');
  if (pendingCount == 0) return; // nothing waiting, no reason to relaunch

  final prefs = await SharedPreferences.getInstance();
  final lastBeatStr = prefs.getString(terminalWatchdogHeartbeatKey);
  final lastBeat = DateTime.tryParse(lastBeatStr ?? '');
  final now = DateTime.now();

  // If lastBeat is in the future (active UniPOS transaction) or occurred within the last 15 seconds,
  // the UI/payment is ACTIVE — do NOT relaunch MainActivity!
  final bool stale = lastBeat == null ||
      (now.isAfter(lastBeat) && now.difference(lastBeat) > const Duration(seconds: 15));

  debugPrint('>>> [BackgroundWatchdogService] lastBeat=$lastBeat stale=$stale');
  if (!stale) return; // UI/UniPOS is active, stand down!

  debugPrint('>>> [BackgroundWatchdogService] Pending print/card requests found ($pendingCount) while UI is closed/stale — relaunching MainActivity');
  await const AndroidIntent(
    action: 'android.intent.action.MAIN',
    category: 'android.intent.category.LAUNCHER',
    package: _appPackage,
    componentName: _mainActivity,
    flags: <int>[
      Flag.FLAG_ACTIVITY_NEW_TASK,
      Flag.FLAG_ACTIVITY_CLEAR_TOP,
      Flag.FLAG_ACTIVITY_SINGLE_TOP,
    ],
  ).launch();
  debugPrint('>>> [BackgroundWatchdogService] relaunch intent launched');
}
