import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/inventory_model.dart';
import '../../models/sales_model.dart';
import '../../services/guilgee_service.dart';
import '../../services/shiree_zakhialga_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/mnt_amount_formatter.dart';

/// Ширээний зураглал — вэб ПОС-ын объект/ширээний харагдацтай ижил урсгал:
///
/// * Сул ширээ дарах → одоогийн сагсыг тухайн ширээнд холбоно (хадгалахад
///   "Ширээнд хадгалах" болно).
/// * Захиалгатай ширээ дарах → захиалгыг сагсанд ачаална (бичлэг устахгүй;
///   дахин хадгалах эсвэл төлөхөд сервер хуучныг нь солино/хаана).
/// * Захиалгатай ширээг удаан дарах → өөр ширээ рүү шилжүүлэх/нэгтгэх/солих.
///
/// Буцахдаа `true` буцаавал сагс өөрчлөгдсөн гэсэн үг.
class ShireeScreen extends StatefulWidget {
  const ShireeScreen({
    super.key,
    this.embedded = false,
    this.onShireeguiKhudaldakh,
  });

  /// ПОС дэлгэц дотор (барааны оронд) үндсэн харагдац болж харагдана —
  /// "ПОС дээр харуулах" идэвхтэй объекттой салбарт. Ширээ сонгоход ПОС
  /// сагсны төлөв өөрчлөгдөж бараа руу шилжинэ (pop хийхгүй).
  final bool embedded;

  /// Embedded үед "Ширээгүй худалдах" (авч явах г.м) товч.
  final VoidCallback? onShireeguiKhudaldakh;

  static Future<bool?> open(BuildContext context) => Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => const ShireeScreen()));

  @override
  State<ShireeScreen> createState() => _ShireeScreenState();
}

class _ShireeScreenState extends State<ShireeScreen> {
  static const _zavguiUngu = Color(0xFFF59E0B);

  List<ShireeObjekt>? _objektuud;
  Map<String, Map<String, dynamic>> _zakhialguud = const {};
  String? _aldaa;
  bool _achaalj = false;
  StreamSubscription<void>? _socketSub;
  Timer? _timer;

  /// Шилжүүлэх горим: эх ширээ сонгогдсон бол дараагийн дарсан ширээ зорилт.
  ShireeMedeelel? _shiljuulekhEkh;

  @override
  void initState() {
    super.initState();
    _achaalya();
    _socketSub = SocketService.instance.shireeniiZakhialgaChanged
        .listen((_) => _achaalya(chimeegui: true));
    // Socket тасарсан үед ч 20 секунд тутам шинэчилнэ (вэбтэй ижил).
    _timer = Timer.periodic(
        const Duration(seconds: 20), (_) => _achaalya(chimeegui: true));
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
    if (!chimeegui && mounted) setState(() => _aldaa = null);
    try {
      final results = await Future.wait([
        shireeZakhialgaService.idevkhteiObjektuud(
          baiguullagiinId: session.baiguullagiinId,
          salbariinId: session.salbariinId,
        ),
        shireeZakhialgaService.shireeniiZakhialguud(
          baiguullagiinId: session.baiguullagiinId,
          salbariinId: session.salbariinId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _objektuud = results[0] as List<ShireeObjekt>;
        _zakhialguud = results[1] as Map<String, Map<String, dynamic>>;
        _aldaa = null;
      });
    } catch (e) {
      if (mounted && !chimeegui) setState(() => _aldaa = e.toString());
    } finally {
      _achaalj = false;
    }
  }

  void _sagsTseverlekh(SalesModel sales) {
    final inventory = context.read<InventoryModel>();
    for (final line in sales.currentSaleItems) {
      inventory.restock(line.product.id, line.quantity);
    }
    sales.clearSale();
  }

  Future<bool> _batalgaajuulakh(String garchig, String aguulga,
      {String tiim = 'Тийм'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(garchig),
        content: Text(aguulga),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Болих')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true), child: Text(tiim)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _shireeDarsan(ShireeMedeelel shiree) async {
    if (_shiljuulekhEkh != null) return _shiljuulekhZorilt(shiree);

    final sales = context.read<SalesModel>();
    final zakhialga = _zakhialguud[shiree.id];
    final idevkhteiShiree = sales.shiree?['shireeniiId']?.toString();

    if (zakhialga == null) {
      // Сул ширээ — одоогийн сагсыг холбоно.
      if (idevkhteiShiree != null &&
          idevkhteiShiree.isNotEmpty &&
          idevkhteiShiree != shiree.id &&
          _zakhialguud.containsKey(idevkhteiShiree)) {
        // Нээлттэй ширээний захиалгыг өөр ширээнд холбохыг хориглоно —
        // эх ширээ давхар үлдэнэ. Шилжүүлэхийг ашиглана.
        showAppSnackBar(
          context,
          'Сагсанд өөр ширээний захиалга ачаалсан байна. Шилжүүлэхийн тулд ширээг удаан дарна уу.',
          variant: AppSnackVariant.warning,
        );
        return;
      }
      sales.setShiree(shiree.toGuilgeeShiree());
      if (!mounted) return;
      showAppSnackBar(context, '${shiree.ner} сонгогдлоо',
          variant: AppSnackVariant.success);
      _khaakh(true);
      return;
    }

    // Захиалгатай ширээ — сагсанд ачаална.
    if (idevkhteiShiree == shiree.id && !sales.isSaleEmpty) {
      _khaakh(false);
      return;
    }
    if (!sales.isSaleEmpty) {
      final ok = await _batalgaajuulakh(
        'Сагс солих уу?',
        'Одоогийн сагс цэвэрлэгдэж ${shiree.ner}-ийн захиалга ачаалагдана.',
      );
      if (!ok || !mounted) return;
      _sagsTseverlekh(sales);
    }
    final lines = saleItemsFromParkedGuilgeeDoc(zakhialga);
    if (lines.isEmpty) {
      showAppSnackBar(context, 'Захиалгын бараа уншигдсангүй',
          variant: AppSnackVariant.error);
      return;
    }
    final inventory = context.read<InventoryModel>();
    for (final line in lines) {
      if (line.quantity > 0) inventory.deductStock(line.product.id, line.quantity);
    }
    final shireeUtga = zakhialga['shiree'] is Map
        ? Map<String, dynamic>.from(zakhialga['shiree'])
        : shiree.toGuilgeeShiree();
    sales.restoreParkedSale(
      lines,
      guilgeeniiDugaar: zakhialga['guilgeeniiDugaar']?.toString() ?? '',
      shiree: shireeUtga,
    );
    if (!mounted) return;
    showAppSnackBar(context, '${shiree.ner} — захиалга ачааллаа',
        variant: AppSnackVariant.success);
    _khaakh(true);
  }

  Future<void> _shireeUdaanDarsan(ShireeMedeelel shiree) async {
    if (!_zakhialguud.containsKey(shiree.id)) return;
    final sales = context.read<SalesModel>();
    if (sales.shiree?['shireeniiId']?.toString() == shiree.id &&
        !sales.isSaleEmpty) {
      showAppSnackBar(
        context,
        'Энэ ширээний захиалга сагсанд нээлттэй байна. Эхлээд хадгална уу.',
        variant: AppSnackVariant.warning,
      );
      return;
    }
    setState(() => _shiljuulekhEkh = shiree);
    showAppSnackBar(context, '${shiree.ner}-ийг шилжүүлэх ширээгээ сонгоно уу');
  }

  Future<void> _shiljuulekhZorilt(ShireeMedeelel zorilt) async {
    final ekh = _shiljuulekhEkh!;
    if (zorilt.id == ekh.id) {
      setState(() => _shiljuulekhEkh = null);
      return;
    }
    String turul = 'shiljuulekh';
    if (_zakhialguud.containsKey(zorilt.id)) {
      final songolt = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('${zorilt.ner} захиалгатай байна',
                    style: Theme.of(c).textTheme.titleMedium),
              ),
              ListTile(
                leading: const Icon(Icons.merge_type_rounded),
                title: Text('Нэгтгэх (${ekh.ner} → ${zorilt.ner})'),
                onTap: () => Navigator.pop(c, 'negtgekh'),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text('Солих (${ekh.ner} ⇄ ${zorilt.ner})'),
                onTap: () => Navigator.pop(c, 'solikh'),
              ),
            ],
          ),
        ),
      );
      if (songolt == null || !mounted) return;
      turul = songolt;
    }
    final session = context.read<AuthModel>().posSession!;
    try {
      await shireeZakhialgaService.shireeniiZakhialgaShiljuulye(
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
        turul: turul,
        ekhShireeniiId: ekh.id,
        zorilt: zorilt.toGuilgeeShiree(),
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        turul == 'negtgekh'
            ? '${ekh.ner} → ${zorilt.ner} нэгтгэлээ'
            : turul == 'solikh'
                ? '${ekh.ner} ⇄ ${zorilt.ner} солилоо'
                : '${ekh.ner} → ${zorilt.ner} шилжүүллээ',
        variant: AppSnackVariant.success,
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.toString(), variant: AppSnackVariant.error);
      }
    } finally {
      if (mounted) setState(() => _shiljuulekhEkh = null);
      _achaalya(chimeegui: true);
    }
  }

  String _khugatsaa(Map<String, dynamic> z) {
    final sh = z['shiree'] is Map ? z['shiree'] as Map : const {};
    final raw = sh['ekhelsenOgnoo'] ?? z['createdAt'];
    final t = raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'дөнгөж сая';
    if (d.inHours < 1) return '${d.inMinutes} мин';
    return '${d.inHours} ц ${d.inMinutes % 60} мин';
  }

  @override
  Widget build(BuildContext context) {
    final objektuud = _objektuud;
    final body = _aldaa != null
        ? _AldaaKharuulakh(aldaa: _aldaa!, onRetry: _achaalya)
        : objektuud == null
            ? const Center(child: CircularProgressIndicator())
            : objektuud.isEmpty
                ? const _KhoosonKharuulakh()
                : TabBarView(
                    children: [
                      for (final o in objektuud) _objektGrid(o),
                    ],
                  );

    final garchig = _shiljuulekhEkh != null
        ? '${_shiljuulekhEkh!.ner} → ширээ сонгох'
        : 'Ширээ';
    final uildluud = <Widget>[
      if (_shiljuulekhEkh != null)
        TextButton(
          onPressed: () => setState(() => _shiljuulekhEkh = null),
          child: const Text('Болих'),
        ),
      IconButton(
        tooltip: 'Шинэчлэх',
        onPressed: _achaalya,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ];
    final tabBar = (objektuud != null && objektuud.length > 1)
        ? TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final o in objektuud)
                Tab(
                  text:
                      '${o.ner} (${o.shireenuud.where((s) => _zakhialguud.containsKey(s.id)).length}/${o.shireenuud.length})',
                ),
            ],
          )
        : null;
    final tabToo =
        (objektuud == null || objektuud.isEmpty) ? 1 : objektuud.length;

    if (widget.embedded) {
      // ПОС-ын барааны хэсгийн оронд — AppBar-гүй толгой мөр.
      return DefaultTabController(
        length: tabToo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      garchig,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (widget.onShireeguiKhudaldakh != null &&
                      _shiljuulekhEkh == null)
                    OutlinedButton.icon(
                      onPressed: widget.onShireeguiKhudaldakh,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Ширээгүй худалдах'),
                    ),
                  ...uildluud,
                ],
              ),
            ),
            if (tabBar != null) tabBar,
            Expanded(
              child: RefreshIndicator(onRefresh: _achaalya, child: body),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: tabToo,
      child: Scaffold(
        appBar: AppBar(
          title: Text(garchig),
          actions: uildluud,
          bottom: tabBar,
        ),
        body: RefreshIndicator(onRefresh: _achaalya, child: body),
      ),
    );
  }

  /// Ширээ сонгосны дараа: тусдаа хуудас бол хаана; embedded бол ПОС өөрөө
  /// сагсны төлөвөөр бараа руу шилжинэ.
  void _khaakh(bool uurchlugdsun) {
    if (widget.embedded) return;
    Navigator.pop(context, uurchlugdsun);
  }

  Widget _objektGrid(ShireeObjekt o) {
    if (o.shireenuud.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        Center(child: Text('Энэ объектод ширээ бүртгээгүй байна')),
      ]);
    }
    final sales = context.watch<SalesModel>();
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: o.shireenuud.length,
      itemBuilder: (_, i) {
        final sh = o.shireenuud[i];
        final z = _zakhialguud[sh.id];
        final zavgui = z != null;
        final songogdson = sales.shiree?['shireeniiId']?.toString() == sh.id;
        final ekh = _shiljuulekhEkh?.id == sh.id;
        final ungu = zavgui ? _zavguiUngu : cs.primary;
        return Material(
          color: zavgui
              ? _zavguiUngu.withValues(alpha: 0.14)
              : cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (songogdson || ekh) ? ungu : ungu.withValues(alpha: 0.35),
              width: (songogdson || ekh) ? 2.5 : 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _shireeDarsan(sh),
            onLongPress: () => _shireeUdaanDarsan(sh),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.table_restaurant_rounded, color: ungu, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sh.ner,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (zavgui) ...[
                    Text(
                      MntAmountFormatter.formatTugrikSpaced(
                        (z['niitUne'] is num)
                            ? (z['niitUne'] as num).toDouble()
                            : double.tryParse('${z['niitUne']}') ?? 0,
                      ),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: cs.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _khugatsaa(z),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ] else
                    Text(
                      sh.suudal > 0 ? 'Сул · ${sh.suudal} суудал' : 'Сул',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AldaaKharuulakh extends StatelessWidget {
  const _AldaaKharuulakh({required this.aldaa, required this.onRetry});
  final String aldaa;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 60),
          Icon(Icons.error_outline_rounded,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(aldaa, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
                onPressed: onRetry, child: const Text('Дахин оролдох')),
          ),
        ],
      );
}

class _KhoosonKharuulakh extends StatelessWidget {
  const _KhoosonKharuulakh();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(32),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.table_restaurant_outlined, size: 56),
          SizedBox(height: 12),
          Text(
            'Идэвхтэй объект/ширээ алга.\nВэбийн Тохиргоо → Объект хэсэгт ширээ бүртгэж, "POS дээр харуулах"-ыг асаана уу.',
            textAlign: TextAlign.center,
          ),
        ],
      );
}
