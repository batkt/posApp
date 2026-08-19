import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../screens/main/checkout_screen.dart';
import '../screens/pos/cashier_payment_screen.dart';

/// Push the payment screen matching the current user's role — same
/// cashier/mobile/QPay selection as `POSScreen._openPaymentScreen` — so any
/// caller (recalling a parked sale from whichever tab, etc.) lands on the
/// same input, and a plain [Navigator.pop] from it returns to whatever
/// screen was showing before, unrelated to which tab is active.
Future<void> openPosPaymentScreen(
  BuildContext context, {
  bool cashierMode = false,
  bool mobileStaffMode = false,
}) {
  final auth = context.read<AuthModel>();
  final cashier = auth.currentUser?.isCashier == true;
  final useCashierPayment =
      cashier || cashierMode || auth.staffAccess.allowsMobile;
  final mobileQpayMode = mobileStaffMode || auth.staffAccess.allowsMobile;
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => useCashierPayment
          ? CashierPaymentScreen(
              terminalMode: mobileQpayMode
                  ? CashierTerminalPaymentMode.qpayOnly
                  : CashierTerminalPaymentMode.cardOnly,
            )
          : const CheckoutScreen(),
    ),
  );
}
