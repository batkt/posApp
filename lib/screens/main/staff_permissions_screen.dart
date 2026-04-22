import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../models/pos_session.dart';
import '../../services/staff_admin_service.dart';
import '../../staff/staff_license_group_builder.dart';

/// Admin-only: list employees and open per-user permission editor (web
/// `hereglegchBurtgel` + `erkhiinTokhirgooModal`).
class StaffPermissionsScreen extends StatefulWidget {
  const StaffPermissionsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<StaffPermissionsScreen> createState() => _StaffPermissionsScreenState();
}

class _StaffPermissionsScreenState extends State<StaffPermissionsScreen> {
  int _page = 1;
  bool _loading = true;
  String? _error;
  StaffListPage? _pageData;

  PosSession? get _session => context.read<AuthModel>().posSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final pos = _session;
    if (pos == null) {
      setState(() {
        _loading = false;
        _error = 'staff_admin_no_session';
        _pageData = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await staffAdminService.listAjiltan(
        baiguullagiinId: pos.baiguullagiinId,
        page: _page,
        pageSize: 200,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pageData = data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'staff_admin_list_failed';
        _pageData = null;
      });
    }
  }

  String _staffName(Map<String, dynamic> row) {
    final ov = row['ovog']?.toString().trim() ?? '';
    final ner = row['ner']?.toString().trim() ?? '';
    final joined = '$ov $ner'.trim();
    if (joined.isNotEmpty) return joined;
    return row['burtgeliinDugaar']?.toString() ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('menu_staff')),
              actions: [
                IconButton(
                  tooltip: l10n.tr('action_refresh'),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : null,
      body: _session == null
          ? Center(child: Text(l10n.tr('staff_admin_no_session')))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.tr(_error!),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _page = 1);
                        await _load();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: (_pageData?.items.isEmpty ?? true)
                            ? 1
                            : (_pageData!.items.length),
                        itemBuilder: (context, i) {
                          final items = _pageData?.items ?? [];
                          if (items.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  l10n.tr('staff_admin_empty'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          final row = items[i];
                          final id = row['_id']?.toString() ?? row['id']?.toString() ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                _staffName(row),
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                row['burtgeliinDugaar']?.toString() ?? '',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: colorScheme.primary,
                              ),
                              onTap: id.isEmpty
                                  ? null
                                  : () {
                                      Navigator.push<void>(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => StaffPermissionEditorScreen(
                                            ajiltanId: id,
                                            ajiltanRow: Map<String, dynamic>.from(row),
                                          ),
                                        ),
                                      ).then((_) => _load());
                                    },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class StaffPermissionEditorScreen extends StatefulWidget {
  const StaffPermissionEditorScreen({
    super.key,
    required this.ajiltanId,
    required this.ajiltanRow,
  });

  final String ajiltanId;
  final Map<String, dynamic> ajiltanRow;

  @override
  State<StaffPermissionEditorScreen> createState() =>
      _StaffPermissionEditorScreenState();
}

class _StaffPermissionEditorScreenState extends State<StaffPermissionEditorScreen> {
  bool _loading = true;
  String? _loadError;

  List<StaffWindowPermBlock> _blocks = [];
  List<Map<String, dynamic>> _branches = [];

  late Map<String, dynamic> _tokhirgoo;
  late List<String> _salbaruud;

  @override
  void initState() {
    super.initState();
    final raw = widget.ajiltanRow['tsonkhniiTokhirgoo'];
    if (raw is Map) {
      _tokhirgoo = Map<String, dynamic>.from(raw);
    } else {
      _tokhirgoo = {};
    }
    final sal = widget.ajiltanRow['salbaruud'];
    if (sal is List) {
      _salbaruud = sal.map((e) => e.toString()).toList();
    } else {
      _salbaruud = [];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalog());
  }

  Future<void> _loadCatalog() async {
    final pos = context.read<AuthModel>().posSession;
    if (pos == null) {
      setState(() {
        _loading = false;
        _loadError = 'staff_admin_no_session';
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final modules = await staffAdminService.fetchLicenseModules(
      baiguullagiinId: pos.baiguullagiinId,
    );
    final branches = await staffAdminService.fetchBranches(
      baiguullagiinId: pos.baiguullagiinId,
    );
    if (!mounted) return;
    if (modules.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = 'staff_admin_license_missing';
        _blocks = [];
        _branches = branches;
      });
      return;
    }
    setState(() {
      _loading = false;
      _blocks = StaffLicenseGroupBuilder.buildBlocks(modules);
      _branches = branches;
    });
  }

  bool _truthy(dynamic v) {
    if (v == true) return true;
    if (v is num && v != 0) return true;
    if (v is String && v.toLowerCase() == 'true') return true;
    return false;
  }

  bool _routeEnabled(String href) => _truthy(_tokhirgoo[href]);

  void _setRoute(String href, bool value, StaffWindowPermRow row) {
    if (row.switchDisabled) return;
    if (value) {
      if (row.remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).tr('staff_admin_slots'))),
        );
        return;
      }
      row.remaining--;
      setState(() => _tokhirgoo[href] = true);
    } else {
      row.remaining++;
      setState(() => _tokhirgoo[href] = false);
    }
  }

  void _setButsaalt(bool v) => setState(() => _tokhirgoo['butsaalt'] = v);

  void _toggleSalbar(String id, bool on) {
    setState(() {
      if (on) {
        if (!_salbaruud.contains(id)) _salbaruud.add(id);
      } else {
        _salbaruud.remove(id);
      }
    });
  }

  bool _hasAnyWindowRoute() {
    for (final e in _tokhirgoo.entries) {
      if (e.key.startsWith('/') && _truthy(e.value)) return true;
    }
    return false;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_hasAnyWindowRoute()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('staff_admin_need_route'))),
      );
      return;
    }
    final pos = context.read<AuthModel>().posSession;
    if (pos == null) return;

    final res = await staffAdminService.saveStaffPermissions(
      ajiltaniiId: widget.ajiltanId,
      baiguullagiinId: pos.baiguullagiinId,
      tsonkhniiTokhirgoo: _tokhirgoo,
      salbaruud: _salbaruud,
    );
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('staff_admin_saved'))),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? l10n.tr('staff_admin_save_failed'))),
      );
    }
  }

  String _titleName() {
    final ov = widget.ajiltanRow['ovog']?.toString().trim() ?? '';
    final ner = widget.ajiltanRow['ner']?.toString().trim() ?? '';
    final joined = '$ov $ner'.trim();
    return joined.isNotEmpty ? joined : (widget.ajiltanRow['burtgeliinDugaar']?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('staff_editor_title')),
        actions: [
          if (!_loading && _loadError == null)
            TextButton(
              onPressed: _save,
              child: Text(l10n.tr('save')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text(l10n.tr(_loadError!)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _titleName(),
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(text: l10n.tr('staff_section_branch')),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            for (final b in _branches)
                              SwitchListTile(
                                title: Text(
                                  b['ner']?.toString() ?? '—',
                                  style: textTheme.bodyLarge,
                                ),
                                value: _salbaruud.contains(b['_id']?.toString()),
                                onChanged: (v) => _toggleSalbar(b['_id']?.toString() ?? '', v),
                              ),
                            if (_branches.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  l10n.tr('staff_admin_no_branches'),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle(text: l10n.tr('staff_section_action')),
                    Card(
                      child: SwitchListTile(
                        title: Text(l10n.tr('staff_butsalt_title')),
                        subtitle: Text(
                          l10n.tr('staff_butsalt_subtitle'),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        value: _truthy(_tokhirgoo['butsaalt']),
                        onChanged: _setButsaalt,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle(text: l10n.tr('staff_section_window')),
                    const SizedBox(height: 8),
                    for (final block in _blocks) ...[
                      if (block.isLeaf && block.leaf != null)
                        _windowRowTile(context, block.leaf!, block.leaf!.label)
                      else
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            title: Text(
                              block.title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            children: [
                              for (final row in block.children)
                                _windowRowTile(context, row, row.label, nested: true),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(l10n.tr('save')),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _windowRowTile(
    BuildContext context,
    StaffWindowPermRow row,
    String title, {
    bool nested = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = _routeEnabled(row.href);
    final slotText =
        l10n.tr('staff_admin_slots_left').replaceAll('{n}', '${row.remaining}');
    return Card(
      margin: EdgeInsets.only(bottom: nested ? 4 : 10),
      color: nested
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: SwitchListTile(
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          slotText,
          style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        value: enabled,
        onChanged: row.switchDisabled
            ? null
            : (v) => _setRoute(row.href, v, row),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: textTheme.titleMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
