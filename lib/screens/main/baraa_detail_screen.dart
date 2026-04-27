import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/staff_screen_access.dart';
import '../../models/auth_model.dart';
import '../../models/inventory_model.dart';
import '../../models/locale_model.dart';
import '../../models/cart_model.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import '../../widgets/authenticated_image.dart';

/// One row of web `Form.List` / `aguulakh.buuniiUneJagsaalt` (`buuniiToo`, `buuniiUne`).
class _BuuniiTierCtrls {
  _BuuniiTierCtrls({String too = '', String une = ''})
      : too = TextEditingController(text: too),
        une = TextEditingController(text: une);

  final TextEditingController too;
  final TextEditingController une;

  void dispose() {
    too.dispose();
    une.dispose();
  }
}

class BaraaDetailScreen extends StatefulWidget {
  const BaraaDetailScreen({super.key, required this.item, this.startEditing = false});

  final InventoryItem item;
  final bool startEditing;

  @override
  State<BaraaDetailScreen> createState() => _BaraaDetailScreenState();
}

class _BaraaDetailScreenState extends State<BaraaDetailScreen> {
  static final _productApi = ProductService();
  late InventoryItem _item;
  bool _editing = false;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _ner;
  late final TextEditingController _bogino;
  late final TextEditingController _code;
  late final TextEditingController _barCode;
  late final TextEditingController _khemjikh;
  late final TextEditingController _angilal;
  late final TextEditingController _niitUne;
  late final TextEditingController _urtugUne;
  late final TextEditingController _uldegdel;
  late final TextEditingController _negKhairtsag;

  bool _idevkhteiEsekh = true;
  bool _noatBodohEsekh = true;
  bool _nhatBodohEsekh = true;
  bool _shirkheglekhEsekh = false;
  bool _buuniiUneEsekh = false;
  final List<_BuuniiTierCtrls> _buuniiTiers = [];

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _editing = widget.startEditing;
    _ner = TextEditingController();
    _bogino = TextEditingController();
    _code = TextEditingController();
    _barCode = TextEditingController();
    _khemjikh = TextEditingController();
    _angilal = TextEditingController();
    _niitUne = TextEditingController();
    _urtugUne = TextEditingController();
    _uldegdel = TextEditingController();
    _negKhairtsag = TextEditingController();
    _applyProductToForm();
  }

  void _applyProductToForm() {
    final p = _item.product;
    _ner.text = p.name;
    _bogino.text = p.boginoNer ?? '';
    _code.text = p.code ?? '';
    _barCode.text = p.barCode ?? '';
    _khemjikh.text = p.khemjikhNegj ?? '';
    _angilal.text = (p.angilal != null && p.angilal!.trim().isNotEmpty)
        ? p.angilal!
        : p.category;
    _niitUne.text = _formatNum(
        (p.niitUne != null && p.niitUne! > 0) ? p.niitUne! : p.price);
    _urtugUne.text = p.urtugUne != null && p.urtugUne! > 0
        ? _formatNum(p.urtugUne)
        : '';
    _uldegdel.text = '${p.uldegdel ?? _item.currentStock}';
    _negKhairtsag.text =
        p.negKhairtsaganDahiShirhegiinToo?.toString() ?? '';

    _idevkhteiEsekh = p.isAvailable;
    _noatBodohEsekh = p.noatBodohEsekh ?? true;
    _nhatBodohEsekh = p.nhatBodohEsekh ?? true;
    _shirkheglekhEsekh = p.shirkheglekhEsekh ?? p.isBoxSaleUnit;
    _buuniiUneEsekh = p.buuniiUneEsekh ?? false;
    _syncBuuniiTiersFromProduct();
  }

  void _syncBuuniiTiersFromProduct() {
    for (final c in _buuniiTiers) {
      c.dispose();
    }
    _buuniiTiers.clear();
    for (final m in _item.product.buuniiUneJagsaalt) {
      final t = m['buuniiToo'];
      final u = m['buuniiUne'];
      final uneStr = u == null
          ? ''
          : _formatNum(
              u is num ? u.toDouble() : _parseDoubleLoose(u.toString()),
            );
      _buuniiTiers.add(
        _BuuniiTierCtrls(
          too: t == null ? '' : t.toString(),
          une: uneStr,
        ),
      );
    }
  }

  void _disposeBuuniiTiers() {
    for (final c in _buuniiTiers) {
      c.dispose();
    }
    _buuniiTiers.clear();
  }

  void _addBuuniiTier() {
    setState(() => _buuniiTiers.add(_BuuniiTierCtrls()));
  }

  void _removeBuuniiTier(int index) {
    if (index < 0 || index >= _buuniiTiers.length) return;
    setState(() {
      _buuniiTiers[index].dispose();
      _buuniiTiers.removeAt(index);
    });
  }

  String _formatNum(double? n) {
    if (n == null) return '';
    if (n == n.roundToDouble()) return '${n.toInt()}';
    return n.toString();
  }

  double _parseDoubleLoose(String s) {
    final t = s.replaceAll(RegExp(r'[,\s]'), '');
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  int _parseIntLoose(String s) {
    final t = s.replaceAll(RegExp(r'[,\s]'), '');
    if (t.isEmpty) return 0;
    return int.tryParse(t) ?? 0;
  }

  @override
  void dispose() {
    _ner.dispose();
    _bogino.dispose();
    _code.dispose();
    _barCode.dispose();
    _khemjikh.dispose();
    _angilal.dispose();
    _niitUne.dispose();
    _urtugUne.dispose();
    _uldegdel.dispose();
    _negKhairtsag.dispose();
    _disposeBuuniiTiers();
    super.dispose();
  }

  bool _getCanEdit(StaffScreenAccess a) => a.allowsBaraaEdit;

  String _yn(AppLocalizations l10n, bool? v) {
    if (v == null) return l10n.tr('yn_dash');
    return v ? l10n.tr('yn_yes') : l10n.tr('yn_no');
  }

  List<Map<String, dynamic>> _collectBuuniiTiersPayload() {
    final out = <Map<String, dynamic>>[];
    for (final c in _buuniiTiers) {
      final t = _parseIntLoose(c.too.text);
      final u = _parseDoubleLoose(c.une.text);
      if (t > 0 && u > 0) {
        out.add({'buuniiToo': t, 'buuniiUne': u});
      }
    }
    return out;
  }

  /// Same rules as web `baraaBurtgekh.js` `validateForm` (tier qty ascending, price descending vs retail).
  bool _validateBuuniiTiers(
    double retail,
    List<Map<String, dynamic>> tiers,
    AppLocalizations l10n,
  ) {
    if (tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('baraa_buunii_empty'))),
      );
      return false;
    }
    for (var i = 0; i < tiers.length; i++) {
      final t = tiers[i]['buuniiToo'] as int;
      final u = (tiers[i]['buuniiUne'] as num).toDouble();
      if (retail <= u) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tr('baraa_buunii_retail_gt'))),
        );
        return false;
      }
      if (i > 0) {
        final pt = tiers[i - 1]['buuniiToo'] as int;
        final pu = (tiers[i - 1]['buuniiUne'] as num).toDouble();
        if (pt >= t) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.tr('baraa_buunii_too_ascend'))),
          );
          return false;
        }
        if (pu <= u) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.tr('baraa_buunii_une_descend'))),
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final p = _item.product;
    if (p.baiguullagiinId == null ||
        p.salbariinId == null ||
        p.id.isEmpty) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final niit = _parseDoubleLoose(_niitUne.text);
    final urtug = _parseDoubleLoose(_urtugUne.text);
    final ul = _parseIntLoose(_uldegdel.text);
    final negK = _parseIntLoose(_negKhairtsag.text);

    if (_shirkheglekhEsekh && negK < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('baraa_pcs_per_box_required'))),
      );
      return;
    }

    var buuniiPayload = <Map<String, dynamic>>[];
    if (_buuniiUneEsekh) {
      buuniiPayload = _collectBuuniiTiersPayload();
      if (!_validateBuuniiTiers(niit, buuniiPayload, l10n)) return;
    }

    final body = <String, dynamic>{
      'baiguullagiinId': p.baiguullagiinId,
      'salbariinId': p.salbariinId,
      'ner': _ner.text.trim(),
      'boginoNer': _bogino.text.trim().isEmpty ? null : _bogino.text.trim(),
      'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
      'barCode': _barCode.text.trim().isEmpty ? null : _barCode.text.trim(),
      'khemjikhNegj':
          _khemjikh.text.trim().isEmpty ? null : _khemjikh.text.trim(),
      'angilal': _angilal.text.trim().isEmpty ? null : _angilal.text.trim(),
      'niitUne': niit,
      'urtugUne': urtug,
      'uldegdel': ul,
      'idevkhteiEsekh': _idevkhteiEsekh,
      'noatBodohEsekh': _noatBodohEsekh,
      'nhatBodohEsekh': _nhatBodohEsekh,
      'shirkheglekhEsekh': _shirkheglekhEsekh,
      'buuniiUneEsekh': _buuniiUneEsekh,
      'buuniiUneJagsaalt': buuniiPayload,
    };
    if (negK > 0) {
      body['negKhairtsaganDahiShirhegiinToo'] = negK;
    } else {
      body['negKhairtsaganDahiShirhegiinToo'] = null;
    }
    body.removeWhere((k, v) => v == null);

    setState(() => _saving = true);
    final r = await _productApi.updateAguulakh(p.id, fields: body);
    if (!mounted) return;
    setState(() => _saving = false);

    if (!r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(r.error ?? l10n.tr('staff_admin_save_failed')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await context.read<InventoryModel>().refreshInventory();
    if (!mounted) return;
    final inv = context.read<InventoryModel>();
    try {
      final found = inv.inventory.firstWhere(
        (e) => e.product.id == p.id,
      );
      setState(() {
        _item = found;
        _editing = false;
        _applyProductToForm();
      });
    } catch (_) {
      setState(() => _editing = false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.tr('baraa_saved')),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final access = context.watch<AuthModel>().staffAccess;
    final canEdit = _getCanEdit(access);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final product = _item.product;

    final categoryLabel = product.category.trim().isNotEmpty
        ? product.category
        : (product.angilal?.trim().isNotEmpty == true
            ? product.angilal!.trim()
            : '—');
    final hasImage = product.imageUrl.trim().isNotEmpty;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    Color stockColor;
    String stockLabel;
    if (_item.isOutOfStock) {
      stockColor = AppColors.error;
      stockLabel = 'Дууссан';
    } else if (_item.isLowStock) {
      stockColor = AppColors.warning;
      stockLabel = 'Цөөн үлдсэн';
    } else {
      stockColor = AppColors.success;
      stockLabel = 'Бэлэн байна';
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            foregroundColor: colorScheme.onSurface,
            leading: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.92),
                ),
                onPressed: () {
                  if (_editing) {
                    setState(() {
                      _editing = false;
                      _applyProductToForm();
                    });
                  } else {
                    Navigator.maybePop(context);
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
            ),
            actions: [
              if (canEdit && !_editing)
                TextButton(
                  onPressed: () => setState(() => _editing = true),
                  child: Text(l10n.tr('baraa_edit')),
                ),
              if (canEdit && _editing) ...[
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _editing = false;
                            _applyProductToForm();
                          });
                        },
                  child: Text(l10n.tr('baraa_cancel')),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FilledButton(
                    onPressed: _saving ? null : _onSave,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.tr('baraa_save')),
                  ),
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    AuthenticatedImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                    )
                  else
                    ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.shadow.withValues(alpha: 0.18),
                          Colors.transparent,
                          colorScheme.shadow.withValues(alpha: 0.45),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _editing
                  ? _EditForm(
                      l10n: l10n,
                      formKey: _formKey,
                      ner: _ner,
                      bogino: _bogino,
                      code: _code,
                      barCode: _barCode,
                      khemjikh: _khemjikh,
                      angilal: _angilal,
                      niitUne: _niitUne,
                      urtugUne: _urtugUne,
                      uldegdel: _uldegdel,
                      negKhairtsag: _negKhairtsag,
                      buuniiTiers: _buuniiTiers,
                      idevkhtei: _idevkhteiEsekh,
                      noat: _noatBodohEsekh,
                      nhat: _nhatBodohEsekh,
                      shirkheg: _shirkheglekhEsekh,
                      buunii: _buuniiUneEsekh,
                      onIdevkhtei: (v) =>
                          setState(() => _idevkhteiEsekh = v),
                      onNoat: (v) => setState(() => _noatBodohEsekh = v),
                      onNhat: (v) => setState(() => _nhatBodohEsekh = v),
                      onShirkheg: (v) => setState(() {
                        _shirkheglekhEsekh = v;
                        if (!v) {
                          _negKhairtsag.clear();
                        }
                      }),
                      onBuunii: (v) => setState(() {
                        _buuniiUneEsekh = v;
                        if (!v) {
                          _disposeBuuniiTiers();
                        } else if (_buuniiTiers.isEmpty) {
                          _buuniiTiers.add(_BuuniiTierCtrls());
                        }
                      }),
                      onAddBuuniiTier: _addBuuniiTier,
                      onRemoveBuuniiTier: _removeBuuniiTier,
                    )
                  : _ViewContent(
                      l10n: l10n,
                      product: product,
                      item: _item,
                      categoryLabel: categoryLabel,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      stockColor: stockColor,
                      stockLabel: stockLabel,
                      yn: _yn,
                    ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16 + bottomPad)),
        ],
      ),
    );
  }
}

class _ViewContent extends StatelessWidget {
  const _ViewContent({
    required this.l10n,
    required this.product,
    required this.item,
    required this.categoryLabel,
    required this.textTheme,
    required this.colorScheme,
    required this.stockColor,
    required this.stockLabel,
    required this.yn,
  });

  final AppLocalizations l10n;
  final Product product;
  final InventoryItem item;
  final String categoryLabel;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final Color stockColor;
  final String stockLabel;
  final String Function(AppLocalizations, bool?) yn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Барааны мэдээлэл',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.name,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.2,
          ),
        ),
        if (product.boginoNer != null && product.boginoNer!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            product.boginoNer!,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (categoryLabel != '—')
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(categoryLabel),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _FlagGrid(l10n: l10n, product: product, yn: yn, colorScheme: colorScheme, textTheme: textTheme),
        const SizedBox(height: 16),
        _MetaPill(
          label: l10n.tr('baraa_code'),
          value: product.code?.isNotEmpty == true ? product.code! : '—',
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 6),
        _MetaPill(
          label: l10n.tr('baraa_barcode'),
          value: product.barCode?.isNotEmpty == true ? product.barCode! : '—',
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 6),
        _MetaPill(
          label: l10n.tr('baraa_sell_price'),
          value: MntAmountFormatter.formatTugrik(
            (product.niitUne != null && product.niitUne! > 0)
                ? product.niitUne!
                : product.price,
          ),
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        if (product.urtugUne != null && product.urtugUne! > 0) ...[
          const SizedBox(height: 6),
          _MetaPill(
            label: l10n.tr('baraa_urtug'),
            value: MntAmountFormatter.formatTugrik(product.urtugUne!),
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
        const SizedBox(height: 6),
        _MetaPill(
          label: l10n.tr('baraa_khemjikh'),
          value: product.khemjikhNegj ?? '—',
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: stockColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stockColor.withValues(alpha: 0.38)),
          ),
          child: Row(
            children: [
              Icon(
                item.isOutOfStock
                    ? Icons.remove_circle_outline
                    : item.isLowStock
                        ? Icons.warning_amber_outlined
                        : Icons.check_circle_outline,
                color: stockColor,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stockLabel,
                      style: textTheme.titleSmall?.copyWith(
                        color: stockColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.tr('baraa_uldegdel')}: ${item.currentStock} ${product.posStockQuantitySuffix}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              FittedBox(
                child: Text(
                  '${item.currentStock}',
                  style: textTheme.displaySmall?.copyWith(
                    color: stockColor,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (item.lastRestocked != null) ...[
          _MetaPill(
            label: 'Сүүлд нөхсөн',
            value: MongolianDateFormatter.formatShortDate(item.lastRestocked!),
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FlagGrid extends StatelessWidget {
  const _FlagGrid({
    required this.l10n,
    required this.product,
    required this.yn,
    required this.colorScheme,
    required this.textTheme,
  });

  final AppLocalizations l10n;
  final Product product;
  final String Function(AppLocalizations, bool?) yn;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Тохиргоо',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _gridRow(
                l10n.tr('baraa_flag_idevkhtei'), yn(l10n, product.isAvailable)),
            _gridRow(l10n.tr('baraa_flag_noat'), yn(l10n, product.noatBodohEsekh)),
            _gridRow(l10n.tr('baraa_flag_nhat'), yn(l10n, product.nhatBodohEsekh)),
            _gridRow(
                l10n.tr('baraa_flag_shirkheg'),
                yn(l10n, product.shirkheglekhEsekh)),
            _gridRow(
                l10n.tr('baraa_flag_buunii'),
                yn(l10n, product.buuniiUneEsekh)),
          ],
        ),
      ),
    );
  }

  Widget _gridRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.l10n,
    required this.formKey,
    required this.ner,
    required this.bogino,
    required this.code,
    required this.barCode,
    required this.khemjikh,
    required this.angilal,
    required this.niitUne,
    required this.urtugUne,
    required this.uldegdel,
    required this.negKhairtsag,
    required this.buuniiTiers,
    required this.idevkhtei,
    required this.noat,
    required this.nhat,
    required this.shirkheg,
    required this.buunii,
    required this.onIdevkhtei,
    required this.onNoat,
    required this.onNhat,
    required this.onShirkheg,
    required this.onBuunii,
    required this.onAddBuuniiTier,
    required this.onRemoveBuuniiTier,
  });

  final AppLocalizations l10n;
  final GlobalKey<FormState> formKey;
  final TextEditingController ner;
  final TextEditingController bogino;
  final TextEditingController code;
  final TextEditingController barCode;
  final TextEditingController khemjikh;
  final TextEditingController angilal;
  final TextEditingController niitUne;
  final TextEditingController urtugUne;
  final TextEditingController uldegdel;
  final TextEditingController negKhairtsag;
  final List<_BuuniiTierCtrls> buuniiTiers;
  final bool idevkhtei;
  final bool noat;
  final bool nhat;
  final bool shirkheg;
  final bool buunii;
  final ValueChanged<bool> onIdevkhtei;
  final ValueChanged<bool> onNoat;
  final ValueChanged<bool> onNhat;
  final ValueChanged<bool> onShirkheg;
  final ValueChanged<bool> onBuunii;
  final VoidCallback onAddBuuniiTier;
  final void Function(int index) onRemoveBuuniiTier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.tr('baraa_edit'),
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: ner,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_name'),
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n.tr('baraa_name_required');
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: bogino,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_bogino'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: code,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_code'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: barCode,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_barcode'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: angilal,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_angilal'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: khemjikh,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_khemjikh'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: niitUne,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_sell_price'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: urtugUne,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_urtug'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: uldegdel,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.tr('baraa_uldegdel'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: noat,
            onChanged: onNoat,
            title: Text(l10n.tr('baraa_flag_noat')),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: idevkhtei,
            onChanged: onIdevkhtei,
            title: Text(l10n.tr('baraa_flag_idevkhtei')),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: shirkheg,
            onChanged: onShirkheg,
            title: Text(l10n.tr('baraa_flag_shirkheg')),
            contentPadding: EdgeInsets.zero,
          ),
          if (shirkheg) ...[
            const SizedBox(height: 4),
            TextFormField(
              controller: negKhairtsag,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.tr('baraa_pcs_per_box'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (!shirkheg) return null;
                final n = int.tryParse(
                  (v ?? '').replaceAll(RegExp(r'[,\s]'), ''),
                );
                if (n == null || n < 1) {
                  return l10n.tr('baraa_pcs_per_box_required');
                }
                return null;
              },
            ),
          ],
          SwitchListTile(
            value: nhat,
            onChanged: onNhat,
            title: Text(l10n.tr('baraa_flag_nhat')),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: buunii,
            onChanged: onBuunii,
            title: Text(l10n.tr('baraa_flag_buunii')),
            contentPadding: EdgeInsets.zero,
          ),
          if (buunii) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onAddBuuniiTier,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(l10n.tr('baraa_buunii_add_tier')),
              ),
            ),
            const SizedBox(height: 8),
            ...List<Widget>.generate(buuniiTiers.length, (i) {
              final c = buuniiTiers[i];
              return Padding(
                key: ObjectKey(c),
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: c.too,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.tr('baraa_buunii_qty'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: c.une,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.tr('baraa_buunii_price'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .deleteButtonTooltip,
                      onPressed: () => onRemoveBuuniiTier(i),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
