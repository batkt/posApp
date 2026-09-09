import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'models/sales_model.dart';
import 'models/inventory_model.dart';
import 'models/product_model.dart';
import 'models/auth_model.dart';
import 'models/locale_model.dart';
import 'models/customer_model.dart';
import 'models/transaction_model.dart';
import 'screens/main/post_login_home.dart';
import 'screens/main/login_screen.dart';
import 'screens/main/two_factor_auth_screen.dart';
import 'screens/main/branch_select_screen.dart';
import 'theme/app_theme.dart';
import 'services/version_service.dart';
import 'services/api_service.dart';
import 'services/inactivity_monitor.dart';
import 'utils/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/network_usage_service.dart';
import 'services/background_watchdog_service.dart';
import 'package:media_kit/media_kit.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await networkUsageService.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final authModel = AuthModel();
  // No-op unless a terminal previously logged in (see TerminalSessionStore) —
  // lets a watchdog-triggered relaunch/reboot skip straight past LoginScreen.
  await authModel.tryRestoreTerminalSession();
  // Cheap: only registers the headless entrypoint + boot flag, starts nothing.
  await BackgroundWatchdogService.instance.configure();
  runApp(POSApp(authModel: authModel));
}

class POSApp extends StatefulWidget {
  const POSApp({super.key, required this.authModel});

  final AuthModel authModel;

  /// Токен хугацаа дуусахад дэлгэцүүдийг ХААХАД хэрэгтэй — session нь
  /// дурын дэлгэцээс (Navigator.push-аар овоолсон) унаж болно.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<POSApp> createState() => _POSAppState();
}

class _POSAppState extends State<POSApp> {
  /// `logout()` өөрөө `/garah`-руу хүсэлт явуулдаг ба тэр нь мөн хугацаа
  /// дууссан токентой тул дахин энэ хандагчийг дуудна — давхар гаралтаас
  /// хамгаална.
  bool _handlingSessionExpiry = false;

  /// 15 минут идэвхгүй байвал сешнийг автоматаар хаана.
  late final InactivityMonitor _inactivity =
      InactivityMonitor(onTimeout: _handleInactivityTimeout);

  @override
  void initState() {
    super.initState();
    ApiService.onSessionExpired = _handleSessionExpired;
    widget.authModel.addListener(_syncInactivityMonitor);
    _syncInactivityMonitor();
  }

  /// Зөвхөн НЭВТЭРСЭН үед тоолно — нэвтрэх дэлгэц дээр хүлээж байгаа хүнийг
  /// "гаргах" зүйл байхгүй.
  void _syncInactivityMonitor() {
    final loggedIn = widget.authModel.isLoggedIn;
    if (loggedIn && !_inactivity.isRunning) {
      _inactivity.start();
    } else if (!loggedIn && _inactivity.isRunning) {
      _inactivity.stop();
    }
  }

  Future<void> _handleInactivityTimeout() async {
    if (!widget.authModel.isLoggedIn) return;
    await widget.authModel.logout();
    POSApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    final ctx = POSApp.navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      showAppSnackBar(
        ctx,
        'Удаан хугацаанд үйлдэл хийгээгүй тул системээс гарлаа.',
        variant: AppSnackVariant.warning,
      );
    }
  }

  @override
  void dispose() {
    if (ApiService.onSessionExpired == _handleSessionExpired) {
      ApiService.onSessionExpired = null;
    }
    widget.authModel.removeListener(_syncInactivityMonitor);
    _inactivity.dispose();
    super.dispose();
  }

  /// Сервер `{"success": false, "aldaa": "jwt expired"}` буцаавал session-ыг
  /// шууд дуусгаж [LoginScreen] руу буцаана.
  void _handleSessionExpired(String message) {
    if (_handlingSessionExpiry) return;
    final auth = widget.authModel;
    if (!auth.isLoggedIn && !auth.isAuthenticated) return;
    _handlingSessionExpiry = true;

    // Хүсэлтийн хариу нь build-ийн дундаас ирж болзошгүй тул кадрын дараа.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await auth.logout();
        // Овоолсон дэлгэцүүдийг хааж [AuthWrapper] руу буцаана — эс тэгвээс
        // хугацаа дууссан ч кассын цонх нээлттэй хэвээр үлдэнэ.
        POSApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
        final ctx = POSApp.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          showAppSnackBar(
            ctx,
            'Нэвтрэх хугацаа дууссан тул дахин нэвтэрнэ үү.',
            variant: AppSnackVariant.error,
          );
        }
      } finally {
        _handlingSessionExpiry = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authModel = widget.authModel;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleModel()),
        ChangeNotifierProvider.value(value: authModel),
        ChangeNotifierProvider(create: (_) => SalesModel()),
        ChangeNotifierProxyProvider2<AuthModel, SalesModel, InventoryModel>(
          create: (_) => InventoryModel(),
          update: (_, auth, sales, previous) {
            final model = previous ?? InventoryModel();
            // Серверээс үлдэгдлээ дахин ачаалах бүрд сагсанд аль хэдийн
            // авсан барааг дахин хасна — эс тэгвээс шинэчлэлт нь сагсны
            // барьцааг арчиж, нэг барааг хоёр удаа зарах боломж үүснэ.
            model.reservedQtyResolver = () => sales.reservedQtyByProductId;
            model.syncSession(auth.posSession);
            return model;
          },
        ),
        ChangeNotifierProxyProvider<AuthModel, ProductModel>(
          create: (_) => ProductModel(),
          update: (_, auth, previous) {
            final model = previous ?? ProductModel();
            model.syncSession(auth.posSession);
            return model;
          },
        ),
        ChangeNotifierProxyProvider<AuthModel, CustomerModel>(
          create: (_) => CustomerModel(),
          update: (_, auth, previous) {
            final model = previous ?? CustomerModel();
            model.syncSession(auth.posSession);
            return model;
          },
        ),
        ChangeNotifierProvider(create: (_) => TransactionModel()),
        ChangeNotifierProvider.value(value: networkUsageService),
      ],
      child: Consumer<LocaleModel>(
        builder: (context, localeModel, child) {
          return MaterialApp(
            title: 'posEase',
            navigatorKey: POSApp.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            locale: localeModel.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('mn'),
            ],
            home: const AuthWrapper(),
            // Системийн "фонтын хэмжээ" тохиргоог хамгийн ихдээ 1.15 болгож
            // хязгаарлана.
            //
            // POS-ийн дэлгэцүүд тогтмол өндөртэй товч, оролтын талбар,
            // dropdown, шүүлтүүрийн мөр дээр суурилдаг. Андройд төхөөрөмжийн
            // хандалтын тохиргоонд фонтыг 1.3–2.0 дахин томруулсан үед тэдгээр
            // мөр текстээ багтааж чадахгүй халиад бүх цонхны дизайн эвдэрдэг
            // байв. Энэ бол цорын ганц газарт тавьсан ЕРӨНХИЙ хязгаарлалт —
            // дэлгэц бүрийг тусад нь засах шаардлагагүй.
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 1.0,
                    maxScaleFactor: 1.15,
                  ),
                ),
                // Дурын хүрэлт/гүйлгэлт/товчлуур нь идэвхгүй байдлын тоолуурыг
                // тэглэнэ. `Listener` нь HitTest-ээс ӨМНӨ дуудагддаг тул доорх
                // товчнуудын ажиллагаанд огт саад болохгүй.
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _inactivity.registerActivity(),
                  onPointerSignal: (_) => _inactivity.registerActivity(),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/poslogo.png'), context);
  }

  Future<void> _checkUpdate() async {
    final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';
    final latest = await versionService.checkUpdate(
      'PosEase', 
      platform, 
      ApiConfig.baseUrl,
    );

    if (latest != null && mounted) {
      _showUpdateDialog(latest);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> versionData) {
    final isForce = versionData['isForceUpdate'] == true;
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (context) => PopScope(
        canPop: !isForce,
        child: AlertDialog(
          title: Text(isForce ? 'Шинэчлэлт заавал хийнэ үү' : 'Шинэ хувилбар гарлаа'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Хувилбар: ${versionData['version']}'),
              const SizedBox(height: 8),
              Text(versionData['message'] ?? 'Та апп-аа шинэчилж хамгийн сүүлийн үеийн боломжуудыг ашиглана уу.'),
            ],
          ),
          actions: [
            if (!isForce)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Дараа'),
              ),
            FilledButton(
              onPressed: () async {
                final url = Uri.parse(versionData['updateUrl'] ?? '');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Шинэчлэх'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthModel>(
      builder: (context, auth, child) {
        if (auth.requiresTwoFactor && !auth.isLoggedIn) {
          return const TwoFactorAuthScreen();
        }
        if (auth.isLoggedIn) {
          if (auth.needsBranchSelection) {
            return const BranchSelectScreen();
          }
          return const PostLoginHome();
        }
        return const LoginScreen();
      },
    );
  }
}
