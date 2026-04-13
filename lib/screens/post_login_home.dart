import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import 'cashier_main_screen.dart';
import 'main_screen.dart';

/// Routes staff to the full back office or the cashier-only shell.
class PostLoginHome extends StatelessWidget {
  const PostLoginHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthModel>().currentUser;
    if (user?.isCashier == true) {
      return const CashierMainScreen();
    }
    return const MainScreen();
  }
}
