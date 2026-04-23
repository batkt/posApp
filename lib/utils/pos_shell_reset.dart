import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inventory_model.dart';
import '../models/sales_model.dart';

/// Clears the in-progress cashier sale (restocks deducted inventory) and bumps
/// the cashier UI epoch so [POSScreen] returns to the product step.
void resetCashierPosShellState(BuildContext context) {
  final sales = context.read<SalesModel>();
  final inventory = context.read<InventoryModel>();
  for (final line in sales.currentSaleItems) {
    inventory.restock(line.product.id, line.quantity);
  }
  sales.clearSale();
  sales.signalCashierReturnToProductsAfterReceipt();
}

