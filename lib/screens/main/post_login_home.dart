import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../pos/cashier_main_screen.dart';
import '../mobile_pos/mobile_pos_main_screen.dart';
import 'main_screen.dart';

/// Picks kiosk vs mobile shell from `tsonkhniiTokhirgoo` and [StaffScreenAccess].
/// `AdminEsekh` → [StaffScreenAccess.hasFullAccess] sets all route flags, so admins
/// get the same kiosk / mobile POS shell as other staff (not [MainScreen] only).
/// If both kiosk and mobile are allowed, phone uses [MobilePosMainScreen] and
/// larger surfaces use [CashierMainScreen].
///
/// Web `/khyanalt/possystem` maps to [StaffScreenAccess.allowsPosSystem] for
/// staff who only have Pos System in `tsonkhniiTokhirgoo`.
class PostLoginHome extends StatelessWidget {
  const PostLoginHome({super.key});

  static bool _preferMobileShell(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide < 600;
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AuthModel>().staffAccess;
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
