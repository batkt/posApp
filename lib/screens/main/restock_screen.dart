import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/cart_model.dart';
import '../../models/inventory_model.dart';
import '../../services/khariltsagch_service.dart';
import '../../services/orlogo_service.dart';
import '../../utils/app_snackbar.dart';

/// Нийлүүлэгчээс бараа орлогодож (худалдан авч) үлдэгдлийг нэмнэ. Вэбийн
/// «Бараа орлогодох»-той ижил `/baraaOrlogodyo`. «Дууссан бараа»-аас сонгосон
/// бараатай, эсвэл «Худалдан авалт»-аас хоосноор нээгдэж «Бараа нэмэх»-ээр
/// дурын барааг сонгоно.
class RestockScreen extends StatefulWidget {
  const RestockScreen({
    super.key,
    this.products = const [],
    this.title = 'Орлого авах',
  });

  final List<Product> products;
  final String title;

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  late final List<OrlogoMur> _muruud;
  Map<String, dynamic>? _niiluulegch;
  String _khelber = 'belen';
  bool _khadgalj = false;

  @override
  void initState() {
    super.initState();
    _muruud = widget.products.map(_murUusgekh).toList();
  }

  double get _niitDun => _muruud.fold(0, (a, m) => a + m.dun);

  OrlogoMur _murUusgekh(Product p) => OrlogoMur(
        product: p,
        too: 1,
        urtugUne: (p.urtugUne ?? p.costPrice ?? 0).toDouble(),
        zarakhUne: (p.niitUne != null && p.niitUne! > 0) ? p.niitUne! : p.price,
      );

  Future<void> _baraaNemekh() async {
    final baigaa = _muruud.map((m) => m.product.id).toSet();
    final songoson = await showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BaraaSongokhSheet(baigaa: baigaa),
    );
    if (songoson == null || songoson.isEmpty) return;
    setState(() => _muruud.addAll(songoson.map(_murUusgekh)));
  }

  String _mnt(double v) {
    final s = v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
    final parts = s.split('.');
    final buf = StringBuffer();
    final digits = parts[0];
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${buf.toString()}${parts.length > 1 ? '.${parts[1]}' : ''}₮';
  }

  Future<void> _niiluulegchSongokh() async {
    final songoson = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NiiluulegchSongokhSheet(),
    );
    if (songoson != null) setState(() => _niiluulegch = songoson);
  }

  Future<void> _khadgalakh() async {
    if (_khadgalj) return;
    if (_niiluulegch == null) {
      showAppSnackBar(context, 'Нийлүүлэгч сонгоогүй байна!',
          variant: AppSnackVariant.warning);
      return;
    }
    if (_muruud.isEmpty) {
      showAppSnackBar(context, 'Бараа сонгоогүй байна',
          variant: AppSnackVariant.warning);
      return;
    }
    for (final m in _muruud) {
      if (!(m.too > 0)) {
        showAppSnackBar(context, '${m.product.name}: тоо 0-ээс их байх ёстой',
            variant: AppSnackVariant.warning);
        return;
      }
      // Вэбтэй ижил: өртөг нь зарах үнээс их байж болохгүй
      if (m.zarakhUne > 0 && m.urtugUne > m.zarakhUne) {
        showAppSnackBar(
          context,
          '${m.product.name}: өртөг зарах үнээс их байж болохгүй',
          variant: AppSnackVariant.warning,
        );
        return;
      }
    }
    final pos = context.read<AuthModel>().posSession;
    if (pos == null) return;
    setState(() => _khadgalj = true);
    final niiluulegch = _niiluulegch!;
    final result = await OrlogoService().baraaOrlogodyo(
      baiguullagiinId: pos.baiguullagiinId,
      salbariinId: pos.salbariinId,
      ajiltan: pos.ajiltanPayload,
      khariltsagchiinId: (niiluulegch['_id'] ?? '').toString(),
      khariltsagchiinNer: _niiluulegchiinNer(niiluulegch),
      khelber: _khelber,
      muruud: _muruud,
    );
    if (!mounted) return;
    setState(() => _khadgalj = false);
    if (!result.success) {
      showAppSnackBar(context, result.error ?? 'Алдаа гарлаа',
          variant: AppSnackVariant.error);
      return;
    }
    showAppSnackBar(context, 'Орлого амжилттай бүртгэгдлээ',
        variant: AppSnackVariant.success);
    unawaited(context.read<InventoryModel>().refreshInventory(force: true));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Material(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(_niiluulegch == null
                  ? 'Нийлүүлэгч сонгох'
                  : _niiluulegchiinNer(_niiluulegch!)),
              subtitle: _niiluulegch == null
                  ? const Text('Заавал сонгоно')
                  : Text((_niiluulegch!['utas'] ?? '').toString()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _niiluulegchSongokh,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'belen',
                  label: Text('Бэлэн'),
                  icon: Icon(Icons.payments_outlined)),
              ButtonSegment(
                  value: 'zeel',
                  label: Text('Зээл'),
                  icon: Icon(Icons.schedule_outlined)),
            ],
            selected: {_khelber},
            onSelectionChanged: (s) => setState(() => _khelber = s.first),
          ),
          const SizedBox(height: 16),
          for (final m in _muruud) ...[
            _OrlogoMurCard(
              key: ObjectKey(m),
              mur: m,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _muruud.remove(m)),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: _baraaNemekh,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Бараа нэмэх'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Нийт дүн',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    Text(_mnt(_niitDun),
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _khadgalj ? null : _khadgalakh,
                icon: _khadgalj
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: const Text('Орлогодох'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _niiluulegchiinNer(Map<String, dynamic> k) {
  final ner = (k['ner'] ?? '').toString().trim();
  final ovog = (k['ovog'] ?? '').toString().trim();
  return [ovog, ner].where((e) => e.isNotEmpty).join(' ');
}

class _OrlogoMurCard extends StatelessWidget {
  const _OrlogoMurCard({
    super.key,
    required this.mur,
    required this.onChanged,
    this.onRemove,
  });

  final OrlogoMur mur;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = mur.product;
    final khairtsag = p.isBoxSaleUnit;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Код: ${p.code ?? p.sku ?? '—'}',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Хасах',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _TooField(
                      label: khairtsag ? 'Тоо (хайрцаг)' : 'Тоо',
                      initial: mur.too,
                      onChanged: (v) {
                        mur.too = v;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TooField(
                      label: 'Нэгж өртөг',
                      initial: mur.urtugUne,
                      onChanged: (v) {
                        mur.urtugUne = v;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TooField(
                      label: 'Зарах үнэ',
                      initial: mur.zarakhUne,
                      onChanged: (v) {
                        mur.zarakhUne = v;
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TooField extends StatefulWidget {
  const _TooField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final double initial;
  final ValueChanged<double> onChanged;

  @override
  State<_TooField> createState() => _TooFieldState();
}

class _TooFieldState extends State<_TooField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    _ctrl = TextEditingController(
        text: v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (t) =>
          widget.onChanged(double.tryParse(t.replaceAll(',', '.')) ?? 0),
    );
  }
}

/// Нийлүүлэгч (`khariltsagch.turul == "Нийлүүлэгч"`) хайж сонгох.
class _NiiluulegchSongokhSheet extends StatefulWidget {
  const _NiiluulegchSongokhSheet();

  @override
  State<_NiiluulegchSongokhSheet> createState() =>
      _NiiluulegchSongokhSheetState();
}

class _NiiluulegchSongokhSheetState extends State<_NiiluulegchSongokhSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _jagsaalt = const [];

  @override
  void initState() {
    super.initState();
    _achaalakh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _achaalakh() async {
    final pos = context.read<AuthModel>().posSession;
    if (pos == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await KhariltsagchService().fetchList(
      baiguullagiinId: pos.baiguullagiinId,
      salbariinId: pos.salbariinId,
      search: _search.text,
      turul: 'Нийлүүлэгч',
      branchOnly: false,
      pageSize: 50,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.success ? null : r.error;
      _jagsaalt = r.success ? r.rows : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: h * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Нийлүүлэгч хайх',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce =
                      Timer(const Duration(milliseconds: 350), _achaalakh);
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _jagsaalt.isEmpty
                          ? const Center(
                              child: Text('Нийлүүлэгч олдсонгүй'))
                          : ListView.separated(
                              itemCount: _jagsaalt.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final k = _jagsaalt[i];
                                return ListTile(
                                  title: Text(_niiluulegchiinNer(k)),
                                  subtitle: Text(
                                      (k['utas'] ?? k['register'] ?? '')
                                          .toString()),
                                  onTap: () => Navigator.pop(context, k),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Агуулахын бараанаас (олноор) сонгох. Олон баркодтой бараа орохгүй —
/// үлдэгдэл нь хүүхэд баркод дээр тул вэбээс орлогодоно.
class _BaraaSongokhSheet extends StatefulWidget {
  const _BaraaSongokhSheet({required this.baigaa});

  final Set<String> baigaa;

  @override
  State<_BaraaSongokhSheet> createState() => _BaraaSongokhSheetState();
}

class _BaraaSongokhSheetState extends State<_BaraaSongokhSheet> {
  final _search = TextEditingController();
  final Map<String, Product> _songoson = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _too(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = MediaQuery.sizeOf(context).height;
    final q = _search.text.trim().toLowerCase();
    final products = context
        .watch<InventoryModel>()
        .inventory
        .map((i) => i.product)
        .where((p) =>
            p.olonBarCodeEsekh != true &&
            p.ajilUilchilgeeEsekh != true &&
            !widget.baigaa.contains(p.id))
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            (p.code ?? '').toLowerCase().contains(q) ||
            (p.barCode ?? '').toLowerCase().contains(q))
        .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: h * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Нэр, код, баркодоор хайх',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('Бараа олдсонгүй'))
                  : ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final p = products[i];
                        return CheckboxListTile(
                          value: _songoson.containsKey(p.id),
                          onChanged: (_) => setState(() {
                            if (_songoson.remove(p.id) == null) {
                              _songoson[p.id] = p;
                            }
                          }),
                          title: Text(p.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            'Код: ${p.code ?? '—'} · Үлдэгдэл: ${_too(p.boditUldegdel)}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _songoson.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context, _songoson.values.toList()),
                    child: Text('Нэмэх (${_songoson.length})'),
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
