import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import 'cashier_main_screen.dart';
import 'main_screen.dart';

/// Kiosk-first when `tsonkhniiTokhirgoo` allows kiosk; full app for admin / unrestricted.
class PostLoginHome extends StatelessWidget {
  const PostLoginHome({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AuthModel>().staffAccess;
    if (access.hasFullAccess) {
      return const MainScreen();
    }
    if (access.allowsKiosk) {
      return const CashierMainScreen();
    }
    return const MainScreen();
  }
}
