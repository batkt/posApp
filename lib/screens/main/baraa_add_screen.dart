import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/inventory_model.dart';
import '../../models/locale_model.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
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

class BaraaAddScreen extends StatefulWidget {
  const BaraaAddScreen({super.key});

  @override
  State<BaraaAddScreen> createState() => _BaraaAddScreenState();
}

class _BaraaAddScreenState extends State<BaraaAddScreen> {
  static final _productApi = ProductService();
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
    final session = context.read<AuthModel>().posSession;
    if (session == null ||
        session.baiguullagiinId == null ||
        session.salbariinId == null) {
      return;
    }
    final baigId = session.baiguullagiinId;
    final salbId = session.salbariinId;

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
      'baiguullagiinId': baigId,
      'salbariinId': salbId,
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
    final r = await _productApi.createAguulakh(fields: body);
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
    Navigator.pop(context);

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Шинэ бүтээгдэхүүн'),
        backgroundColor: colorScheme.surface,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: _saving ? null : _onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Хадгалах',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: _EditForm(
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
          onIdevkhtei: (v) => setState(() => _idevkhteiEsekh = v),
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
        ),
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
