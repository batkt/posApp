import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';

/// Shown from [AuthWrapper] when logged in but [AuthModel.needsBranchSelection] is true.
class BranchSelectScreen extends StatefulWidget {
  const BranchSelectScreen({super.key});

  @override
  State<BranchSelectScreen> createState() => _BranchSelectScreenState();
}

class _BranchSelectScreenState extends State<BranchSelectScreen> {
  String? _selectedId;
  bool _didInitSelection = false;

  void _ensureSelection(AuthModel auth) {
    if (_didInitSelection) return;
    final opts = auth.pendingBranchOptions;
    if (opts == null || opts.isEmpty) return;
    _didInitSelection = true;
    final cur = auth.posSession?.salbariinId;
    if (cur != null && opts.any((b) => b.id == cur)) {
      _selectedId = cur;
    } else {
      _selectedId = opts.first.id;
    }
  }

  void _continue() {
    final id = _selectedId;
    if (id == null) return;
    context.read<AuthModel>().applySelectedBranch(id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Consumer2<AuthModel, LocaleModel>(
      builder: (context, auth, localeModel, _) {
        final l10n = AppLocalizations(localeModel.locale);
        final opts = auth.pendingBranchOptions;

        if (!auth.needsBranchSelection || opts == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _ensureSelection(auth);

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.tr('branch_select_title')),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () async {
                await context.read<AuthModel>().logout();
              },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 140,
                    child: Image.asset(
                      'assets/images/poslogo.png',
                      fit: BoxFit.contain,
                      cacheWidth: 480,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.store_rounded,
                          size: 72,
                          color: colorScheme.primary,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.tr('login_brand_subtitle'),
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.tr('branch_select_hint'),
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.tr('branch_field_label'),
                      filled: true,
                      border: const OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedId != null &&
                                opts.any((b) => b.id == _selectedId)
                            ? _selectedId
                            : opts.first.id,
                        items: opts
                            .map(
                              (b) => DropdownMenuItem<String>(
                                value: b.id,
                                child: Text(
                                  b.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _selectedId == null ? null : _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(l10n.tr('branch_continue')),
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
