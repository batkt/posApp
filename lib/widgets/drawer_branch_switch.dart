import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/locale_model.dart';

/// Drawer row + bottom sheet to switch `PosSession.salbariinId` when `salbaruud` has 2+ entries.
class DrawerBranchSwitchSection extends StatelessWidget {
  const DrawerBranchSwitchSection({super.key});

  Future<void> _openSheet(BuildContext context) async {
    final auth = context.read<AuthModel>();
    final l10n = AppLocalizations.of(context);
    final opts = auth.branchSwitchOptions;
    if (opts.length < 2) return;

    var selected = auth.posSession?.salbariinId ?? opts.first.id;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        final textTheme = Theme.of(sheetCtx).textTheme;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.tr('branch_select_title'),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.tr('branch_select_hint'),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final b in opts)
                      RadioListTile<String>(
                        title: Text(
                          b.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: b.id,
                        groupValue: selected,
                        onChanged: (v) => setSt(() => selected = v ?? selected),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        sheetCtx.read<AuthModel>().applySelectedBranch(selected);
                        Navigator.pop(sheetCtx);
                      },
                      child: Text(l10n.tr('branch_continue')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Consumer<AuthModel>(
      builder: (context, auth, _) {
        if (!auth.canSwitchBranch) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context);
        final label = auth.activeSalbariinLabel;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openSheet(context),
              borderRadius: BorderRadius.circular(14),
              splashColor:
                  colorScheme.secondaryContainer.withValues(alpha: 0.35),
              highlightColor:
                  colorScheme.secondaryContainer.withValues(alpha: 0.2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.store_mall_directory_outlined,
                        color: colorScheme.onSecondaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('drawer_branch_menu'),
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
