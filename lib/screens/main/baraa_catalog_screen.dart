import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/cart_model.dart';
import '../../models/inventory_model.dart';
import '../../models/locale_model.dart';
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/barcode_scan_sheet.dart';
import 'baraa_detail_screen.dart';

/// Read-only branch catalog: үнэ, үлдэгдэл, optional буцаалт/зарлага тоо (API-д байвал).
class BaraaCatalogScreen extends StatefulWidget {
  const BaraaCatalogScreen({super.key, this.showAppBar = true});

  /// False when shown inside [MainScreen] (shell already shows [menu_baraa_list]).
  final bool showAppBar;

  @override
  State<BaraaCatalogScreen> createState() => _BaraaCatalogScreenState();
}

class _BaraaCatalogScreenState extends State<BaraaCatalogScreen> {
  final ProductService _products = ProductService();
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<Product> _items = [];
  final Set<String> _seen = {};
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  static const _pageSize = 80;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) {
      setState(() => _error = 'Салбарын сесс байхгүй');
      return;
    }
    setState(() {
      _items.clear();
      _seen.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) return;

    setState(() => _loading = true);
    final res = await _products.getProducts(
      search: _search.text.trim(),
      baiguullagiinId: pos.baiguullagiinId,
      salbariinId: pos.salbariinId,
      page: _page,
      limit: _pageSize,
    );

    if (!mounted) return;
    if (res.success) {
      for (final p in res.products) {
        if (p.id.isNotEmpty && _seen.add(p.id)) {
          _items.add(p);
        }
      }
      if (res.products.length < _pageSize) {
        _hasMore = false;
      } else {
        _page++;
      }
      _error = null;
    } else {
      _error = res.error ?? 'Ачаалахад алдаа';
      _hasMore = false;
    }
    setState(() => _loading = false);
  }

  String _fmtButsaalt(Product p) {
    final v = p.butsaaltToo;
    if (v == null) return '—';
    return '$v';
  }

  Future<void> _scanBarcodeToSearch(BuildContext context) async {
    final code = await showBarcodeScanSheet(context);
    final v = code?.trim();
    if (v == null || v.isEmpty) return;
    if (!context.mounted) return;
    _search.text = v;
    setState(() {});
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('menu_baraa_list')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loading ? null : _reload,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loading ? null : _reload,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.tr('baraa_catalog_search_hint'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Баркод унших',
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: () => _scanBarcodeToSearch(context),
                    ),
                    if (_search.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                          _reload();
                        },
                      ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _reload(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ),
          Expanded(
            child: _items.isEmpty && _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(child: Text(l10n.tr('baraa_catalog_empty')))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _items.length + (_loading ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final p = _items[i];
                          final stock = p.uldegdel ?? p.stock;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: AuthenticatedImage(
                                  imageUrl: p.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if ((p.code ?? '').isNotEmpty) p.code!,
                                if (p.category.isNotEmpty) p.category,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: SizedBox(
                              width: 132,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    MntAmountFormatter.formatTugrik(p.price),
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.tr('baraa_col_stock')}: $stock',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.tr('baraa_col_return')}: ${_fmtButsaalt(p)}',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onTap: () {
                              final item = InventoryItem(
                                product: p,
                                currentStock: stock,
                                minStockLevel: 5,
                                costPrice: p.urtugUne,
                                lastRestocked: p.createdAt,
                              );
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      BaraaDetailScreen(item: item),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
