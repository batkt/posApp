import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../services/shiree_zakhialga_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/mnt_amount_formatter.dart';

/// Захиалгын дараалал — вэб ПОС-ын "Захиалга" таб / KDS-тэй ижил өгөгдөл
/// (`/zakhialguudAvya`). Киоск болон "Гал тогоо руу" илгээсэн ПОС-ын
/// захиалгууд энд харагдаж, төлөв (бэлтгэж буй → бэлэн → олгосон) солино.
class ZakhialgaDaraalalScreen extends StatefulWidget {
  const ZakhialgaDaraalalScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ZakhialgaDaraalalScreen()));

  @override
  State<ZakhialgaDaraalalScreen> createState() =>
      _ZakhialgaDaraalalScreenState();
}

class _ZakhialgaDaraalalScreenState extends State<ZakhialgaDaraalalScreen> {
  ZakhialgiinDaraalal? _data;
  String? _aldaa;
  bool _achaalj = false;
  final Set<String> _ajillajBaigaa = {};
  StreamSubscription<void>? _socketSub;
  Timer? _timer;


  @override
  void initState() {
    super.initState();
    _achaalya();
    _socketSub = SocketService.instance.zakhialgaChanged
        .listen((_) => _achaalya(chimeegui: true));
    _timer = Timer.periodic(
        const Duration(seconds: 15), (_) => _achaalya(chimeegui: true));
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _achaalya({bool chimeegui = false}) async {
    final session = context.read<AuthModel>().posSession;
    if (session == null || _achaalj) return;
    _achaalj = true;
    try {
      final d = await shireeZakhialgaService.zakhialguudAvya(
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
        olgosonOruulakh: true,
      );
      if (mounted) {
        setState(() {
          _data = d;
          _aldaa = null;
        });
      }
    } catch (e) {
      if (mounted && !chimeegui) setState(() => _aldaa = e.toString());
    } finally {
      _achaalj = false;
    }
  }

  Future<void> _uildel(ZakhialgaMur z, Future<void> Function() fn,
      String amjilt) async {
    if (_ajillajBaigaa.contains(z.id)) return;
    setState(() => _ajillajBaigaa.add(z.id));
    try {
      await fn();
      if (mounted) {
        showAppSnackBar(context, amjilt, variant: AppSnackVariant.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.toString(), variant: AppSnackVariant.error);
      }
    } finally {
      if (mounted) setState(() => _ajillajBaigaa.remove(z.id));
      await _achaalya(chimeegui: true);
    }
  }

  Future<void> _ustgakh(ZakhialgaMur z) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('#${z.dugaar} захиалгыг устгах уу?'),
        content: const Text('ПОС болон KDS-ээс хоёуланаас нь алга болно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Болих')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(d).colorScheme.error),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _uildel(z, () => shireeZakhialgaService.ustgaya(z.id),
        '#${z.dugaar} устгагдлаа');
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final idevkhtei = d?.idevkhtei ?? const <ZakhialgaMur>[];
    // Дууссан = KDS-ээс бэлэн болсон + олгосон. Устгавал KDS-ээс ч алга болно.
    final duussan = [
      ...idevkhtei.where((z) => z.tuluv == 'belenBolson'),
      ...(d?.olgoson ?? const <ZakhialgaMur>[]),
    ];

    Widget jagsaalt(List<ZakhialgaMur> list, String khooson) {
      if (_aldaa != null && d == null) {
        return ListView(padding: const EdgeInsets.all(32), children: [
          const SizedBox(height: 60),
          Text(_aldaa!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
              child: FilledButton(
                  onPressed: _achaalya, child: const Text('Дахин оролдох'))),
        ]);
      }
      if (d == null) return const Center(child: CircularProgressIndicator());
      if (list.isEmpty) {
        return ListView(children: [
          const SizedBox(height: 120),
          Center(child: Text(khooson)),
        ]);
      }
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: list.length,
        itemBuilder: (_, i) => _card(list[i]),
      );
    }

    // Вэб ПОС-той ижил: зөвхөн KDS-ээс дууссан захиалга (Устгах товчтой).
    // Бэлтгэж буй захиалга зөвхөн KDS дээр харагдана.
    return Scaffold(
      appBar: AppBar(
        title: Text('Захиалга (${duussan.length})'),
        actions: [
          IconButton(
            tooltip: 'Шинэчлэх',
            onPressed: _achaalya,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _achaalya,
        child: jagsaalt(duussan,
            'Дууссан захиалга алга\n12 цагаас хуучин захиалга автоматаар устна'),
      ),
    );
  }

  Widget _card(ZakhialgaMur z) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ajillaj = _ajillajBaigaa.contains(z.id);
    final ognoo = z.ognoo;
    final minut = ognoo == null ? null : DateTime.now().difference(ognoo).inMinutes;
    // Дууссан захиалгын карт: ганц "Устгах" товч (вэбтэй ижил).
    final tovchnuud = <Widget>[
      if (z.ustgakhBolomjtoi)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: ajillaj ? null : () => _ustgakh(z),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Устгах'),
        ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${z.dugaar}',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(width: 10),
                _Shoshgo(
                  text: z.turul == 'endIdekh' ? 'Эндээ' : 'Авч явах',
                  ungu: cs.secondary,
                ),
                const Spacer(),
                if (minut != null)
                  Text(minut < 1 ? 'дөнгөж сая' : '$minut мин',
                      style: tt.bodySmall?.copyWith(
                        color: minut >= 15 ? cs.error : cs.onSurfaceVariant,
                        fontWeight: minut >= 15 ? FontWeight.w700 : null,
                      )),
              ],
            ),
            const SizedBox(height: 8),
            for (final m in z.muruud)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${m.value % 1 == 0 ? m.value.toInt() : m.value}×',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(child: Text(m.key)),
                ]),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Text(MntAmountFormatter.formatTugrikSpaced(z.niitUne),
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text(z.tulugdsun ? 'Төлсөн' : 'Төлөөгүй',
                  style: tt.bodySmall?.copyWith(
                      color: z.tulugdsun ? Colors.green : cs.error)),
            ]),
            if (tovchnuud.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: tovchnuud),
            ],
          ],
        ),
      ),
    );
  }
}

class _Shoshgo extends StatelessWidget {
  const _Shoshgo({required this.text, required this.ungu});
  final String text;
  final Color ungu;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ungu.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, color: ungu, fontWeight: FontWeight.w700)),
      );
}
