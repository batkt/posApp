import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/guilgee_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import 'sales_history_screen.dart';

String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

class EbarimtMenuScreen extends StatefulWidget {
  const EbarimtMenuScreen({super.key});

  @override
  State<EbarimtMenuScreen> createState() => _EbarimtMenuScreenState();
}

class _EbarimtMenuScreenState extends State<EbarimtMenuScreen> {
  Future<GuilgeeListResult>? _future;
  String? _sessionKey;
  int _refreshGen = 0;

  static String? _resolveAjiltanId(AuthModel auth) {
    final u = auth.currentUser?.id.trim();
    if (u != null && u.isNotEmpty) return u;
    final pos = auth.posSession;
    if (pos == null) return null;
    final m = pos.ajiltan;
    final fromMap = m['_id']?.toString().trim() ?? m['id']?.toString().trim();
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    return null;
  }

  Future<void> _reload(AuthModel auth) async {
    final pos = auth.posSession;
    if (pos == null) return;
    setState(() => _refreshGen++);
    await Future<void>.delayed(Duration.zero);
    if (mounted && _future != null) {
      try {
        await _future;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthModel>();
    final pos = auth.posSession;
    final aj = _resolveAjiltanId(auth);
    final key = pos == null
        ? null
        : '${pos.baiguullagiinId}|${pos.salbariinId}|$aj|$_refreshGen';

    if (key != _sessionKey) {
      _sessionKey = key;
      _future = pos == null
          ? null
          : guilgeeService.listGuilgeeniiTuukh(
              baiguullagiinId: pos.baiguullagiinId,
              salbariinId: pos.salbariinId,
              ajiltanId: aj,
            );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('ebarimt')),
        centerTitle: true,
        actions: [
          if (_future != null)
            IconButton(
              tooltip: l10n.tr('sales_history_refresh'),
              onPressed: () => _reload(auth),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: pos == null || _future == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.tr('ebarimt_no_session'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : FutureBuilder<GuilgeeListResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final result = snap.data;
                if (result == null || !result.success) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        result?.error ?? l10n.tr('ebarimt_list_error'),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }
                final withEbarimt =
                    result.sales.where((s) => s.ebarimtAvsan).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        l10n.tr('ebarimt_menu_hint'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        l10n.tr('ebarimt_recent_list_title'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: withEbarimt.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 56,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.tr('ebarimt_list_empty'),
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _reload(auth),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  24,
                                ),
                                itemCount: withEbarimt.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final sale = withEbarimt[i];
                                  return Material(
                                    color: colorScheme.surface,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => showPOSCompletedSaleSheet(
                                        context,
                                        sale,
                                        l10n,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.receipt_long_rounded,
                                              color: colorScheme.primary,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    sale.id,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${MongolianDateFormatter.formatShortDate(sale.timestamp)} · ${MongolianDateFormatter.formatTime(sale.timestamp)}',
                                                    style: textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _fmtMnt(sale.total),
                                                  style: textTheme.titleSmall
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: Text(
                                                    l10n.tr('ebarimt_badge'),
                                                    style: textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: AppColors.success,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    if (auth.staffAccess.allowsSalesHistory)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const SalesHistoryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history_rounded),
                          label: Text(l10n.tr('menu_open_sales_history')),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
