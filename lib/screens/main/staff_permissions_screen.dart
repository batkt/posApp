import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../models/pos_session.dart';
import '../../services/staff_admin_service.dart';
import '../../staff/staff_license_group_builder.dart';
import '../../utils/app_snackbar.dart';

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

  /// Saved permissions when the editor opened (normalized) — web `ankhniiErkh`.
  late Map<String, dynamic> _ankhniiTokhirgoo;
  late List<String> _salbaruud;

  @override
  void initState() {
    super.initState();
    final raw = widget.ajiltanRow['tsonkhniiTokhirgoo'];
    // Web parity: stored keys may carry a URL prefix; normalize so switches
    // reflect real state and saves don't create duplicate keys.
    _tokhirgoo = raw is Map
        ? StaffLicenseGroupBuilder.normalizeTokhirgoo(raw)
        : <String, dynamic>{};
    _ankhniiTokhirgoo = Map<String, dynamic>.from(_tokhirgoo);
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

  /// Remaining seats with the current (unsaved) edits applied — web
  /// `getEffectiveUldegdel`. `null` = not seat counted.
  int? _effectiveRemaining(StaffWindowPermRow row) {
    final r = row.initialRemaining;
    if (row.isDevice || r == null) return null;
    final initialOn = _truthy(_ankhniiTokhirgoo[row.href]);
    final currentOn = _routeEnabled(row.href);
    if (!initialOn && currentOn) return r - 1;
    if (initialOn && !currentOn) return r + 1;
    return r;
  }

  /// Whether the switch may be turned ON — web `asaakhBolomjtoi`.
  /// Turning OFF is always allowed.
  bool _canEnable(StaffWindowPermRow row) {
    if (row.switchDisabled) return false;
    if (row.isDevice) return row.idevkhtei;
    if (row.initialRemaining == null) return true;
    if (_truthy(_ankhniiTokhirgoo[row.href])) return true;
    return row.initialRemaining! > 0;
  }

  void _setRoute(String href, bool value, StaffWindowPermRow row) {
    if (row.switchDisabled) return;
    if (value && !_canEnable(row)) {
      final l10n = AppLocalizations.of(context);
      showAppSnackBar(
        context,
        row.isDevice
            ? l10n.tr(row.tuhuurumj == 'mobile'
                ? 'staff_device_off_mobile'
                : 'staff_device_off_terminal')
            : l10n.tr('staff_admin_slots'),
      );
      return;
    }
    setState(() => _tokhirgoo[href] = value);
  }

  void _setFlag(String key, bool v) => setState(() => _tokhirgoo[key] = v);

  Widget _flagTile(String key, String titleKey, String subtitleKey) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SwitchListTile(
      title: Text(l10n.tr(titleKey)),
      subtitle: Text(
        l10n.tr(subtitleKey),
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      value: _truthy(_tokhirgoo[key]),
      onChanged: (v) => _setFlag(key, v),
    );
  }

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

  /// Илгээж байх хугацаанд товчийг идэвхгүй болгоно — олон дарахад
  /// хүсэлт давхардаж илгээгддэг байв.
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    if (!_hasAnyWindowRoute()) {
      showAppSnackBar(context, l10n.tr('staff_admin_need_route'));
      return;
    }
    final pos = context.read<AuthModel>().posSession;
    if (pos == null) return;

    setState(() => _saving = true);
    final res = await staffAdminService.saveStaffPermissions(
      ajiltaniiId: widget.ajiltanId,
      baiguullagiinId: pos.baiguullagiinId,
      tsonkhniiTokhirgoo: _tokhirgoo,
      salbaruud: _salbaruud,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      showAppSnackBar(context, l10n.tr('staff_admin_saved'));
      Navigator.pop(context);
    } else {
      showAppSnackBar(context, res.message ?? l10n.tr('staff_admin_save_failed'));
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
              onPressed: _saving ? null : _save,
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
                    // Same action permissions (and order) as web
                    // erkhiinTokhirgooModal "Үйлдэл хийх эрх".
                    Card(
                      child: Column(
                        children: [
                          _flagTile('butsaalt', 'staff_butsalt_title',
                              'staff_butsalt_subtitle'),
                          _flagTile('uniiOorchlogch', 'staff_unii_title',
                              'staff_unii_subtitle'),
                          _flagTile(
                              'nukhunOrlogo',
                              'staff_nukhun_borluulalt_title',
                              'staff_nukhun_borluulalt_subtitle'),
                          _flagTile(
                              'nukhunOrlogoAvakh',
                              'staff_nukhun_orlogo_title',
                              'staff_nukhun_orlogo_subtitle'),
                          _flagTile('udriinTailan', 'staff_udriin_tailan_title',
                              'staff_udriin_tailan_subtitle'),
                        ],
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
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
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
    final remaining = _effectiveRemaining(row);
    final String? slotText;
    Color? slotColor;
    if (row.isDevice) {
      slotText = row.idevkhtei
          ? l10n.tr('staff_device_on')
          : l10n.tr(row.tuhuurumj == 'mobile'
              ? 'staff_device_off_mobile'
              : 'staff_device_off_terminal');
      if (!row.idevkhtei) slotColor = colorScheme.error;
    } else if (remaining != null) {
      slotText = remaining < 0
          ? l10n.tr('staff_admin_slots_over').replaceAll('{n}', '$remaining')
          : l10n.tr('staff_admin_slots_left').replaceAll('{n}', '$remaining');
      if (remaining < 0) slotColor = colorScheme.error;
    } else {
      slotText = null;
    }
    // Turning OFF is always allowed; turning ON only when a seat is left
    // (or the device is enabled for the org) — same as web.
    final canToggle = !row.switchDisabled && (enabled || _canEnable(row));
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
        subtitle: slotText == null
            ? null
            : Text(
                slotText,
                style: textTheme.labelSmall?.copyWith(
                  color: slotColor ?? colorScheme.onSurfaceVariant,
                ),
              ),
        value: enabled,
        onChanged: canToggle ? (v) => _setRoute(row.href, v, row) : null,
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
