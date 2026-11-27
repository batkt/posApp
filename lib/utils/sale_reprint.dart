import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/cart_model.dart';
import '../models/sales_model.dart';
import '../screens/shared/receipt_screen.dart';
import '../services/guilgee_service.dart';

bool _neejBaina = false;

/// Өмнөх борлуулалтын баримтыг дахин хэвлэх дэлгэцийг нээнэ (Хянах самбарын
/// "Сүүлийн борлуулалт", Борлуулалтын түүхийн дэлгэрэнгүй хоёулаа ашиглана).
///
/// И-Баримт авсан борлуулалтын ХАДГАЛСАН И-Баримтыг (`GET /ebarimtJagsaaltAvya`)
/// ачаалж дамжуулна — дахин хэвлэхэд шинэ И-Баримт үүсэхгүй. Авч амжаагүй бол
/// баримтын дэлгэц дээрээс авч болно. "Баримт хэвлэх" нь зарлагын баримт.
///
/// Буцаж ирэхэд `true` (И-Баримт шинээр авсан байж болох тул жагсаалтаа
/// шинэчлэхэд ашиглана).
Future<bool> openSaleReprint(BuildContext context, CompletedSale sale) async {
  if (_neejBaina) return false;
  _neejBaina = true;
  try {
    final session = context.read<AuthModel>().posSession;
    Map<String, dynamic>? ebarimt;
    // `ebarimtAvsan` тугаас үл хамааран ҮРГЭЛЖ шалгана — Борлуулалтын түүх
    // зэрэг газраас ирсэн борлуулалтад туг нь дамжихгүй байж болно. И-Баримт
    // байхгүй бол null буцаж, баримтын дэлгэц дээрээс авах боломжтой хэвээр.
    if (session != null && sale.id.isNotEmpty) {
      ebarimt = await guilgeeService.fetchSavedEbarimt(
        baiguullagiinId: session.baiguullagiinId,
        guilgeeniiDugaar: sale.id,
        salbariinId: sale.salbariinId ?? session.salbariinId,
      );
    }
    if (!context.mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(
          items: sale.items
              .map((i) => CartItem(product: i.product, quantity: i.quantity))
              .toList(),
          saleLines: buildReceiptLines(sale.items),
          total: sale.total,
          paymentMethod: sale.paymentMethod,
          orderNumber: sale.id,
          initialEbarimt: ebarimt,
          guilgeeniiMongoId: sale.mongoId,
          cashierSlipTotals: CashierSlipTotals(
            grossSubtotal: sale.total + sale.discount,
            discount: sale.discount,
            noatgui: sale.noatguiSum > 0
                ? sale.noatguiSum
                : (sale.total - sale.tax - sale.nhhat),
            noat: sale.tax,
            nhat: sale.nhhat,
            payable: sale.total,
          ),
          dakhinKhevlekh: true,
        ),
      ),
    );
    return true;
  } finally {
    _neejBaina = false;
  }
}
