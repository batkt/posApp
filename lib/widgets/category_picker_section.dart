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
  bool _expanded = false;

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
          onTap: () => setState(() => _expanded = !_expanded),
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
                Icon(
                  hasCurrent
                      ? Icons.check_circle_rounded
                      : (_expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded),
                  color: hasCurrent
                      ? const Color(0xFF4CAF50)
                      : colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          if (widget.categoryList.isNotEmpty)
            DropdownButtonFormField<Category>(
              isExpanded: true,
              initialValue: widget.categoryList.any((c) => c.angilal == current)
                  ? widget.categoryList.firstWhere((c) => c.angilal == current)
                  : widget.selectedCategory,
              decoration: InputDecoration(
                labelText: 'Ангилал сонгох',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                prefixIcon: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50),
                ),
                suffixIcon: widget.loadingCategories
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              items: widget.categoryList
                  .map(
                    (cat) => DropdownMenuItem<Category>(
                      value: cat,
                      child: Text(cat.angilal, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (cat) {
                widget.onSelectCategory(cat);
                setState(() => _expanded = false);
              },
            )
          else if (!widget.loadingCategories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Салбарт одоогоор бүртгэгдсэн ангилал байхгүй байна',
                style:
                    tt.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          if (widget.selectedCategory != null &&
              widget.selectedCategory!.subcategoryNames.isNotEmpty) ...[
            const SizedBox(height: 8),
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
      ],
    );
  }
}
