import 'package:flutter/material.dart';

import '../models/category_model.dart';

/// Category (`Ангилал`) + subcategory (`Дэд ангилал`) picker shared by
/// `BaraaAddScreen` and `BaraaDetailScreen`'s edit form — kept as one widget
/// so both stay in sync instead of drifting apart as two copies.
///
/// Collapsed by default (just a summary row); tapping it reveals the
/// dropdown + subcategory chips. There is no manual free-text category
/// input — pick from [categoryList] only.
class CategoryPickerSection extends StatefulWidget {
  const CategoryPickerSection({
    super.key,
    required this.categoryList,
    required this.loadingCategories,
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.angilal,
    required this.bogino,
    required this.onSelectCategory,
    required this.onSelectSubcategory,
  });

  final List<Category> categoryList;
  final bool loadingCategories;
  final Category? selectedCategory;
  final String? selectedSubcategory;

  /// Payload source of truth — set programmatically from [onSelectCategory],
  /// never typed into directly.
  final TextEditingController angilal;

  /// Short-name field doubled up as subcategory storage (existing pattern).
  final TextEditingController bogino;
  final ValueChanged<Category?> onSelectCategory;
  final ValueChanged<String?> onSelectSubcategory;

  @override
  State<CategoryPickerSection> createState() => _CategoryPickerSectionState();
}

class _CategoryPickerSectionState extends State<CategoryPickerSection> {
  /// Ангиллын жагсаалтыг ХАЙЛТТАЙ доод хуудсаар сонгуулна. Өмнө нь
  /// [DropdownButtonFormField] байсан тул ангилал олон үед нээгдмэгц бүтэн
  /// дэлгэцийг дүүргэдэг, хайх ч боломжгүй байв.
  Future<void> _pickCategory() async {
    if (widget.categoryList.isEmpty) return;
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoryPickSheet(
        categories: widget.categoryList,
        current: widget.angilal.text.trim(),
      ),
    );
    if (picked != null) widget.onSelectCategory(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final current = widget.angilal.text.trim();
    final hasCurrent = current.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.loadingCategories ? null : _pickCategory,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              border: Border.all(
                color: hasCurrent
                    ? const Color(0xFF4CAF50)
                    : colorScheme.outlineVariant,
                width: hasCurrent ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  hasCurrent
                      ? Icons.check_circle_rounded
                      : Icons.category_rounded,
                  color: hasCurrent
                      ? const Color(0xFF4CAF50)
                      : colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ангилал',
                        style: tt.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasCurrent ? current : 'Ангилал сонгоогүй',
                        style: tt.bodyMedium?.copyWith(
                          color: hasCurrent
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.loadingCategories)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    hasCurrent
                        ? Icons.check_circle_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: hasCurrent
                        ? const Color(0xFF4CAF50)
                        : colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
        if (widget.categoryList.isEmpty && !widget.loadingCategories)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Салбарт одоогоор бүртгэгдсэн ангилал байхгүй байна',
              style:
                  tt.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        if (widget.selectedCategory != null &&
            widget.selectedCategory!.subcategoryNames.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Дэд ангилал сонгох:',
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.selectedCategory!.subcategoryNames.map((sub) {
              final isSelected = widget.selectedSubcategory == sub ||
                  widget.bogino.text.trim() == sub;
              return FilterChip(
                selected: isSelected,
                label: Text(sub, style: const TextStyle(fontSize: 12)),
                onSelected: (selected) =>
                    widget.onSelectSubcategory(selected ? sub : null),
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.primary,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Ангиллын хайлттай сонголтын доод хуудас — дэлгэцийн 70%-иас хэтрэхгүй.
class _CategoryPickSheet extends StatefulWidget {
  const _CategoryPickSheet({required this.categories, required this.current});

  final List<Category> categories;
  final String current;

  @override
  State<_CategoryPickSheet> createState() => _CategoryPickSheetState();
}

class _CategoryPickSheetState extends State<_CategoryPickSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.categories
        : widget.categories
            .where((c) => c.angilal.toLowerCase().contains(q))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ангилал сонгох',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${list.length}',
                    style: tt.labelMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Ангилал хайх...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Олдсонгүй',
                        style: tt.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                      itemBuilder: (_, i) {
                        final cat = list[i];
                        final selected = cat.angilal == widget.current;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(
                            cat.angilal,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: cat.subcategoryNames.isEmpty
                              ? null
                              : Text(
                                  cat.subcategoryNames.join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall,
                                ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF4CAF50),
                                  size: 20,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, cat),
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
