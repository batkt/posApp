// Shared POS totals — keep in sync with pos/tools/logic/posPaymentCore.js where applicable.

/// Branch/org flags for tax split — mirrors web `pages/khyanalt/posSystem/index.js` (`niitDunNoat`).
class PosWebTaxContext {
  const PosWebTaxContext({
    required this.borluulaltNUAT,
    required this.eBarimtShine,
    this.isModalOpenTulbur = true,
    this.baraaNUATModalOpen = false,
  });

  /// Web `salbar?.tokhirgoo?.borluulaltNUAT` (org-level in mobile: from `baiguullaga.tokhirgoo`).
  final bool borluulaltNUAT;

  /// Web `salbar?.tokhirgoo?.eBarimtShine`.
  final bool eBarimtShine;

  /// Web payment step: `isModalOpenTulbur === true`.
  final bool isModalOpenTulbur;

  /// Web SKU VAT modal — mobile POS keeps `false` (same as paying on web register).
  final bool baraaNUATModalOpen;

  /// Until settings load — typical e-barимт POS (per-product НӨАТ flags respected).
  static const PosWebTaxContext paymentDefault = PosWebTaxContext(
    borluulaltNUAT: false,
    eBarimtShine: true,
    isModalOpenTulbur: true,
    baraaNUATModalOpen: false,
  );
}

/// One cart line after discount allocation — web per-row `noatiinDun` / `nhatiinDun` / `noatguiDun`.
class PosWebLineTax {
  const PosWebLineTax({
    required this.zarsanNiitUne,
    required this.noatiinDun,
    required this.nhatiinDun,
    required this.noatguiDun,
  });

  /// Line gross used for split (after optional `borluulaltNUAT` /1.1 strip).
  final double zarsanNiitUne;
  final double noatiinDun;
  final double nhatiinDun;
  final double noatguiDun;
}

class CashierTotals {
  const CashierTotals({
    required this.cappedDiscount,
    required this.net,
    required this.vat,
    required this.nhhat,
    required this.total,
  });

  final double cappedDiscount;
  final double net;
  final double vat;
  final double nhhat;
  final double total;
}

class StandardSaleTotals {
  const StandardSaleTotals({
    required this.subtotal,
    required this.net,
    required this.vat,
    required this.total,
  });

  /// Gross amount (VAT included).
  final double subtotal;
  /// Net amount (VAT excluded).
  final double net;
  final double vat;
  /// Final payable amount (for standard sale this equals gross).
  final double total;
}

abstract final class PosPaymentCore {
  PosPaymentCore._();

  static const double vatRate = 0.10;

  static const String methodCash = 'cash';
  static const String methodCard = 'card';
  /// Same as web `tulbur[].turul === "qpay"` (QuickQpay / merchant QR, not UniPOS).
  static const String methodQpay = 'qpay';
  static const String methodAccount = 'account';
  static const String methodCredit = 'credit';
  static const String methodMobile = 'mobile';

  static StandardSaleTotals calculateStandardSaleTotals(
    double subtotal, {
    double vatRate = PosPaymentCore.vatRate,
  }) {
    final gross = subtotal.clamp(0.0, double.infinity).toDouble();
    final net = gross / (1 + vatRate);
    final vat = gross - net;
    return StandardSaleTotals(
      subtotal: gross,
      net: net,
      vat: vat,
      total: gross,
    );
  }

  static CashierTotals calculateCashierTotals({
    required double subtotal,
    double discountMnt = 0,
    double nhhatMnt = 0,
    double vatRate = PosPaymentCore.vatRate,
  }) {
    final cappedDiscount = discountMnt.clamp(0.0, subtotal).toDouble();
    final grossAfterDiscount =
        (subtotal - cappedDiscount).clamp(0.0, double.infinity).toDouble();
    final net = grossAfterDiscount / (1 + vatRate);
    final vat = grossAfterDiscount - net;
    final nh = nhhatMnt.clamp(0.0, double.infinity).toDouble();
    final total = grossAfterDiscount + nh;
    return CashierTotals(
      cappedDiscount: cappedDiscount,
      net: net,
      vat: vat,
      nhhat: nh,
      total: total,
    );
  }

  static double _round2(double x) =>
      double.parse(x.clamp(0.0, double.infinity).toStringAsFixed(2));

  /// Single line — same logic as web `songogdsomEmnuud.map` tax block (simplified: no per-line loyalty).
  static PosWebLineTax computeLineTaxWeb({
    required double lineGrossAfterDiscount,
    required bool noatBodohEsekh,
    required bool nhatBodohEsekh,
    required PosWebTaxContext ctx,
  }) {
    var z = _round2(lineGrossAfterDiscount);
    if (z <= 0) {
      return const PosWebLineTax(
        zarsanNiitUne: 0,
        noatiinDun: 0,
        nhatiinDun: 0,
        noatguiDun: 0,
      );
    }

    if (ctx.borluulaltNUAT &&
        ctx.isModalOpenTulbur &&
        !ctx.baraaNUATModalOpen &&
        noatBodohEsekh) {
      z = _round2(z / 1.1);
    }

    var tempNoatBodohEsekh = ctx.borluulaltNUAT &&
            ctx.isModalOpenTulbur &&
            !ctx.baraaNUATModalOpen
        ? false
        : (ctx.eBarimtShine ? noatBodohEsekh : false);

    double noatiinDun = 0;
    double nhatiinDun = 0;

    if (nhatBodohEsekh && tempNoatBodohEsekh) {
      final negBaraaniiNoat = _round2(z / 1.12 / 10);
      noatiinDun = negBaraaniiNoat;
      nhatiinDun = _round2(negBaraaniiNoat / 5);
    } else if (tempNoatBodohEsekh && !nhatBodohEsekh) {
      noatiinDun = _round2(z / 1.1 / 10);
    } else if (!tempNoatBodohEsekh && nhatBodohEsekh) {
      nhatiinDun = _round2(z / 1.02 / 50);
    }

    final noatguiDun = _round2(z - noatiinDun - nhatiinDun);

    return PosWebLineTax(
      zarsanNiitUne: z,
      noatiinDun: noatiinDun,
      nhatiinDun: nhatiinDun,
      noatguiDun: noatguiDun > 0 ? noatguiDun : 0,
    );
  }

  /// Per-line splits after spreading [discountMnt] proportionally (web cart discount).
  static List<PosWebLineTax> computeLineTaxesForCart({
    required List<double> lineGrossAmounts,
    required List<bool> noatBodohPerLine,
    required List<bool> nhatBodohPerLine,
    required double discountMnt,
    required PosWebTaxContext ctx,
  }) {
    assert(lineGrossAmounts.length == noatBodohPerLine.length);
    assert(lineGrossAmounts.length == nhatBodohPerLine.length);

    final subtotal = lineGrossAmounts.fold<double>(
      0,
      (s, e) => s + (e.isFinite ? e : 0),
    );
    final cappedDiscount =
        discountMnt.clamp(0.0, subtotal > 0 ? subtotal : 0).toDouble();

    if (lineGrossAmounts.isEmpty) return [];

    if (subtotal <= 0) {
      return List<PosWebLineTax>.filled(
        lineGrossAmounts.length,
        const PosWebLineTax(
          zarsanNiitUne: 0,
          noatiinDun: 0,
          nhatiinDun: 0,
          noatguiDun: 0,
        ),
      );
    }

    final out = <PosWebLineTax>[];
    var allocatedDiscount = 0.0;
    for (var i = 0; i < lineGrossAmounts.length; i++) {
      final gross = lineGrossAmounts[i].clamp(0.0, double.infinity);
      final isLast = i == lineGrossAmounts.length - 1;
      final share = isLast
          ? _round2(cappedDiscount - allocatedDiscount)
          : _round2(cappedDiscount * gross / subtotal);
      allocatedDiscount = _round2(allocatedDiscount + share);
      final adj = _round2((gross - share).clamp(0.0, double.infinity));

      out.add(
        computeLineTaxWeb(
          lineGrossAfterDiscount: adj,
          noatBodohEsekh: noatBodohPerLine[i],
          nhatBodohEsekh: nhatBodohPerLine[i],
          ctx: ctx,
        ),
      );
    }
    return out;
  }

  /// Cart-level totals matching web `niitDunNoat` aggregation (invoice discount spread by line share).
  static CashierTotals calculateCashierTotalsWeb({
    required List<double> lineGrossAmounts,
    required List<bool> noatBodohPerLine,
    required List<bool> nhatBodohPerLine,
    required double discountMnt,
    required PosWebTaxContext ctx,
  }) {
    final splits = computeLineTaxesForCart(
      lineGrossAmounts: lineGrossAmounts,
      noatBodohPerLine: noatBodohPerLine,
      nhatBodohPerLine: nhatBodohPerLine,
      discountMnt: discountMnt,
      ctx: ctx,
    );

    final subtotal = lineGrossAmounts.fold<double>(
      0,
      (s, e) => s + (e.isFinite ? e : 0),
    );
    final cappedDiscount =
        discountMnt.clamp(0.0, subtotal > 0 ? subtotal : 0).toDouble();

    if (lineGrossAmounts.isEmpty || subtotal <= 0) {
      return CashierTotals(
        cappedDiscount: cappedDiscount,
        net: 0,
        vat: 0,
        nhhat: 0,
        total: 0,
      );
    }

    double sumNoat = 0;
    double sumNhat = 0;
    double sumNoatgui = 0;
    double sumZarsan = 0;
    for (final split in splits) {
      sumNoat = _round2(sumNoat + split.noatiinDun);
      sumNhat = _round2(sumNhat + split.nhatiinDun);
      sumNoatgui = _round2(sumNoatgui + split.noatguiDun);
      sumZarsan = _round2(sumZarsan + split.zarsanNiitUne);
    }

    return CashierTotals(
      cappedDiscount: cappedDiscount,
      net: sumNoatgui,
      vat: sumNoat,
      nhhat: sumNhat,
      total: sumZarsan,
    );
  }

  static String generateOrderPreview() {
    final n = DateTime.now();
    final tail =
        (n.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'БД${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}$tail';
  }

  static String generateLegacySaleId() {
    return 'SALE-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }
}
