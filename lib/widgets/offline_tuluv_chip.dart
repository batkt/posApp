import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../services/offline/offline_guilgee_queue.dart';
import '../services/offline/online_tuluv.dart';
import '../utils/mnt_amount_formatter.dart';

const _turliinNer = {
  'belen': 'Бэлэн',
  'cart': 'Карт',
  'khariltsakh': 'Дансаар',
  'zeel': 'Зээл',
  'qpay': 'QPay',
};

/// AppBar-т: офлайн эсэх, синк хийгдээгүй борлуулалтын тоо. Онлайн, дараалал
/// хоосон үед харагдахгүй. Дарахад дарааллын жагсаалт нээгдэнэ.
class OfflineTuluvChip extends StatelessWidget {
  const OfflineTuluvChip({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthModel>().posSession;
    if (session == null) return const SizedBox.shrink();
    final salbarKey = OfflineGuilgeeQueue.salbarKeyAvakh(
        session.baiguullagiinId, session.salbariinId);
    return AnimatedBuilder(
      animation: Listenable.merge(
          [OnlineTuluv.instance, OfflineGuilgeeQueue.instance]),
      builder: (context, _) {
        final online = OnlineTuluv.instance.online;
        final jagsaalt =
            OfflineGuilgeeQueue.instance.salbariinJagsaalt(salbarKey);
        if (online && jagsaalt.isEmpty) return const SizedBox.shrink();
        final aldaatai = jagsaalt.where((e) => e.tuluv == 'aldaa').length;

        Color ungu;
        IconData icon;
        String tekst;
        if (!online) {
          ungu = Colors.orange.shade700;
          icon = Icons.cloud_off_rounded;
          tekst = jagsaalt.isEmpty ? 'Офлайн' : 'Офлайн · ${jagsaalt.length}';
        } else if (aldaatai > 0) {
          ungu = Colors.red.shade600;
          icon = Icons.warning_amber_rounded;
          tekst = '$aldaatai алдаатай';
        } else {
          ungu = Colors.blue.shade600;
          icon = Icons.sync_rounded;
          tekst = 'Илгээгдээгүй ${jagsaalt.length}';
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ActionChip(
            avatar: Icon(icon, size: 16, color: ungu),
            label: Text(tekst,
                style: TextStyle(
                    color: ungu, fontWeight: FontWeight.w600, fontSize: 12)),
            side: BorderSide(color: ungu.withValues(alpha: 0.5)),
            backgroundColor: ungu.withValues(alpha: 0.08),
            onPressed: () => _sheetNeekh(context, salbarKey),
          ),
        );
      },
    );
  }

  void _sheetNeekh(BuildContext context, String salbarKey) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _OfflineDaraalalSheet(salbarKey: salbarKey),
    );
  }
}

class _OfflineDaraalalSheet extends StatelessWidget {
  const _OfflineDaraalalSheet({required this.salbarKey});

  final String salbarKey;

  Future<void> _ustgakh(BuildContext context, OfflineGuilgee e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Энэ борлуулалтыг устгах уу?'),
        content: Text(
            '${e.dugaar} — сервер рүү хэзээ ч илгээгдэхгүй, бүртгэлээс бүрмөсөн алга болно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Болих')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (ok == true) await OfflineGuilgeeQueue.instance.ustgakh(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation:
          Listenable.merge([OnlineTuluv.instance, OfflineGuilgeeQueue.instance]),
      builder: (context, _) {
        final online = OnlineTuluv.instance.online;
        final q = OfflineGuilgeeQueue.instance;
        final jagsaalt = q.salbariinJagsaalt(salbarKey);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Офлайн борлуулалт',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                online
                    ? 'Интернэт холбогдсон. Борлуулалтууд автоматаар илгээгдэнэ.'
                    : 'Интернэт тасарсан байна. Бэлэн, карт, дансаар борлуулалт хийж болно — холболт сэргэхэд автоматаар илгээгдэнэ.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (jagsaalt.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Илгээгдээгүй борлуулалт байхгүй',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: jagsaalt.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = jagsaalt[i];
                      final aldaa = e.tuluv == 'aldaa';
                      final tulbur = (e.payload['tulbur'] as List? ?? [])
                          .whereType<Map>()
                          .map((t) => _turliinNer[t['turul']] ?? t['turul'])
                          .join(', ');
                      final t = e.uusgesenOgnoo;
                      final tsag =
                          '${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: aldaa
                                  ? Colors.red.shade200
                                  : cs.outlineVariant),
                          color: aldaa
                              ? Colors.red.withValues(alpha: 0.05)
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.dugaar} · ${MntAmountFormatter.formatTugrik(e.niitUne)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('$tsag · $tulbur',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant)),
                                  if (aldaa && e.aldaa != null) ...[
                                    const SizedBox(height: 4),
                                    Text(e.aldaa!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade700)),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Устгах',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _ustgakh(context, e),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: !online || q.sinkKhiijBaina || jagsaalt.isEmpty
                    ? null
                    : () => q.sinkKhiikh(),
                icon: q.sinkKhiijBaina
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_rounded),
                label: Text(q.sinkKhiijBaina ? 'Илгээж байна...' : 'Одоо илгээх'),
              ),
            ],
          ),
        );
      },
    );
  }
}
