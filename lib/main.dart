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
import 'package:url_launcher/url_launcher.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const POSApp());
}

class POSApp extends StatelessWidget {
  const POSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleModel()),
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(create: (_) => SalesModel()),
        ChangeNotifierProxyProvider<AuthModel, InventoryModel>(
          create: (_) => InventoryModel(),
          update: (_, auth, previous) {
            final model = previous ?? InventoryModel();
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
      ],
      child: Consumer<LocaleModel>(
        builder: (context, localeModel, child) {
          return MaterialApp(
            title: 'posEase',
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
