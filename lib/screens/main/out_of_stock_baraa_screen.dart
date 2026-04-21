import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_model.dart';
import '../../models/locale_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/authenticated_image.dart';
import 'baraa_detail_screen.dart';

/// Lists branch products with zero stock (Дууссан), newest first, with category chips.
class OutOfStockBaraaScreen extends StatefulWidget {
  const OutOfStockBaraaScreen({super.key, this.showAppBar = true});

  /// False when shown inside [MainScreen] (shell already shows [menu_out_of_stock_baraa]).
  final bool showAppBar;

  @override
  State<OutOfStockBaraaScreen> createState() => _OutOfStockBaraaScreenState();
}

class _OutOfStockBaraaScreenState extends State<OutOfStockBaraaScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _category = 'Бүгд';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('out_of_stock_baraa_title')),
              centerTitle: true,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.tr('search_inventory'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Consumer<InventoryModel>(
            builder: (context, inventory, _) {
              return SizedBox(
                height: 40,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: inventory.categories.length,
                  itemBuilder: (context, index) {
                    final cat = inventory.categories[index];
                    final selected = _category == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = cat),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Expanded(
            child: Consumer<InventoryModel>(
              builder: (context, inventory, _) {
                if (inventory.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (inventory.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        inventory.error!,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  );
                }

                final items = inventory.outOfStockItemsFiltered(
                  category: _category,
                  searchQuery: _searchController.text,
                );

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.tr('no_out_of_stock_items'),
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: inventory.refreshInventory,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final p = item.product;
                      final date = p.createdAt ?? p.updatedAt;
                      final dateStr = date != null
                          ? DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal())
                          : '—';

                      return Material(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    BaraaDetailScreen(item: item),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: AuthenticatedImage(
                                      imageUrl: p.imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${l10n.tr('category')}: ${p.angilal ?? p.category}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        '${l10n.tr('date')}: $dateStr',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    l10n.tr('out_of_stock_short'),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
