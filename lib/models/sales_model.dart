import 'package:flutter/foundation.dart';

import '../data/payment_display_config.dart';
import '../payment/pos_payment_core.dart';
import '../utils/buunii_une_helper.dart';
import '../utils/dorvon_neg_uramshuulal.dart';
import 'cart_model.dart';
import 'customer_model.dart';
import 'inventory_model.dart';

class SaleItem {
  final Product product;
  int quantity;
  double unitPrice;

  /// Жижиглэнгийн нэгж үнэ (эхний оруулалт / гараар өөрчилсөн суурь).
  final double retailUnitPrice;

  /// `POST /guilgeeniiTuukhKhadgalya` → `baraa.uramshuulaliinId` (сонгосон урамшуулал).
  String? uramshuulaliinId;

  /// Үнэ гараар тохируулсан эсвэл бөөний тiers-ээс гадуурх нэгж үнэ — тоо өөрчлөхөд автомат бөөнөөр дахин тооцохгүй.
  bool forceRetailPricing;

  /// Хайрцагтай бараа: задлаж зарсан **нийт ширхэг** (вэб `zadlakhToo`). Хоосон бол
  /// `quantity` хайрцаг × [Product.negKhairtsaganDahiShirhegiinToo].
  double? boxPiecesSold;

  /// Жингийн бараа: граммаар оруулсан **бодит кг** (жишээ нь 250 гр → 0.25).
  /// Хоосон бол `quantity` нь бүхэл кг гэж үзнэ. [boxPiecesSold]-ийн яг адил
  /// зарчим — үлдэгдлийн нөөцлөлт нь бүхэл тоогоор явж, үнэ/API нь бутархайг
  /// ашиглана.
  double? soldWeightKg;

  /// `POST /uramshuulalShalgay` буцаасан мөрийн бүтэн бичлэг. Сервер нь
  /// урамшууллаа мөчлөг бүрт ДАХИН тооцдог тул өмнөх хариугаа (тэр дундаа
  /// `dorvonNegGiftLine`, `dorvonNegOriginalShirkheg` зэрэг зөвхөн сервер
  /// мэддэг талбаруудыг) хэвээр буцааж илгээх ёстой — эс тэгвээс бэлэг мөр
  /// бүр дуудалт тутамд дахин үрждэг.
  Map<String, dynamic>? serverRow;

  /// Бэлэг мөрийн ЖИНХЭНЭ үнэ (сервер `undsenZarakhUne`). Бэлэг мөр 0 үнээр
  /// бичигддэг тул хөнгөлөлтийн дүнг эндээс гаргана.
  double? undsenZarakhUne;

  /// Сервер тэмдэглэсэн "N-т 1 үнэгүй"-ийн бэлэг мөр эсэх.
  bool dorvonNegGiftLine;

  /// Урамшууллаар үнэгүй өгсөн мөр эсэх (бэлэг эсвэл "N-т 1 үнэгүй").
  bool get isGiftLine =>
      uramshuulaliinId != null && uramshuulaliinId!.trim().isNotEmpty;

  /// Бэлгээр өгснөөр үүсэх хөнгөлөлт (вэб `uramshuulaliinBelegniiDun`).
  double get giftDiscount {
    if (!isGiftLine) return 0;
    final unit = undsenZarakhUne ?? 0;
    if (!unit.isFinite || unit <= 0) return 0;
    return unit * effectivePieces;
  }

  SaleItem({
    required this.product,
    required this.unitPrice,
    required this.retailUnitPrice,
    this.quantity = 1,
    this.uramshuulaliinId,
    this.forceRetailPricing = false,
    this.boxPiecesSold,
    this.soldWeightKg,
    this.serverRow,
    this.undsenZarakhUne,
    this.dorvonNegGiftLine = false,
  });

  double get _negPerBox {
    final n = product.negKhairtsaganDahiShirhegiinToo ?? 1;
    return n < 1 ? 1.0 : n.toDouble();
  }

  /// Нэг хайрцаг дахь ширхэг (хайрцагтай бараанд).
  double get negPerBox => _negPerBox;

  /// Нийт ширхэг (хайрцагтайд задлах эсвэл энгийн бараанд `quantity`).
  double get effectivePieces {
    if (product.isBoxSaleUnit) {
      return boxPiecesSold ?? (quantity * _negPerBox);
    }
    if (product.isWeightSaleUnit) {
      return soldWeightKg ?? quantity.toDouble();
    }
    return quantity.toDouble();
  }

  /// API `too`: хайрцагтайд хайрцгийн тоо (дробь зөвшөөрнө), бусадад `quantity`.
  double get apiTooUnits {
    if (product.isBoxSaleUnit) {
      return effectivePieces / _negPerBox;
    }
    if (product.isWeightSaleUnit) {
      return effectivePieces;
    }
    return quantity.toDouble();
  }

  double get total {
    if (product.isBoxSaleUnit) {
      final perPiece = unitPrice / _negPerBox;
      return perPiece * effectivePieces;
    }
    // `unitPrice` нь 1 кг-ийн үнэ тул бутархай кг-д шууд үржинэ.
    if (product.isWeightSaleUnit) {
      return unitPrice * effectivePieces;
    }
    return unitPrice * quantity;
  }

  SaleItem copyWith({
    Product? product,
    int? quantity,
    double? unitPrice,
    double? retailUnitPrice,
    String? uramshuulaliinId,
    bool? forceRetailPricing,
    double? boxPiecesSold,
    double? soldWeightKg,
    Map<String, dynamic>? serverRow,
    double? undsenZarakhUne,
    bool? dorvonNegGiftLine,
  }) {
    return SaleItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      retailUnitPrice: retailUnitPrice ?? this.retailUnitPrice,
      uramshuulaliinId: uramshuulaliinId ?? this.uramshuulaliinId,
      forceRetailPricing: forceRetailPricing ?? this.forceRetailPricing,
      boxPiecesSold: boxPiecesSold ?? this.boxPiecesSold,
      soldWeightKg: soldWeightKg ?? this.soldWeightKg,
      serverRow: serverRow ?? this.serverRow,
      undsenZarakhUne: undsenZarakhUne ?? this.undsenZarakhUne,
      dorvonNegGiftLine: dorvonNegGiftLine ?? this.dorvonNegGiftLine,
    );
  }

  /// `POST /uramshuulalShalgay` → `songogdsonEmnuud[]` мөр. Серверийн өмнөх
  /// хариуг (`serverRow`) суурь болгож, зөвхөн кассчны өөрчилсөн зүйлсийг
  /// (тоо, нэгж үнэ) дарж бичнэ — ингэснээр сервер зөвхөн өөрийн мэдэх
  /// талбаруудаа буцааж уншина.
  Map<String, dynamic> toUramshuulalRow({required String fallbackSalbariinId}) {
    final row = <String, dynamic>{
      ...(serverRow ??
          product.toBaraaDocument(fallbackSalbariinId: fallbackSalbariinId)),
    };
    row['shirkheg'] = effectivePieces;
    // `khamgiinKhyamdUnitPrice` салбарын `baraaHudaldahUne` тохиргооноос
    // хамаарч `zarakhUne` эсвэл `niitUne`-г уншдаг — хоёуланг нь мөрийн
    // бодит нэгж үнээр бичиж, аль ч тохиргоонд ижил үр дүн гаргана.
    //
    // Хайрцгийг задалж зарахад `shirkheg` нь ШИРХЭГ тул нэгж үнэ ч ширхэгийн
    // үнэ байх ёстой: `shirkheg × niitUne == [total]` тэнцэл үргэлж хадгална,
    // эс тэгвээс сервер урамшууллыг хайрцгийн үнээр бодож хэт өндөр
    // хөнгөлөлт гаргана.
    final perUnit = product.isBoxSaleUnit ? (unitPrice / _negPerBox) : unitPrice;
    final unit = isGiftLine ? 0.0 : perUnit;
    row['niitUne'] = unit;
    row['zarakhUne'] = unit;
    if (uramshuulaliinId != null && uramshuulaliinId!.trim().isNotEmpty) {
      row['uramshuulaliinId'] = uramshuulaliinId!.trim();
    } else {
      row.remove('uramshuulaliinId');
    }
    if (dorvonNegGiftLine) {
      row['dorvonNegGiftLine'] = true;
    } else {
      row.remove('dorvonNegGiftLine');
    }
    if (undsenZarakhUne != null) {
      row['undsenZarakhUne'] = undsenZarakhUne;
    }

    // `dorvonNegOriginalShirkheg` нь ЗӨВХӨН серверийн сүүлд буцаасан тоонд
    // хүчинтэй "хуваалтын өмнөх нийт" тэмдэглэгээ. Сервер (`/uramshuulalShalgay`)
    // энэ талбар байвал `shirkheg`-ийг ТҮҮГЭЭР ДАРЖ БИЧДЭГ:
    //
    //     if (hadPriorSplit) mur.shirkheg = mur.dorvonNegOriginalShirkheg;
    //
    // Тиймээс кассчин тоог өөрчилсний дараа ч хуучин тэмдэглэгээ хамт явбал
    // сервер шинэ тоог хаяад хуучин утгаараа дахин хуваадаг — сагс тухайн
    // барааны хувьд `buleg − chuluulekhToo` дээр (жиш. 3-т 1 үнэгүй дээр 2)
    // ГЯЛЖ ЗОГСДОГ, "+" хэдэн ч удаа дарсан нэмэгдэхгүй болдог байв.
    //
    // Мөрийн одоогийн тоо нь серверийн сүүлд өгсөн тоотой ТААРАХГҮЙ бол
    // тэмдэглэгээ хуучирсан гэсэн үг тул хаяна.
    final serverShirkheg = _numOrNull(serverRow?['shirkheg']);
    if (serverShirkheg == null || serverShirkheg != effectivePieces) {
      row.remove('dorvonNegOriginalShirkheg');
    }
    return row;
  }

  static double? _numOrNull(dynamic v) {
    if (v is num) return v.toDouble();
    if (v == null) return null;
    return double.tryParse(v.toString());
  }
}

class CompletedSale {
  final String id;
  final List<SaleItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String paymentMethod;
  final DateTime timestamp;
  final String? notes;
  /// Хөнгөлөлт (MNT), applied before VAT.
  final double discount;
  /// НХАТ (MNT). With web-parity cashier totals this is summed from line splits, not typed in.
  final double nhhat;

  /// НӨАТ-гүй дүн (суурь), web `noatguiDun` aggregate — thermal slip breakdown.
  final double noatguiSum;

  /// Staff snapshot from `guilgeeniiTuukh` / local completion (if available).
  final Map<String, dynamic>? ajiltan;

  /// From `guilgee.ebarimtAvsanEsekh` when loaded from POS API.
  final bool ebarimtAvsan;

  /// Total discount amount, including header discount, promotional discounts,
  /// and line-level discounts.
  double get effectiveDiscount {
    if (discount > 0.009) return discount;
    double itemDisc = 0.0;
    for (final item in items) {
      final orig = item.retailUnitPrice * item.quantity;
      final paid = item.total;
      final diff = orig - paid;
      if (diff > 0.001) {
        itemDisc += diff;
      }
    }
    return itemDisc;
  }

  CompletedSale({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.timestamp,
    this.notes,
    this.discount = 0,
    this.nhhat = 0,
    this.noatguiSum = 0,
    this.ajiltan,
    this.ebarimtAvsan = false,
  });

  double get netSubtotal => (subtotal - discount).clamp(0.0, double.infinity);
}

class SalesModel extends ChangeNotifier {
  final List<SaleItem> _currentSale = [];
  final List<CompletedSale> _salesHistory = [];
  Customer? _selectedCustomer;

  Customer? get selectedCustomer => _selectedCustomer;

  void setSelectedCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// Matches web POS `guilgeeniiDugaar` from `POST /zakhialgiinDugaarAvya`.
  String? _guilgeeniiDugaar;
  String? get guilgeeniiDugaar => _guilgeeniiDugaar;

  void setGuilgeeniiDugaar(String? value) {
    _guilgeeniiDugaar = value;
    notifyListeners();
  }

  /// Incremented when the user leaves the receipt screen to start a new sale so
  /// mobile cashier [POSScreen] can jump the PageView back to the product grid.
  int _cashierReturnToProductsEpoch = 0;
  int get cashierReturnToProductsEpoch => _cashierReturnToProductsEpoch;

  void signalCashierReturnToProductsAfterReceipt() {
    _cashierReturnToProductsEpoch++;
    notifyListeners();
  }

  // Current Sale getters
  List<SaleItem> get currentSaleItems => List.unmodifiable(_currentSale);
  bool get isSaleEmpty => _currentSale.isEmpty;
  int get saleItemCount => _currentSale.fold(0, (sum, item) => sum + item.quantity);

  /// Нийт ширхэгийн ойролцоо (хайрцагтай мөрүүдэд задласан ширхэг).
  int get salePieceCountApprox => _currentSale.fold(
        0,
        (sum, item) =>
            sum +
            (item.product.isBoxSaleUnit
                ? item.effectivePieces.round()
                : item.quantity),
      );

  /// Distinct бараа (төрөл), not raw row count — same бараа may appear as separate
  /// [SaleItem] rows; [currentSaleItems] stays separate for receipt / API lines.
  int get uniqueSaleItems {
    final keys = <String>{};
    for (final item in _currentSale) {
      keys.add(productLineKey(item.product));
    }
    return keys.length;
  }

  /// Сагсны мөрүүдийг БАРААГААР нь бүлэглэх түлхүүр — серверийн `lineKey`-тэй
  /// ижил (`code__barCode__salbariinId`).
  ///
  /// `_id`-гээр бүлэглэж БОЛОХГҮЙ: "N-т 1 үнэгүй"-ийн бэлэг мөр нь эх мөртэй
  /// ижил бараа боловч серверээс `<id>_gift_<promoId>` гэсэн өөр `_id`-тэй
  /// ирдэг. Ингэснээр нэг бараа хоёр мөр болж хуваагдахад "2 төрөл" гэж
  /// тоологдож, тоо ширхэг нь зөвхөн эхний мөрөөр харагддаг байв.
  static String productLineKey(Product p) {
    final code = (p.code ?? '').toString().trim();
    if (code.isNotEmpty) {
      final bar = (p.barCode ?? '').toString().trim();
      final sal = (p.salbariinId ?? '').toString().trim();
      return 'code:$code|$bar|$sal';
    }
    final id = p.id.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'ner:${p.name}';
  }

  /// Тухайн бараанаас сагсанд НИЙТ хэдэн ширхэг байгаа — урамшуулалаар
  /// үнэгүй болсон (0 үнэтэй) бэлэг мөрийг нь ОРУУЛААД.
  ///
  /// Барааны хайрцган дээрх "×N" тэмдэг үүнийг ашиглана: эс тэгвээс сервер
  /// мөрийг хуваасны дараа зөвхөн төлбөртэй хэсэг нь харагдаж, "+" дарахад
  /// тоо нь урагш-хойш үсэрч байгаа мэт харагдана.
  int qtyForProduct(Product p) {
    final key = productLineKey(p);
    var sum = 0;
    for (final line in _currentSale) {
      if (productLineKey(line.product) == key) sum += line.quantity;
    }
    return sum;
  }

  /// Сагсанд аль хэдийн "барьцаалсан" тоо ширхэг, `product.id`-гээр.
  ///
  /// [InventoryModel] нь серверээс үлдэгдлээ дахин ачаалах бүрд ҮҮНИЙГ
  /// дахин хасна. Эс тэгвээс сагстай байх үед ирсэн шинэчлэлт барьцааг
  /// арчиж, үлдэгдэл нь сагстайгаа салдаг (нэг л барааг хоёр удаа зарах
  /// боломж үүснэ).
  ///
  /// Бэлэг мөр нь үлдэгдлээс хасагдаагүй тул энд ОРОХГҮЙ.
  Map<String, int> get reservedQtyByProductId {
    final out = <String, int>{};
    for (final line in _currentSale) {
      if (line.isGiftLine) continue;
      final id = line.product.id.trim();
      if (id.isEmpty) continue;
      out[id] = (out[id] ?? 0) + line.quantity;
    }
    return out;
  }

  PosWebTaxContext? _webTaxContext;
  PosWebTaxContext? get webTaxContext => _webTaxContext;

  void setWebTaxContext(PosWebTaxContext? ctx) {
    _webTaxContext = ctx;
    notifyListeners();
  }

  /// Идэвхтэй "N-т 1 үнэгүй" (`uramshuulal.turul == "khamgiinKhyamd"`) бичлэг
  /// энэ салбарт байвал энд ачаалагдана — [UramshuulalService.fetchActive].
  Map<String, dynamic>? _dorvonNegPromo;
  Map<String, dynamic>? get dorvonNegPromo => _dorvonNegPromo;

  void setDorvonNegPromo(Map<String, dynamic>? promo) {
    _dorvonNegPromo = promo;
    _pruneStaleDorvonNegPicks();
    notifyListeners();
  }

  /// Чөлөөлөх сүүлийн нэгж(үүд)ийн үнэ өөр өөр 2+ баранд тэнцүү орсон үед
  /// (тэнцвэр) кассчингийн сонголт — [DorvonNegUramshuulal.compute] руу дамжина.
  Map<String, int> _dorvonNegManualPicks = const {};
  Map<String, int> get dorvonNegManualPicks => _dorvonNegManualPicks;

  void setDorvonNegManualPicks(Map<String, int> picks) {
    _dorvonNegManualPicks = Map.unmodifiable(picks);
    notifyListeners();
  }

  /// Урамшууллыг сервер (`POST /uramshuulalShalgay`) тооцож байгаа эсэх.
  /// Нэг удаа амжилттай тооцоолсны дараа асна — тэр үеэс эхлэн бэлэг мөрүүд
  /// сагсанд 0 үнээр бодитоор орж ирдэг тул клиент талын
  /// [DorvonNegUramshuulal] тооцоог ДАВХАР нэмэхгүй.
  bool _uramshuulalServerDriven = false;
  bool get uramshuulalServerDriven => _uramshuulalServerDriven;

  /// Серверийн буцаасан "N-т 1 үнэгүй"-ийн тэнцвэр (`dorvonNegTie`).
  Map<String, dynamic>? _serverDorvonNegTie;
  Map<String, dynamic>? get serverDorvonNegTie => _serverDorvonNegTie;

  /// Нэг урамшуулалд олон бэлэг байгаа тул кассчин сонгох ёстой (`songokhBelegnuud`).
  List<Map<String, dynamic>> _songokhBelegnuud = const [];
  List<Map<String, dynamic>> get songokhBelegnuud => _songokhBelegnuud;

  /// Кассчны сонгосон бэлгүүд — дараагийн `uramshuulalShalgay`-д буцаана.
  List<Map<String, dynamic>> _songogdsonBelegnuud = const [];
  List<Map<String, dynamic>> get songogdsonBelegnuud => _songogdsonBelegnuud;

  void setSongogdsonBelegnuud(List<Map<String, dynamic>> rows) {
    _songogdsonBelegnuud = List.unmodifiable(rows);
    notifyListeners();
  }

  /// Серверийн `dorvonNegTie`-г одоо байгаа тэнцвэрийн UI-д тааруулж
  /// хөрвүүлнэ. `discount`/`freeUnitsById` нь ЗОРИУДААР хоосон: чөлөөлөлт нь
  /// сагсанд 0 үнэтэй бэлэг мөр болж аль хэдийн орсон байдаг.
  DorvonNegCalcResult get _serverDorvonNegCalcView {
    final tie = _serverDorvonNegTie;
    if (tie == null) return DorvonNegUramshuulal.empty;
    if (tie['resolved'] == true) return DorvonNegUramshuulal.empty;
    final raw = tie['candidates'];
    if (raw is! List || raw.isEmpty) return DorvonNegUramshuulal.empty;
    final candidates = <DorvonNegTieCandidate>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final units = _rowNum(e['availableUnits']).round();
      if (units <= 0) continue;
      candidates.add(
        DorvonNegTieCandidate(
          id: e['id']?.toString() ?? '',
          name: (e['ner'] ?? e['code'] ?? '—').toString(),
          price: _rowNum(e['price']),
          availableUnits: units,
        ),
      );
    }
    if (candidates.isEmpty) return DorvonNegUramshuulal.empty;
    return DorvonNegCalcResult(
      tieCandidates: candidates,
      tieSlotsNeeded: _rowNum(tie['slotsNeeded']).round(),
    );
  }

  /// Сагсны нэгжүүд болон идэвхтэй урамшуулалд тулгуурлан "хамгийн хямд N
  /// үнэгүй" тооцоог хийнэ (freeCount/discount/freeUnitsById/тэнцвэр).
  ///
  /// Сервер тооцож эхэлсэн бол ([uramshuulalServerDriven]) хоосон буцаана —
  /// бэлэг мөр сагсанд аль хэдийн орсон тул давхар хөнгөлөлт үүсэхээс сэргийлнэ.
  DorvonNegCalcResult get dorvonNegCalc {
    if (_uramshuulalServerDriven) return _serverDorvonNegCalcView;
    final promo = _dorvonNegPromo;
    if (promo == null) return DorvonNegUramshuulal.empty;
    final rawBuleg = promo['buleg'];
    final buleg = (rawBuleg is num && rawBuleg > 0) ? rawBuleg.toInt() : 4;
    final lines = _currentSale
        .map((i) => DorvonNegLineInput(
              id: i.product.id,
              name: i.product.name,
              unitPrice: i.unitPrice,
              quantity: i.quantity,
            ))
        .toList();
    return DorvonNegUramshuulal.compute(
      lines: lines,
      buleg: buleg,
      manualPicks: _dorvonNegManualPicks,
    );
  }

  /// Сагс өөрчлөгдөх (нэмэх/хасах/тоо өөрчлөх) болгонд дуудна — тэнцвэр
  /// (tie) арилсан бол хуучин кассчингийн сонголтыг цэвэрлэнэ, эс тэгвээс
  /// шинэ тэнцвэрт хуучин сонголт санамсаргүй давхацвал (ижил id-тай бараа
  /// дахин тэнцвэрт орвол) буруу автомат үнэгүй сонгогдож болзошгүй. Web
  /// хувилбартай ижил (`pages/khyanalt/posSystem/index.js`, useEffect дээр
  /// `dorvonNegCalc.tieCandidates.length === 0` бол цэвэрлэдэг).
  void _pruneStaleDorvonNegPicks() {
    if (_dorvonNegManualPicks.isNotEmpty && !dorvonNegCalc.hasTie) {
      _dorvonNegManualPicks = const {};
    }
  }

  /// `POST /uramshuulalShalgay`-д илгээх сагс (вэб `songogdsonEmnuud`).
  List<Map<String, dynamic>> buildUramshuulalRows({
    required String fallbackSalbariinId,
  }) {
    return _currentSale
        .map((e) => e.toUramshuulalRow(fallbackSalbariinId: fallbackSalbariinId))
        .toList();
  }

  static double _rowNum(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0;
  }

  /// Серверийн эрх мэдэлтэй сагсаар [_currentSale]-г солино (вэб
  /// `setSongogdsomEmnuud(data.songogdsonEmnuud)`).
  ///
  /// Зөвхөн клиент талд амьдардаг төлөв (жижиглэнгийн суурь үнэ, гараар
  /// тогтоосон үнэ, хайрцаг задалсан ширхэг) хуучин мөрөөс хадгалагдана.
  void applyUramshuulalResult({
    required List<Map<String, dynamic>> songogdsonEmnuud,
    List<Map<String, dynamic>> songokhBelegnuud = const [],
    Map<String, dynamic>? dorvonNegTie,
  }) {
    final previousById = <String, SaleItem>{};
    for (final line in _currentSale) {
      previousById[line.product.id] = line;
    }

    final rebuilt = <SaleItem>[];
    for (final row in songogdsonEmnuud) {
      final product = Product.fromJson(row);
      // `shirkheg` нь ҮРГЭЛЖ ШИРХЭГ (эсвэл жингийн бараанд кг) — [toUramshuulalRow]
      // үүнийг [SaleItem.effectivePieces]-ээс бичдэг. Харин `quantity` нь
      // хайрцагтай бараанд ХАЙРЦГИЙН тоо. Өмнө нь энэ хоёрыг шууд тэнцүүлдэг
      // байсан тул урамшуулал шалгах бүрд 1 хайрцаг нь
      // `negKhairtsaganDahiShirhegiinToo` дахин үржиж (1 → 720) байв.
      final pieces = _rowNum(row['shirkheg']);
      if (pieces <= 0) continue;
      final int qtyUnits;
      if (product.isBoxSaleUnit) {
        final neg = product.negKhairtsaganDahiShirhegiinToo ?? 1;
        qtyUnits = (pieces / (neg < 1 ? 1 : neg)).ceil();
      } else if (product.isWeightSaleUnit) {
        qtyUnits = pieces.ceil();
      } else {
        qtyUnits = pieces.round();
      }

      final promoId = row['uramshuulaliinId']?.toString().trim();
      final isGift = promoId != null && promoId.isNotEmpty;
      final undsen = row.containsKey('undsenZarakhUne')
          ? _rowNum(row['undsenZarakhUne'])
          : null;
      final unitPrice = isGift ? 0.0 : _rowNum(row['niitUne']);

      final prior = previousById[product.id];
      rebuilt.add(
        SaleItem(
          product: product,
          quantity: qtyUnits < 1 ? 1 : qtyUnits,
          unitPrice: unitPrice,
          // Бэлэг мөрийн "суурь" үнэ нь жинхэнэ үнэ нь — ингэснээр
          // [effectiveDiscount] бэлгийн дүнг хөнгөлөлт болгож тооцно.
          retailUnitPrice: isGift
              ? (undsen ?? 0)
              : (prior?.retailUnitPrice ?? unitPrice),
          uramshuulaliinId: isGift ? promoId : null,
          forceRetailPricing: isGift ? false : (prior?.forceRetailPricing ?? false),
          // Серверийн буцаасан ширхэг нь эрх мэдэлтэй — бүхэлчилсэн
          // `qtyUnits` дээр найдвал задалсан ширхэг (1.5 хайрцаг) алдагдана.
          boxPiecesSold: isGift || !product.isBoxSaleUnit
              ? null
              : (pieces > 0 ? pieces : prior?.boxPiecesSold),
          soldWeightKg: isGift || !product.isWeightSaleUnit
              ? null
              : (pieces > 0 ? pieces : prior?.soldWeightKg),
          serverRow: row,
          undsenZarakhUne: undsen,
          dorvonNegGiftLine: row['dorvonNegGiftLine'] == true,
        ),
      );
    }

    _currentSale
      ..clear()
      ..addAll(rebuilt);
    _songokhBelegnuud = List.unmodifiable(songokhBelegnuud);
    _serverDorvonNegTie = dorvonNegTie;
    _uramshuulalServerDriven = true;
    // Серверийн тэнцвэр арилсан бол хуучин сонголтыг цэвэрлэнэ (вэбтэй ижил).
    if (dorvonNegTie == null && _dorvonNegManualPicks.isNotEmpty) {
      _dorvonNegManualPicks = const {};
    }
    notifyListeners();
  }

  /// Урамшууллаар үнэгүй өгсөн барааны нийт үнэ — вэб `tulburTuluhModal`-ын
  /// `uramshuulaliinBelegniiDun`. Бэлэг мөр 0 үнээр бичигддэг тул үүнийг
  /// гүйлгээний `hungulsunDun`-д нэмэхгүй бол баримтын жагсаалтын "Хөнгөлөлт"
  /// багана урамшуулалтай борлуулалт дээр үргэлж 0 гарна.
  double get uramshuulaliinBelegniiDun {
    var sum = 0.0;
    for (final item in _currentSale) {
      sum += item.giftDiscount;
    }
    return sum;
  }

  /// Хөнгөлөлт хасахаас өмнөх суурь дүн — мөр бүрийн **бодит зарах** дүнгийн
  /// нийлбэр (вэб `niitDunNoat`-ын `e.zarsanNiitUne` суурьтай ижил).
  ///
  /// [subtotal]-аас ялгаатай: тэр нь жижиглэнгийн `retailUnitPrice × quantity`
  /// тул бөөний үнэ, гараар засварласан үнэ, хайрцаг задалсан ширхэг зэрэг
  /// тохиолдолд илүү гарна. Кассын хөнгөлөлтийн дээд хязгаар болон дэлгэцэнд
  /// харагдах "Дүн" хоёулаа ЭНЭ дүнг ашиглах ёстой — эс тэгвээс харагдах
  /// суурь ба тооцоонд орох суурь зөрж, хөнгөлөлт давхар хасагдсан мэт
  /// харагдана.
  double get lineGrossBase {
    var sum = 0.0;
    for (final item in _currentSale) {
      final t = item.total;
      if (t.isFinite && t > 0) sum += t;
    }
    return sum;
  }

  /// 📊 Gross subtotal before discounts (retail unit price × quantity)
  double get subtotal {
    double sum = 0.0;
    for (final item in _currentSale) {
      sum += item.retailUnitPrice * item.quantity;
    }
    return sum;
  }

  /// 🎁 Total promotional & line discount amount
  double get effectiveDiscount {
    double itemDisc = dorvonNegCalc.discount;
    for (final item in _currentSale) {
      final orig = item.retailUnitPrice * item.quantity;
      final paid = item.total;
      final diff = orig - paid;
      if (diff > 0.001) {
        itemDisc += diff;
      }
    }
    return itemDisc;
  }

  double get tax {
    final ctx = _webTaxContext;
    if (ctx != null) {
      if (!ctx.borluulaltNUAT) return 0.0;
      return PosPaymentCore.calculateCashierTotalsWeb(
        lineGrossAmounts:
            _currentSale.map((e) => e.total.toDouble()).toList(),
        noatBodohPerLine:
            _currentSale.map((e) => e.product.noatBodohEsekh == true).toList(),
        nhatBodohPerLine:
            _currentSale.map((e) => e.product.nhatBodohEsekh == true).toList(),
        discountMnt: 0,
        ctx: ctx,
      ).vat;
    }
    return PosPaymentCore.calculateStandardSaleTotals(subtotal).vat;
  }

  /// 💰 Final net payable total (subtotal - discount)
  double get total => (subtotal - effectiveDiscount).clamp(0.0, double.infinity);

  /// Кассанд БОДИТООР авах дүн.
  ///
  /// НӨАТ-гүй борлуулалтад ([PosWebTaxContext.vatExcludedSale]) мөрийн дүнгээс
  /// НӨАТ хасагдаж (`/1.1`) төлөх дүн буурдаг — вэбийн `posSystem/index.js`
  /// нь `niitDun += e.zarsanNiitUne` (хуваасны дараах) → `turulruuKhiikhDun`
  /// гэж яг үүнийг кассанд авдаг.
  ///
  /// Өмнө нь борлуулалтын дэлгэц [total]-ыг (хуваалтгүй) харуулдаг байсан тул
  /// "Нийт төлөх 4,000₮" гэж бичээд, касс болон баримт дээр 3,636.36₮ гарч,
  /// НӨАТ дахин хасагдсан мэт харагддаг байв.
  double get payableTotal {
    final ctx = _webTaxContext;
    if (ctx == null || !ctx.vatExcludedSale) return total;
    return PosPaymentCore.calculateCashierTotalsWeb(
      lineGrossAmounts: _currentSale.map((e) => e.total.toDouble()).toList(),
      noatBodohPerLine:
          _currentSale.map((e) => e.product.noatBodohEsekh == true).toList(),
      nhatBodohPerLine:
          _currentSale.map((e) => e.product.nhatBodohEsekh == true).toList(),
      discountMnt: 0,
      ctx: ctx,
    ).total;
  }

  /// НӨАТ-гүй борлуулалтад мөрийн дүнгээс ХАСАГДСАН НӨАТ.
  ///
  /// Үүнийг харуулахгүй бол "Дүн" ба "Нийт төлөх"-ийн зөрүү тайлбаргүй үлдэнэ.
  double get excludedVat {
    final diff = total - payableTotal;
    return diff > 0.009 ? diff : 0.0;
  }

  /// НӨАТ-гүй дүн — тооцооны задаргаанд [tax]-ийн ДЭЭР харагдана.
  ///
  ///     нөатгүй дүн + НӨАТ == нийт төлөх
  ///
  /// Өмнө нь НӨАТ-ийн дээрх мөр нь НӨАТ багтсан бүтэн дүнг харуулдаг байсан
  /// тул НӨАТ нь дүн дээр НЭМЭГДЭЖ байгаа мэт уншигдаж, задаргаа нь нийт
  /// төлөхтэйгээ таардаггүй байв.
  double get netTotal => (payableTotal - tax).clamp(0.0, double.infinity);

  // Sales history getters
  List<CompletedSale> get salesHistory => List.unmodifiable(_salesHistory);

  double get todayRevenue {
    final today = DateTime.now();
    return _salesHistory
        .where((sale) =>
            sale.timestamp.year == today.year &&
            sale.timestamp.month == today.month &&
            sale.timestamp.day == today.day)
        .fold(0, (sum, sale) => sum + sale.total);
  }

  int get todayTransactions {
    final today = DateTime.now();
    return _salesHistory
        .where((sale) =>
            sale.timestamp.year == today.year &&
            sale.timestamp.month == today.month &&
            sale.timestamp.day == today.day)
        .length;
  }

  /// Sum of all completed sales kept in local history (this session / device).
  double get totalRecordedRevenue =>
      _salesHistory.fold(0.0, (sum, sale) => sum + sale.total);

  int get totalRecordedSaleCount => _salesHistory.length;

  // Current Sale methods
  void _reapplyWholesaleForIndex(int index) {
    if (index < 0 || index >= _currentSale.length) return;
    final line = _currentSale[index];
    if (line.forceRetailPricing) return;
    if (line.product.buuniiUneEsekh != true ||
        line.product.buuniiUneJagsaalt.isEmpty) {
      line.unitPrice = line.retailUnitPrice;
      return;
    }
    final tierQty = line.product.isBoxSaleUnit
        ? line.apiTooUnits
        : line.quantity.toDouble();
    final tier = BuuniiUneHelper.resolveUnitPrice(
      qty: tierQty,
      buuniiUneJagsaalt: line.product.buuniiUneJagsaalt,
      retailUnit: line.retailUnitPrice,
    );
    line.unitPrice = tier ?? line.retailUnitPrice;
  }

  void addToSale(Product product, {double? customPrice}) {
    final retail = customPrice ?? product.price;
    final existingIndex =
        _currentSale.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      final line = _currentSale[existingIndex];
      line.boxPiecesSold = null;
      line.soldWeightKg = null;
      line.quantity++;
      _reapplyWholesaleForIndex(existingIndex);
    } else {
      _currentSale.add(SaleItem(
        product: product,
        unitPrice: retail,
        retailUnitPrice: retail,
      ));
      _reapplyWholesaleForIndex(_currentSale.length - 1);
    }
    _pruneStaleDorvonNegPicks();
    notifyListeners();
  }

  /// Бөөний түвшингийн нэгж үнэ (гарын авлага) — дараагийн тоо өөрчлөлтөд tier дахин тооцохгүй.
  void applyWholesaleTierUnit(String productId, double tierUnitPrice) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].unitPrice = tierUnitPrice;
    _currentSale[i].forceRetailPricing = true;
    notifyListeners();
  }

  void applyRetailUnitForLine(String productId) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].unitPrice = _currentSale[i].retailUnitPrice;
    _currentSale[i].forceRetailPricing = true;
    notifyListeners();
  }

  /// Тоо ширхэгээр бөөний tier автоматаар (вэб `buuniiUneAvakh`).
  void useAutomaticWholesaleForProduct(String productId) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].forceRetailPricing = false;
    _reapplyWholesaleForIndex(i);
    notifyListeners();
  }

  void setLineUramshuulal(String productId, String? uramshuulaliinId) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].uramshuulaliinId = uramshuulaliinId;
    notifyListeners();
  }

  void removeFromSale(String productId) {
    _currentSale.removeWhere((item) => item.product.id == productId);
    _pruneStaleDorvonNegPicks();
    notifyListeners();
  }

  /// Картан дээрх тоо хэмжээний шошго — жингийн бараанд бодит жин.
  ///
  /// Жингийн мөрд "×1" гэж харуулах нь ХУДАЛ: 250 гр ч, 1 кг ч ижилхэн
  /// харагдаж, кассчин юу нэмснээ картаас мэдэхгүй байв. Жингийн бус
  /// бараанд `null` буцааж, картаа хэвийн "×N"-ээ хэвээр харуулна.
  String? saleQuantityLabel(Product product) {
    if (!product.isWeightSaleUnit) return null;
    final kg = _currentSale
        .where((e) => e.product.id == product.id && !e.isGiftLine)
        .fold<double>(0, (sum, e) => sum + e.effectivePieces);
    if (kg <= 0) return null;
    if (kg < 1) return '${(kg * 1000).toStringAsFixed(0)}гр';
    // Сүүлийн ач холбогдолгүй тэгүүдийг хасна: "2.50кг" биш "2.5кг".
    final text = kg
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '${text}кг';
  }

  /// Барааг сагснаас БҮРЭН хасаад нөөцөлсөн үлдэгдлийг нь буцаана.
  ///
  /// Картан дээрх (x) товч үүнийг дуудна. [removeFromSale] нь зөвхөн мөрийг
  /// устгадаг тул үүнийг ганцаар дуудвал барьцаалсан үлдэгдэл "алга болж",
  /// "сагс + үлдэгдэл == анхны үлдэгдэл" тэнцэл эвдэрнэ.
  void removeLineRestoringStock(
    String productId, {
    InventoryModel? inventory,
  }) {
    final lines = _currentSale.where((e) => e.product.id == productId);
    if (lines.isEmpty) return;
    // Бэлэг мөр үлдэгдэл барьцаалдаггүй тул буцаах тооноос хасна.
    final reserved = lines.fold<int>(
      0,
      (sum, e) => sum + (e.isGiftLine ? 0 : e.quantity),
    );
    if (inventory != null && reserved > 0) {
      inventory.restock(productId, reserved);
    }
    removeFromSale(productId);
  }

  void updateSaleQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromSale(productId);
      return;
    }
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _currentSale[index].boxPiecesSold = null;
      _currentSale[index].soldWeightKg = null;
      _currentSale[index].quantity = quantity;
      _reapplyWholesaleForIndex(index);
      _pruneStaleDorvonNegPicks();
      notifyListeners();
    }
  }

  void incrementSaleQuantity(String productId) {
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      final line = _currentSale[index];
      line.boxPiecesSold = null;
      line.soldWeightKg = null;
      line.quantity++;
      _reapplyWholesaleForIndex(index);
      _pruneStaleDorvonNegPicks();
      notifyListeners();
    }
  }

  /// Нэг ширхэг хасна. Үнэхээр хассан бол `true`.
  ///
  /// Буцаах утга нь ЧУХАЛ: дуудагч нь агуулахын үлдэгдлийг зөвхөн амжилттай
  /// хассан үед л буцааж нэмэх ёстой. Өмнө нь `_id`-гээр л хайдаг байсан тул
  /// урамшууллын дараа тухайн бараанаас зөвхөн бэлэг мөр
  /// (`<id>_gift_<promoId>`) үлдвэл юу ч хасагдалгүй чимээгүй өнгөрч, харин
  /// дуудагч нь үлдэгдлийг нэмсээр байдаг тул "−" дарах тусам ҮЛДЭГДЭЛ
  /// ӨСДӨГ байв.
  bool decrementSaleQuantity(Product product) {
    var index = _currentSale.indexWhere((e) => e.product.id == product.id);
    if (index < 0) {
      // Бэлэг мөр болж хуваагдсан байж болно — түлхүүрийг БАРААНААС нь
      // гаргана (мөрийн `_id` нь `<id>_gift_<promoId>` болж өөрчлөгддөг тул
      // сагснаас `_id`-гээр хайж олохгүй). Эхлээд ТӨЛБӨРТЭЙ мөрийг, эс
      // бөгөөс бэлэг мөрийг нь хасна.
      final key = productLineKey(product);
      index = _currentSale.indexWhere(
        (e) => productLineKey(e.product) == key && !e.isGiftLine,
      );
      if (index < 0) {
        index =
            _currentSale.indexWhere((e) => productLineKey(e.product) == key);
      }
    }
    if (index < 0) return false;

    final line = _currentSale[index];
    if (line.quantity > 1) {
      line.boxPiecesSold = null;
      line.soldWeightKg = null;
      line.quantity--;
      _reapplyWholesaleForIndex(index);
      _pruneStaleDorvonNegPicks();
      notifyListeners();
    } else {
      _currentSale.removeAt(index);
      _pruneStaleDorvonNegPicks();
      notifyListeners();
    }
    return true;
  }


  /// Хайрцагтай мөр: задлах ширхэг (вэб `khemjikhNegjUurchlukh`). [pieces] нь агуулах дахь
  /// нийт ширхэгийн хязгаарт байх ёстой.
  void setBoxLinePieces(
    String productId,
    double pieces, {
    InventoryModel? inventory,
  }) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    final line = _currentSale[i];
    if (!line.product.isBoxSaleUnit) return;
    final neg = line.negPerBox;
    final maxPieces = (line.product.uldegdel ?? line.product.stock) * neg;
    final clamped = pieces.clamp(0.01, maxPieces);
    final newQty = (clamped / neg).ceil().clamp(1, 999999);
    final oldQty = line.quantity;
    line.boxPiecesSold = clamped;
    line.quantity = newQty;
    if (inventory != null && oldQty != newQty) {
      if (oldQty > newQty) {
        inventory.restock(productId, oldQty - newQty);
      } else {
        // Хайрцгийн ширхэг нь үлдэгдлээр аль хэдийн хязгаарлагдсан.
        inventory.deductStock(productId, newQty - oldQty);
      }
    }
    _reapplyWholesaleForIndex(i);
    _pruneStaleDorvonNegPicks();
    notifyListeners();
  }

  /// Жингийн мөрийг ГРАММААР тохируулна ([setBoxLinePieces]-ийн яг адил зарчим).
  ///
  /// Үлдэгдэл нь бүхэл тоо (`int`) тул нөөцлөлтийг ДЭЭШ бүхэлчилнэ: 250 гр
  /// авахад 1 кг барьцаална. Ингэснээр хэзээ ч илүү зарахгүй бөгөөд
  /// "сагс + үлдэгдэл == анхны үлдэгдэл" тэнцэл хэвээр хадгалагдана.
  void setWeightLineGrams(
    String productId,
    double grams, {
    InventoryModel? inventory,
  }) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    final line = _currentSale[i];
    if (!line.product.isWeightSaleUnit) return;
    final maxKg =
        (line.product.uldegdel ?? line.product.stock).toDouble();
    final kg = (grams / 1000).clamp(0.001, maxKg <= 0 ? 0.001 : maxKg);
    final newQty = kg.ceil().clamp(1, 999999);
    final oldQty = line.quantity;
    line.soldWeightKg = kg;
    line.quantity = newQty;
    if (inventory != null && oldQty != newQty) {
      if (oldQty > newQty) {
        inventory.restock(productId, oldQty - newQty);
      } else {
        inventory.deductStock(productId, newQty - oldQty);
      }
    }
    _reapplyWholesaleForIndex(i);
    _pruneStaleDorvonNegPicks();
    notifyListeners();
  }

  void clearBoxLinePiecesOverride(String productId) {
    final i = _currentSale.indexWhere((e) => e.product.id == productId);
    if (i < 0) return;
    _currentSale[i].boxPiecesSold = null;
    _reapplyWholesaleForIndex(i);
    notifyListeners();
  }

  void updateSaleItemPrice(String productId, double newPrice) {
    final index = _currentSale.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _currentSale[index].unitPrice = newPrice;
      _currentSale[index].forceRetailPricing = true;
      notifyListeners();
    }
  }

  void clearSale() {
    _currentSale.clear();
    _guilgeeniiDugaar = null;
    _selectedCustomer = null;
    _dorvonNegManualPicks = const {};
    // Урамшууллын серверийн төлөв нь тухайн сагсных — шинэ захиалга дээр
    // хуучин бэлэг/тэнцвэр үлдэхгүй.
    _uramshuulalServerDriven = false;
    _serverDorvonNegTie = null;
    _songokhBelegnuud = const [];
    _songogdsonBelegnuud = const [];
    notifyListeners();
  }

  /// Replace cart with parked-sale lines and restore receipt number (web `huleelgeesHudaldahruuZakhialgaKhiiy`).
  void restoreParkedSale(
    List<SaleItem> lines, {
    required String guilgeeniiDugaar,
  }) {
    _currentSale
      ..clear()
      ..addAll(lines);
    _guilgeeniiDugaar = guilgeeniiDugaar;
    notifyListeners();
  }

  // Complete sale and add to history
  CompletedSale completeSale(
    String paymentMethod, {
    String? notes,
    String? orderId,
  }) {
    final std = PosPaymentCore.calculateStandardSaleTotals(subtotal);
    final sale = CompletedSale(
      id: orderId ?? PaymentDisplayConfig.generateLegacySaleId(),
      items: List.from(_currentSale),
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      timestamp: DateTime.now(),
      notes: notes,
      noatguiSum: std.net,
    );
    _salesHistory.add(sale);
    clearSale();
    return sale;
  }

  /// Cashier checkout: discount and НХАТ adjust totals; VAT (10%) on net subtotal.
  ///
  /// When [totalsSnapshot] is set (web-parity НӨАТ/НХАТ split), it is used instead of
  /// flat [calculateCashierTotals].
  CompletedSale completeCashierSale({
    required String paymentMethod,
    double discountMnt = 0,
    double nhhatMnt = 0,
    CashierTotals? totalsSnapshot,
    String? notes,
    String? orderId,
  }) {
    final t = totalsSnapshot ??
        PosPaymentCore.calculateCashierTotals(
          subtotal: subtotal,
          discountMnt: discountMnt,
          nhhatMnt: nhhatMnt,
        );
    final now = DateTime.now();
    final resolvedOrderId = orderId ?? PaymentDisplayConfig.generateOrderPreview();

    final sale = CompletedSale(
      id: resolvedOrderId,
      items: List.from(_currentSale),
      subtotal: subtotal,
      tax: t.vat,
      total: t.total,
      paymentMethod: paymentMethod,
      timestamp: now,
      notes: notes,
      discount: t.cappedDiscount,
      nhhat: t.nhhat,
      noatguiSum: t.net,
    );
    _salesHistory.add(sale);
    clearSale();
    return sale;
  }
}
