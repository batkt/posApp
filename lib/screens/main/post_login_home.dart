import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../pos/cashier_main_screen.dart';
import '../mobile_pos/mobile_pos_main_screen.dart';
import 'main_screen.dart';

/// Picks kiosk vs mobile shell from `tsonkhniiTokhirgoo`. If both are allowed, phone
/// uses mobile POS (QPay) and larger surfaces use kiosk (card terminal).
///
/// Web `/khyanalt/possystem` maps to [StaffScreenAccess.allowsPosSystem]. Managers
/// often have Pos System but not the separate kiosk/mobile route keys — they must
/// still land on the sale terminal (same as admin-level POS staff).
class PostLoginHome extends StatelessWidget {
  const PostLoginHome({super.key});

  static bool _preferMobileShell(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide < 600;
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AuthModel>().staffAccess;
    if (access.hasFullAccess) {
      return const MainScreen();
    }
    final kiosk = access.allowsKiosk;
    final mobile = access.allowsMobile;
    final posSystem = access.allowsPosSystem;

    if (kiosk && mobile) {
      return _preferMobileShell(context)
          ? const MobilePosMainScreen()
          : const CashierMainScreen();
    }
    if (kiosk) {
      return const CashierMainScreen();
    }
    if (mobile) {
      return const MobilePosMainScreen();
    }
    /// Pos System only (typical manager POS permission on web).
    if (posSystem) {
      return _preferMobileShell(context)
          ? const MobilePosMainScreen()
          : const CashierMainScreen();
    }
    return const MainScreen();
  }
}
