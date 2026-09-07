import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/payment_display_config.dart';
import '../../models/auth_model.dart';
import '../../models/cart_model.dart';
import '../../models/sales_model.dart';
import '../../payment/pos_payment_core.dart';
import '../../services/pos_settings_service.dart';
import '../../services/pos_transaction_service.dart';
import '../../services/printer_service.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import '../../utils/thermal_receipt_image.dart';
import '../../widgets/print_receipt_to_pos_button.dart';

/// Breakdown for thermal slip when cashier used хөнгөлөлт / НХАТ (И-Баримт not loaded yet).
class CashierSlipTotals {
  const CashierSlipTotals({
    required this.grossSubtotal,
    required this.discount,
    required this.noatgui,
    required this.noat,
    required this.nhat,
    required this.payable,
  });

  final double grossSubtotal;
  final double discount;
  final double noatgui;
  final double noat;
  final double nhat;
  final double payable;
}

/// Баримт дээр хэвлэгдэх нэг мөр.
///
/// [CartItem] нь зөвхөн (бараа, тоо) агуулдаг тул нэгж үнэ нь ВАРИАНТГҮЙ
/// каталогийн `product.price` болж, бөөний үнэ / гараар засварласан үнэ /
/// хайрцаг задалсан мөр дээр баримт нь бодит зарсан үнээ харуулдаггүй байв.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.quantityLabel,
    required this.unitPrice,
    required this.lineTotal,
    this.noatBodohEsekh = false,
    this.nhatiinDunPerUnit = 0,
    this.units = 1,
  });

  final String name;

  /// Тоо баганад бичигдэх бэлэн текст ("3" эсвэл "2\nхайрцаг").
  final String quantityLabel;

  /// Нэг нэгжийн бодит зарсан үнэ.
  final double unitPrice;

  /// Мөрийн нийт дүн (хөнгөлөлтийн өмнөх).
  final double lineTotal;

  final bool noatBodohEsekh;
  final double nhatiinDunPerUnit;
  final int units;
}

/// [CompletedSale]-ийн мөрүүдийг баримтын мөр болгоно — каталогийн үнэ биш,
/// БОДИТ зарсан нэгж үнэ / мөрийн дүнг авч явна.
List<ReceiptLine> buildReceiptLines(List<SaleItem> items) {
  return [
    for (final i in items)
      ReceiptLine(
        name: i.product.name,
        quantityLabel: i.product.isBoxSaleUnit
            ? '${i.apiTooUnits.toStringAsFixed(i.apiTooUnits % 1 == 0 ? 0 : 2)}\nхайрцаг'
            : '${i.quantity}',
        unitPrice: i.product.isBoxSaleUnit
            ? (i.negPerBox > 0 ? i.unitPrice / i.negPerBox : i.unitPrice)
            : i.unitPrice,
        lineTotal: i.total,
        noatBodohEsekh: i.product.noatBodohEsekh == true,
        nhatiinDunPerUnit: i.product.nhatiinDun ?? 0,
        units: i.quantity,
      ),
  ];
}

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({
    super.key,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.orderNumber,
    this.initialEbarimt,
    this.guilgeeniiMongoId,
    this.cashierSlipTotals,
    this.saleLines,
  });

  /// Бодит зарсан үнэ/дүнтэй мөрүүд. Өгөгдсөн бол [items]-ын оронд
  /// хэвлэгдэнэ.
  final List<ReceiptLine>? saleLines;

  final List<CartItem> items;
  final double total;
  final String paymentMethod;
  final String orderNumber;
  final Map<String, dynamic>? initialEbarimt;
  final String? guilgeeniiMongoId;
  final CashierSlipTotals? cashierSlipTotals;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final GlobalKey _printKey = GlobalKey();
  Map<String, dynamic>? _ebarimt;

  /// Matches typical grey counter behind a narrow thermal slip.
  static const Color _receiptPageBg = Color(0xFFBDBDBD);
  static const double _thermalPaperWidth = 380;

  PosWebTaxContext _taxContext = PosWebTaxContext.paymentDefault;
  String _merchantSalbarName = '';

  @override
  void initState() {
    super.initState();
    _ebarimt = widget.initialEbarimt;
    _loadTaxContext();
  }

  Future<void> _loadTaxContext() async {
    final auth = context.read<AuthModel>();
    final session = auth.posSession;
    if (session != null) {
      final salbaruud = await posSettingsService.fetchSalbaruud(session.baiguullagiinId);
      String salbarName = '';
      for (final s in salbaruud) {
        if (s['_id']?.toString() == session.salbariinId) {
          final raw = s['ner'] ?? s['name'] ?? s['salbariinNer'] ?? s['boginoNer'] ?? s['hayag'];
          salbarName = (raw ?? '').toString().trim();
          break;
        }
      }
      final ctx = await posSettingsService.loadPosWebTaxContext(
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
      );
      if (mounted) {
        setState(() {
          _taxContext = ctx;
          if (salbarName.isNotEmpty) {
            _merchantSalbarName = salbarName;
          }
        });
      }
    }
  }

  String get _paymentMethodName =>
      PaymentDisplayConfig.labelMn(widget.paymentMethod);

  void _startNewOrder(BuildContext context) {
    context.read<SalesModel>().signalCashierReturnToProductsAfterReceipt();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

  /// Subtotal line has no ₮ suffix — only the final payable/e-barimt amounts do.
  static String _fmtMntPlain(double v) => MntAmountFormatter.format(v);

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();

  static double _ebarimtKhungulukh(Map<String, dynamic>? e) {
    if (e == null) return 0;
    return _num(e['khungulukhDun']);
  }

  /// Баримтад хэвлэх мөрүүд — бодит зарсан үнэтэй [ReceiptScreen.saleLines]
  /// байвал түүнийг, эс бөгөөс каталогийн үнээр [ReceiptScreen.items]-ээс
  /// зохионо (хуучин дуудагчидтай нийцтэй байх).
  List<ReceiptLine> get _lines {
    final provided = widget.saleLines;
    if (provided != null) return provided;
    return [
      for (final i in widget.items)
        ReceiptLine(
          name: i.product.name,
          quantityLabel: i.product.isBoxSaleUnit
              ? '${i.quantity}\nхайрцаг'
              : '${i.quantity}',
          unitPrice: i.product.price,
          lineTotal: i.total,
          noatBodohEsekh: i.product.noatBodohEsekh == true,
          nhatiinDunPerUnit: i.product.nhatiinDun ?? 0,
          units: i.quantity,
        ),
    ];
  }

  /// Approximate НӨАТ / НӨАТ-гүй / НХАТ from cart when И-Баримт map is missing.
  static ({double noatgui, double noat, double nhat}) _cartTaxApprox(
      List<ReceiptLine> lines, {bool enableVat = true}) {
    var noatgui = 0.0;
    var noat = 0.0;
    var nhat = 0.0;
    for (final i in lines) {
      final lt = i.lineTotal;
      if (enableVat && i.noatBodohEsekh) {
        final net = lt / 1.1;
        noatgui += net;
        noat += lt - net;
      } else {
        noatgui += lt;
      }
      if (i.nhatiinDunPerUnit > 0) {
        nhat += i.nhatiinDunPerUnit * i.units;
      }
    }
    return (noatgui: noatgui, noat: noat, nhat: nhat);
  }

  /// e-barimt API / printer may use different keys for the QR payload.
  static String _qrDataFromEbarimt(Map<String, dynamic>? e) {
    if (e == null) return '';
    for (final key in const [
      'qrData',
      'qr_data',
      'QRData',
      'qr',
      'qrCode',
      'qrString',
    ]) {
      final s = _str(e[key]);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  /// [tatvaraasBaiguullagaAvya] merges `getInfo` with `tin`; name field varies.
  static String _companyNameFromTatvarMap(Map<String, dynamic>? m) {
    if (m == null) return '';
    for (final key in const [
      'name',
      'mongolianName',
      'companyName',
      'ner',
      'fullName',
      'buyerName',
      'baiguullagiinNer',
      'registerUserName',
    ]) {
      final s = _str(m[key]);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static String _companyNameFromEbarimt(Map<String, dynamic>? e) {
    if (e == null) return '';
    for (final key in const [
      'baiguullagiinNer',
      'companyDisplayName',
      'customerName',
      'buyerName',
      'companyName',
      'name',
    ]) {
      final s = _str(e[key]);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  /// Merges [tatvaraasBaiguullagaAvya] body (`name`, `tin`, …) into the e-barimt API map for the receipt.
  static Map<String, dynamic> mergeTatvarIntoEbarimtResult(
    Map<String, dynamic> apiResult,
    Map<String, dynamic>? tatvarLookup,
  ) {
    final m = Map<String, dynamic>.from(apiResult);
    final ner = _companyNameFromTatvarMap(tatvarLookup);
    if (ner.isNotEmpty) {
      m['baiguullagiinNer'] = ner;
      m['companyDisplayName'] = ner;
    }
    return m;
  }

  /// Thermal print: default [Text] line metrics add a large gap under/over dashes.
  static const Widget _thermalDashLine = Text(
    '----------------------------------------------',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.black,
      fontSize: 9,
      height: 1.0,
    ),
  );

  Future<void> _printOnPaxDevice(
    BuildContext context, {
    bool allowPdfFallback = true,
  }) async {
    try {
      final boundary = _printKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Print boundary not ready');
      }
      // High DPI + thermal binarization (see [encodeThermalReceiptPng]) so text stays
      // solid black on paper; low pixelRatio + PNG gray fringes look blurry on PAX.
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final Uint8List pngBytes;
      try {
        pngBytes = await encodeThermalReceiptPng(image);
      } finally {
        image.dispose();
      }
      final e = _ebarimt;
      final totalAmount =
          _num(e?['amount']) > 0 ? _num(e?['amount']) : _num(e?['totalAmount']);
      final dbRefNo =
          _str(e?['billId']).isNotEmpty ? _str(e?['billId']) : _str(e?['id']);
      final result = await PrinterService.printReceiptImage(
        pngBytes,
        amount: totalAmount > 0 ? totalAmount : widget.total,
        dbRefNo: dbRefNo.isNotEmpty ? dbRefNo : widget.orderNumber,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
          ),
        );
      }
      final lower = result.message.toLowerCase();
      if (!result.success &&
          allowPdfFallback &&
          (lower.contains('neptuneliteuser') ||
              lower.contains('classnotfound') ||
              lower.contains('neptune sdk not found'))) {
        await _printViaSystemDialog();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Терминал хэвлэгч байхгүй тул системийн хэвлэх цонх нээгдлээ'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Терминал хэвлэх алдаа: $e'),
          ),
        );
      }
    }
  }

  Future<void> _printViaSystemDialog() async {
    final e = _ebarimt;
    final totalAmount =
        _num(e?['amount']) > 0 ? _num(e?['amount']) : _num(e?['totalAmount']);
    final totalVat =
        _num(e?['vat']) > 0 ? _num(e?['vat']) : _num(e?['totalVAT']);
    final ddtd =
        _str(e?['billId']).isNotEmpty ? _str(e?['billId']) : _str(e?['id']);
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('E-BARIMT'),
            pw.Text('DDTD: $ddtd'),
            pw.Text('Amount: ${MntAmountFormatter.format(totalAmount)}'),
            pw.Text('VAT: ${MntAmountFormatter.format(totalVat)}'),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _onEbarimtPrintPressed(BuildContext context) async {
    if (_ebarimt != null) {
      await _printOnPaxDevice(context);
      return;
    }
    final auth = context.read<AuthModel>();
    final session = auth.posSession;
    final id = widget.guilgeeniiMongoId ?? '';
    // `POST /ebarimtShivye` нь гүйлгээний Mongo id-гүйгээр ажиллахгүй (офлайн
    // хадгалсан борлуулалт г.м.) — тэр үед дуугүй бүтэлгүйтэхийн оронд
    // шалтгааныг хэлээд энгийн баримтыг нь хэвлүүлнэ.
    if (id.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Гүйлгээ сервер дээр бүртгэгдээгүй тул И-Баримт авах боломжгүй — '
            'энгийн баримт хэвлэлээ',
          ),
        ),
      );
      await _printOnPaxDevice(context);
      return;
    }
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EbarimtBuyerDialog(
        guilgeeniiMongoId: id,
        baiguullagiinId: session?.baiguullagiinId ?? '',
        salbariinId: session?.salbariinId ?? '',
      ),
    );
    // Цонхыг цуцалсан бол цаас дэмий үрэхгүйн тулд автоматаар хэвлэхгүй —
    // оронд нь доод талын товчны эгнээнд И-Баримтаас хамаарахгүй "Баримт
    // хэвлэх" товч үргэлж байна.
    if (!mounted || !context.mounted || result == null) return;
    setState(() => _ebarimt = result);
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || !context.mounted) return;
    await _printOnPaxDevice(context);
  }

  /// Single label/value row on the white thermal receipt (black text).
  Widget _thermalPaymentMoneyRow(
    TextTheme t, {
    required String label,
    required String value,
    double fontSize = 14,
    FontWeight lw = FontWeight.w400,
    FontWeight vw = FontWeight.w500,
    double topPad = 2,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: t.bodySmall?.copyWith(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: lw,
                height: 1.15,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: t.bodySmall?.copyWith(
              color: Colors.black,
              fontSize: fontSize,
              fontWeight: vw,
              height: 1.15,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// Same layout as thermal print capture — white paper, black text, 380px.
  Widget _thermalReceiptInner(TextTheme textTheme, String cashierName) {
    final e = _ebarimt;
    final totalAmount =
        _num(e?['amount']) > 0 ? _num(e?['amount']) : _num(e?['totalAmount']);
    final totalVat =
        _num(e?['vat']) > 0 ? _num(e?['vat']) : _num(e?['totalVAT']);
    final totalCityTax = _num(e?['cityTax']) > 0
        ? _num(e?['cityTax'])
        : _num(e?['totalCityTax']);
    final ebarimtType =
        _str(e?['customerTin']).isNotEmpty || _str(e?['register']).length == 7
            ? 'ААН'
            : 'Иргэн';
    final ebarimtDate = _str(e?['date']);
    final ebarimtBillId = _str(e?['billId']);
    final ebarimtRegister = _str(e?['register']);
    final qrData = _qrDataFromEbarimt(e);
    final ebarimtCompanyNer = _companyNameFromEbarimt(e);
    final khungulE = _ebarimtKhungulukh(e);
    final auth = context.read<AuthModel>();
    final orgName = (ebarimtCompanyNer.isNotEmpty
            ? ebarimtCompanyNer
            : auth.merchantDisplayName)
        .trim();
    final salbarName = (_merchantSalbarName.isNotEmpty
            ? _merchantSalbarName
            : auth.activeSalbariinLabel)
        .trim();

    final canPosEbarimt = auth.canSubmitPosSales &&
        widget.guilgeeniiMongoId != null &&
        widget.guilgeeniiMongoId!.isNotEmpty;
    final enableTax = _taxContext.eBarimtShine || _taxContext.borluulaltNUAT;
    final receiptLines = _lines;
    final cartTax = _cartTaxApprox(receiptLines,
        enableVat: enableTax && (e != null || canPosEbarimt));
    final slip = widget.cashierSlipTotals;
    final thermalPay = e != null
        ? (totalAmount > 0 ? totalAmount : widget.total)
        : widget.total;
    final useSlip = e == null && slip != null;
    final thermalVat = enableTax
        ? (e != null ? totalVat : (useSlip ? slip.noat : cartTax.noat))
        : 0.0;
    final thermalCt = e != null
        ? totalCityTax
        : (useSlip ? slip.nhat : cartTax.nhat);
    final thermalNoatguiRaw = e != null
        ? (thermalPay - thermalVat - thermalCt)
        : (useSlip ? slip.noatgui : cartTax.noatgui);
    final thermalNoatgui = thermalNoatguiRaw < 0 ? 0.0 : thermalNoatguiRaw;
    // Баримт дээр харагдах хөнгөлөлт — И-Баримт авсан бол түүний `khungulukhDun`,
    // эс бөгөөс кассын тооцооны хөнгөлөлт.
    final thermalKhungulult = e != null ? khungulE : (useSlip ? slip.discount : 0.0);
    // "Нийт дүн" бол хөнгөлөлт хасахаас **өмнөх** суурь (вэб `niitDunNoat`:
    // `niitDun + hungulsunDun`). Өмнө нь И-Баримтгүй үед хөнгөлсний **дараах**
    // төлөх дүнг хэвлэчихээд дээр нь "Хөнгөлөлт −X" мөрийг бас гаргадаг байсан
    // тул баримт дээр хөнгөлөлт хоёр дахин хасагдсан мэт харагддаг байв.
    final thermalNiitDun = thermalPay + thermalKhungulult;
    final thermalTulukh = thermalPay;
    final thermalIb = thermalPay;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            '${orgName.isNotEmpty ? orgName.toUpperCase() : 'POSEASE'} БАРИМТ',
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 16,
            ),
          ),
        ),
        if (salbarName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Салбар: $salbarName',
            textAlign: TextAlign.start,
            style: textTheme.labelMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
        if (cashierName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Касс: $cashierName',
            textAlign: TextAlign.start,
            style: textTheme.labelMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          'БД: ${widget.orderNumber}',
          textAlign: TextAlign.start,
          style: textTheme.labelLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          MongolianDateFormatter.formatReceiptNumericDateTime(DateTime.now()),
          textAlign: TextAlign.start,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.black,
            fontSize: 13,
            fontFeatures: const [
              ui.FontFeature.tabularFigures(),
            ],
          ),
        ),
        if (e != null && ebarimtDate.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Огноо: $ebarimtDate',
            textAlign: TextAlign.start,
            style: textTheme.labelSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFeatures: const [
                ui.FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
        if (e != null && _taxContext.eBarimtShine && ebarimtBillId.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'ДДТД: $ebarimtBillId',
            textAlign: TextAlign.start,
            style: textTheme.labelSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              fontFeatures: const [
                ui.FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
        if (e != null && ebarimtRegister.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Регистр: $ebarimtRegister',
            textAlign: TextAlign.start,
            style: textTheme.labelSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
        if (ebarimtType == 'ААН' && ebarimtCompanyNer.isNotEmpty && ebarimtCompanyNer != orgName) ...[
          const SizedBox(height: 2),
          Text(
            'Худалдан авагч: $ebarimtCompanyNer',
            textAlign: TextAlign.start,
            style: textTheme.labelSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 1),
        _thermalDashLine,
        SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Бараа',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(
                width: 46,
                height: 12,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    'Тоо',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 76,
                child: Text(
                  'Үнэ',
                  textAlign: TextAlign.right,
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(
                width: 84,
                child: Text(
                  'Дүн',
                  textAlign: TextAlign.right,
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        ...receiptLines.take(8).map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        line.name,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          line.quantityLabel,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            height: line.quantityLabel.contains('\n') ? 1.05 : null,
                            fontFeatures: const [
                              ui.FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _fmtMntPlain(line.unitPrice),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            fontFeatures: const [
                              ui.FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _fmtMntPlain(line.lineTotal),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            fontFeatures: const [
                              ui.FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (receiptLines.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(
              '+${receiptLines.length - 8} бараа...',
              style: textTheme.labelSmall?.copyWith(
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
        _thermalDashLine,
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Text(
                'Төлбөр',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              Text(
                _paymentMethodName,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        // "Нийт дүн" (хөнгөлөхөөс өмнөх) → "Хөнгөлөлт" → … → "Төлөх дүн" гэсэн
        // дарааллаар: хасалт нь дээрх суурь дүнгээс хийгдэж байгаа нь баримт
        // дээр уншигдана.
        _thermalPaymentMoneyRow(
          textTheme,
          label: 'Нийт дүн',
          value: _fmtMntPlain(thermalNiitDun),
          topPad: 6,
          fontSize: 15,
        ),
        if (thermalKhungulult > 0.009)
          _thermalPaymentMoneyRow(
            textTheme,
            label: 'Хөнгөлөлт',
            value: '−${_fmtMnt(thermalKhungulult)}',
            fontSize: 14,
          ),
        if (e != null && thermalVat > 0) ...[
          _thermalPaymentMoneyRow(
            textTheme,
            label: 'НӨАТ-гүй дүн',
            value: _fmtMnt(thermalNoatgui),
            fontSize: 14,
          ),
          _thermalPaymentMoneyRow(
            textTheme,
            label: 'НӨАТ',
            value: _fmtMnt(thermalVat),
            fontSize: 14,
          ),
        ],
        if (thermalCt > 0)
          _thermalPaymentMoneyRow(
            textTheme,
            label: 'НХАТ',
            value: _fmtMnt(thermalCt),
            fontSize: 14,
          ),
        _thermalPaymentMoneyRow(
          textTheme,
          label: 'Төлөх дүн',
          value: _fmtMnt(thermalTulukh),
          fontSize: 16,
          lw: FontWeight.w600,
          vw: FontWeight.w700,
          topPad: 4,
        ),
        if (e != null && _taxContext.eBarimtShine)
          _thermalPaymentMoneyRow(
            textTheme,
            label: 'И-Баримт дүн',
            value: _fmtMnt(thermalIb),
            fontSize: 16,
            lw: FontWeight.w600,
            vw: FontWeight.w700,
          ),
        if (e != null && _taxContext.eBarimtShine) ...[
          const SizedBox(height: 4),
          _thermalDashLine,
          const SizedBox(height: 2),
          if (_str(e['lottery']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Сугалааны дугаар: ${_str(e['lottery'])}',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (qrData.isNotEmpty) ...[
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 280,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'QR уншуулаад баримтаа шалгана уу',
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
              Text(
                'Баярлалаа',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _buildCompleteBarimtData() {
    final auth = context.read<AuthModel>();
    final mName = _merchantSalbarName.isNotEmpty
        ? _merchantSalbarName
        : (auth.activeSalbariinLabel.isNotEmpty
            ? auth.activeSalbariinLabel
            : auth.merchantDisplayName);
    final Map<String, dynamic> map = {
      'orderNumber': widget.orderNumber,
      'totalAmount': widget.total,
      'paymentMethod': widget.paymentMethod,
      'baiguullagiinNer': mName,
      'eBarimtShine': _taxContext.eBarimtShine,
      'items': widget.items
          .map((i) => {
                'name': i.product.name,
                'count': i.quantity,
                'price': i.product.price,
                'sumPrice': i.total,
                'noatBodohEsekh': i.product.noatBodohEsekh,
                'nhatBodohEsekh': i.product.nhatBodohEsekh,
                'nhatiinDun': i.product.nhatiinDun,
              })
          .toList(),
    };
    if (_ebarimt != null) {
      map.addAll(_ebarimt!);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cashierName =
        (context.watch<AuthModel>().currentUser?.name ?? '').trim();
    final auth = context.watch<AuthModel>();
    final canPosEbarimt = auth.canSubmitPosSales &&
        widget.guilgeeniiMongoId != null &&
        widget.guilgeeniiMongoId!.isNotEmpty;

    return Scaffold(
      backgroundColor: _receiptPageBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: _receiptPageBg,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        key: _printKey,
                        child: Container(
                          width: _thermalPaperWidth,
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                          child: _thermalReceiptInner(textTheme, cashierName),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 6,
              shadowColor: Colors.black26,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _startNewOrder(context),
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Шинэ захиалга эхлүүлэх'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // И-Баримтын тохиргоо асаалттай үед нэмэлт товч гарна —
                      // гэхдээ энгийн "Баримт хэвлэх" нь ҮРГЭЛЖ байна. Өмнө нь
                      // `eBarimtShine` асаалттай бол цорын ганц товч нь
                      // И-Баримтын цонхоор дамждаг байсан тул цонхыг цуцлах /
                      // И-Баримт амжилтгүй болоход баримт огт хэвлэгддэггүй
                      // байв.
                      if (_taxContext.eBarimtShine) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _onEbarimtPrintPressed(context),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text(
                              _ebarimt != null
                                  ? 'И-Баримт хэвлэх'
                                  : 'И-Баримт сонгоод хэвлэх',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _printOnPaxDevice(context),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Баримт хэвлэх'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: PrintReceiptToPosButton(
                          salbariinId: context.read<AuthModel>().posSession?.salbariinId ?? '',
                          barimtType: 'ebarimt',
                          onBeforeSend: () async {
                            if (_ebarimt == null && canPosEbarimt && _taxContext.eBarimtShine) {
                              await _onEbarimtPrintPressed(context);
                            }
                            return _buildCompleteBarimtData();
                          },
                          barimtData: _buildCompleteBarimtData(),
                          label: 'ПОС терминал руу баримт хэвлэх',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web parity: [pos/components/modalBody/posSystem/eBarimt.js] — Иргэн vs ААН, `POST /ebarimtShivye`.
class _EbarimtBuyerDialog extends StatefulWidget {
  const _EbarimtBuyerDialog({
    required this.guilgeeniiMongoId,
    required this.baiguullagiinId,
    required this.salbariinId,
  });

  final String guilgeeniiMongoId;
  final String baiguullagiinId;
  final String salbariinId;

  @override
  State<_EbarimtBuyerDialog> createState() => _EbarimtBuyerDialogState();
}

class _EbarimtBuyerDialogState extends State<_EbarimtBuyerDialog> {
  bool _aan = false;
  final TextEditingController _reg = TextEditingController();
  bool _loading = false;
  String? _tin;

  /// Full JSON from `GET /tatvaraasBaiguullagaAvya/:regno` (includes `name`, `found`, `tin`).
  Map<String, dynamic>? _tatvarInfo;

  @override
  void dispose() {
    _reg.dispose();
    super.dispose();
  }

  static String? _tinFromMap(Map<String, dynamic>? m) {
    if (m == null) return null;
    final t = m['tin'] ?? m['data'];
    if (t == null) return null;
    final s = t.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _resolveTinForRegister(String reg) async {
    if (reg.isEmpty) {
      setState(() {
        _tin = null;
        _tatvarInfo = null;
      });
      return;
    }
    if (_aan && reg.length != 7) {
      setState(() {
        _tin = null;
        _tatvarInfo = null;
      });
      return;
    }
    if (!_aan && reg.length != 10) {
      setState(() {
        _tin = null;
        _tatvarInfo = null;
      });
      return;
    }
    setState(() => _loading = true);
    final info = await PosTransactionService().fetchTatvarRegisterInfo(reg);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _tin = _tinFromMap(info);
      _tatvarInfo = info;
    });
  }

  Future<void> _submit() async {
    final raw = _reg.text.trim();
    final reg = raw.toUpperCase();
    final svc = PosTransactionService();

    if (_aan) {
      if (reg.length != 7) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ААН байгууллагын регистр (7 орон) оруулна уу'),
            ),
          );
        }
        return;
      }
      setState(() => _loading = true);
      final result = await svc.requestEbarimtAfterSale(
        guilgeeniiMongoId: widget.guilgeeniiMongoId,
        baiguullagiinId: widget.baiguullagiinId,
        salbariinId: widget.salbariinId,
        register: reg,
        turul: '3',
        customerTin: (_tin != null && _tin!.isNotEmpty) ? _tin : null,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('И-Баримт авахад алдаа гарлаа')),
        );
        return;
      }
      Map<String, dynamic>? lookup = _tatvarInfo;
      lookup ??= await svc.fetchTatvarRegisterInfo(reg);
      if (!mounted) return;
      Navigator.of(context).pop(
        _ReceiptScreenState.mergeTatvarIntoEbarimtResult(result, lookup),
      );
      return;
    }

    // Иргэн — регистр заавал биш: хоосон бол нэргүй, бөглөсөн боловч ТТД
    // тохирохгүй/бүрэн бус байсан ч блоклохгүй, register-гүйгээр үргэлжилнэ.
    if (reg.isEmpty) {
      setState(() => _loading = true);
      final result = await svc.requestCitizenEbarimtAfterSale(
        guilgeeniiMongoId: widget.guilgeeniiMongoId,
        baiguullagiinId: widget.baiguullagiinId,
        salbariinId: widget.salbariinId,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('И-Баримт авахад алдаа гарлаа')),
        );
        return;
      }
      Navigator.of(context).pop(result);
      return;
    }

    var tin = _tin;
    Map<String, dynamic>? lookupForName = _tatvarInfo;
    if ((tin == null || tin.isEmpty) && reg.length == 10) {
      setState(() => _loading = true);
      final info = await svc.fetchTatvarRegisterInfo(reg);
      if (!mounted) return;
      tin = _tinFromMap(info);
      lookupForName = info;
      setState(() {
        _loading = false;
        _tin = tin;
        _tatvarInfo = info;
      });
    }

    setState(() => _loading = true);
    final result = await svc.requestEbarimtAfterSale(
      guilgeeniiMongoId: widget.guilgeeniiMongoId,
      baiguullagiinId: widget.baiguullagiinId,
      salbariinId: widget.salbariinId,
      register: reg,
      turul: '3',
      customerTin: (tin != null && tin.isNotEmpty) ? tin : null,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('И-Баримт авахад алдаа гарлаа')),
      );
      return;
    }
    Navigator.of(context).pop(
      _ReceiptScreenState.mergeTatvarIntoEbarimtResult(result, lookupForName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tatvarBaiguullagiinNer =
        _ReceiptScreenState._companyNameFromTatvarMap(_tatvarInfo);
    return AlertDialog(
      title: const Text('И-Баримт'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Иргэн'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('ААН'),
                ),
              ],
              selected: {_aan},
              onSelectionChanged: (s) {
                setState(() {
                  _aan = s.first;
                  _tin = null;
                  _tatvarInfo = null;
                  _reg.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reg,
              autofocus: true,
              // Урьд нь `enabled: !_loading` байсан тул ТТД шалгах хүсэлт
              // явахад талбар идэвхгүй болж, фокус/гар алдагдаад бичсэн
              // регистр харагдахаа больдог байв. Одоо талбар идэвхтэй хэвээр,
              // ачаалалт нь дүрсээр л мэдэгдэнэ.
              textCapitalization: TextCapitalization.characters,
              // Диалогийн текст загвар өвлөхгүйгээр ил өнгө өгнө.
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
              // Гар гарч ирэхэд талбар нь гарын ард дарагдахгүй байх зай.
              scrollPadding: const EdgeInsets.only(bottom: 120),
              keyboardType: _aan
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: _aan
                    ? 'Регистр (7 орон)'
                    : 'Регистр (заавал биш)',
                border: const OutlineInputBorder(),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (_) async {
                final r = _reg.text.trim().toUpperCase();
                if (_aan && r.length == 7) {
                  await _resolveTinForRegister(r);
                } else if (!_aan && r.length == 10) {
                  await _resolveTinForRegister(r);
                } else {
                  setState(() {
                    _tin = null;
                    _tatvarInfo = null;
                  });
                }
              },
            ),
            if (_tin != null && _tin!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'ТТД: $_tin',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_aan && tatvarBaiguullagiinNer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Байгууллагын нэр: $tatvarBaiguullagiinNer',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Болих'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Болсон'),
        ),
      ],
    );
  }
}
