import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../models/pos_session.dart';
import '../../services/category_service.dart';
import '../../services/pos_settings_service.dart';
import '../../models/category_model.dart';

/// Web parity: `pages/khyanalt/tokhirgoo` — profile + org/branch settings.
class PosSettingsHubScreen extends StatefulWidget {
  const PosSettingsHubScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<PosSettingsHubScreen> createState() => _PosSettingsHubScreenState();
}

enum PosSettingsSection {
  personal,
  baraa,
  categories,
  notifications,
  ebarimt,
  dans,
  bonus,
  door,
  branches,
}

class _PosSettingsHubScreenState extends State<PosSettingsHubScreen> {
  PosSettingsSection _section = PosSettingsSection.personal;
  Map<String, dynamic>? _baiguullaga;
  bool _loading = true;
  String? _error;

  PosSession? get _session => context.read<AuthModel>().posSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final pos = _session;
    if (pos == null) {
      setState(() {
        _loading = false;
        _error = 'pos_settings_no_session';
        _baiguullaga = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final doc = await posSettingsService.fetchBaiguullaga(pos.baiguullagiinId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _baiguullaga = doc;
      if (doc == null) _error = 'pos_settings_load_failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthModel>();
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sections = auth.staffAccess.hasFullAccess
        ? const [PosSettingsSection.personal, PosSettingsSection.door]
        : PosSettingsSection.values;

    if (!sections.contains(_section)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _section = sections.first);
      });
    }

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('pos_settings_title')),
              actions: [
                IconButton(
                  tooltip: l10n.tr('action_refresh'),
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          : null,
      body: _session == null
          ? Center(child: Text(l10n.tr('pos_settings_no_session')))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _baiguullaga == null
                  ? Center(child: Text(l10n.tr(_error!)))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 720;
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 200,
                                child: Material(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  child: ListView(
                                    children: [
                                      for (final s in sections)
                                        _RailTile(
                                          label: posSettingsSectionLabel(l10n, s),
                                          selected: _section == s,
                                          onTap: () => setState(() => _section = s),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(child: _buildPanel(l10n, textTheme, colorScheme)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            SizedBox(
                              height: 52,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                children: [
                                  for (final s in sections)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          posSettingsSectionLabel(l10n, s),
                                          style: textTheme.labelLarge,
                                        ),
                                        selected: _section == s,
                                        onSelected: (_) => setState(() => _section = s),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(child: _buildPanel(l10n, textTheme, colorScheme)),
                          ],
                        );
                      },
                    ),
    );
  }

  Widget _buildPanel(
    AppLocalizations l10n,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final pos = _session!;
    final bg = _baiguullaga;
    switch (_section) {
      case PosSettingsSection.personal:
        return _PersonalSettingsPanel(
          l10n: l10n,
          pos: pos,
          onSaved: _reload,
        );
      case PosSettingsSection.baraa:
        return _BaraaTokhirgooPanel(
          l10n: l10n,
          baiguullaga: bg,
          salbariinId: pos.salbariinId,
          onSaved: _reload,
        );
      case PosSettingsSection.categories:
        return _CategoryPanel(
          l10n: l10n,
          baiguullagiinId: pos.baiguullagiinId,
        );
      case PosSettingsSection.notifications:
        return _PlaceholderPanel(
          title: l10n.tr('pos_settings_notify_title'),
          body: l10n.tr('pos_settings_notify_hint'),
        );
      case PosSettingsSection.ebarimt:
        return _EbarimtBranchPanel(
          l10n: l10n,
          baiguullaga: bg,
          salbariinId: pos.salbariinId,
          onSaved: _reload,
        );
      case PosSettingsSection.dans:
        return _DansListPanel(
          l10n: l10n,
          salbariinId: pos.salbariinId,
        );
      case PosSettingsSection.bonus:
        return _LoyaltyPanel(
          l10n: l10n,
          baiguullagiinId: pos.baiguullagiinId,
        );
      case PosSettingsSection.door:
        return _KhaaltPanel(
          l10n: l10n,
          baiguullaga: bg,
          baiguullagiinId: pos.baiguullagiinId,
          onSaved: _reload,
        );
      case PosSettingsSection.branches:
        return _BranchesPanel(
          l10n: l10n,
          baiguullagiinId: pos.baiguullagiinId,
        );
    }
  }

}

String posSettingsSectionLabel(AppLocalizations l10n, PosSettingsSection s) {
  switch (s) {
    case PosSettingsSection.personal:
      return l10n.tr('pos_settings_nav_personal');
    case PosSettingsSection.baraa:
      return l10n.tr('pos_settings_nav_baraa');
    case PosSettingsSection.categories:
      return l10n.tr('pos_settings_nav_categories');
    case PosSettingsSection.notifications:
      return l10n.tr('pos_settings_nav_notify');
    case PosSettingsSection.ebarimt:
      return l10n.tr('pos_settings_nav_ebarimt');
    case PosSettingsSection.dans:
      return l10n.tr('pos_settings_nav_dans');
    case PosSettingsSection.bonus:
      return l10n.tr('pos_settings_nav_bonus');
    case PosSettingsSection.door:
      return l10n.tr('pos_settings_nav_door');
    case PosSettingsSection.branches:
      return l10n.tr('pos_settings_nav_branches');
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      title: Text(label),
      onTap: onTap,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _PersonalSettingsPanel extends StatefulWidget {
  const _PersonalSettingsPanel({
    required this.l10n,
    required this.pos,
    required this.onSaved,
  });

  final AppLocalizations l10n;
  final PosSession pos;
  final Future<void> Function() onSaved;

  @override
  State<_PersonalSettingsPanel> createState() => _PersonalSettingsPanelState();
}

class _PersonalSettingsPanelState extends State<_PersonalSettingsPanel> {
  late final TextEditingController _ovog;
  late final TextEditingController _ner;
  late final TextEditingController _register;
  late final TextEditingController _utas;
  late final TextEditingController _mail;
  late final TextEditingController _khayag;
  late final TextEditingController _nuutsUg;
  late final TextEditingController _nuutsUgDavtan;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.pos.ajiltan;
    _ovog = TextEditingController(text: a['ovog']?.toString() ?? '');
    _ner = TextEditingController(text: a['ner']?.toString() ?? '');
    _register = TextEditingController(text: a['register']?.toString() ?? '');
    _utas = TextEditingController(text: a['utas']?.toString() ?? '');
    _mail = TextEditingController(text: a['mail']?.toString() ?? '');
    _khayag = TextEditingController(text: a['khayag']?.toString() ?? '');
    _nuutsUg = TextEditingController();
    _nuutsUgDavtan = TextEditingController();
  }

  @override
  void dispose() {
    _ovog.dispose();
    _ner.dispose();
    _register.dispose();
    _utas.dispose();
    _mail.dispose();
    _khayag.dispose();
    _nuutsUg.dispose();
    _nuutsUgDavtan.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _nuutsUg.text.trim();
    final pw2 = _nuutsUgDavtan.text.trim();
    if (pw.isNotEmpty && pw != pw2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.tr('pos_settings_pw_mismatch'))),
      );
      return;
    }
    final id = widget.pos.ajiltan['_id']?.toString() ?? widget.pos.ajiltan['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final body = <String, dynamic>{
      '_id': id,
      'ovog': _ovog.text.trim(),
      'ner': _ner.text.trim(),
      'register': _register.text.trim(),
      'utas': _utas.text.trim(),
      'mail': _mail.text.trim(),
      'khayag': _khayag.text.trim(),
    };
    if (pw.isNotEmpty) {
      body['nuutsUg'] = pw;
    }

    setState(() => _saving = true);
    final ok = await posSettingsService.putAjiltan(body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      final auth = context.read<AuthModel>();
      auth.mergePosSessionAjiltan({
        'ovog': body['ovog'],
        'ner': body['ner'],
        'register': body['register'],
        'utas': body['utas'],
        'mail': body['mail'],
        'khayag': body['khayag'],
      });
      _nuutsUg.clear();
      _nuutsUgDavtan.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.tr('pos_settings_saved'))),
      );
      await widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.tr('pos_settings_save_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.tr('pos_settings_personal_head'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.tr('pos_settings_photo_hint'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        TextField(controller: _ovog, decoration: InputDecoration(labelText: l10n.tr('pos_settings_ovog'))),
        TextField(controller: _ner, decoration: InputDecoration(labelText: l10n.tr('pos_settings_ner'))),
        TextField(controller: _register, decoration: InputDecoration(labelText: l10n.tr('pos_settings_register'))),
        TextField(
          controller: _utas,
          decoration: InputDecoration(labelText: l10n.tr('pos_settings_utas')),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
        ),
        TextField(controller: _mail, decoration: InputDecoration(labelText: l10n.tr('pos_settings_mail'))),
        TextField(controller: _khayag, decoration: InputDecoration(labelText: l10n.tr('pos_settings_khayag')), maxLines: 3),
        const SizedBox(height: 16),
        Text(l10n.tr('pos_settings_pw_hint'), style: Theme.of(context).textTheme.labelMedium),
        TextField(
          controller: _nuutsUg,
          decoration: InputDecoration(labelText: l10n.tr('pos_settings_pw_new')),
          obscureText: true,
        ),
        TextField(
          controller: _nuutsUgDavtan,
          decoration: InputDecoration(labelText: l10n.tr('pos_settings_pw_repeat')),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.tr('save')),
        ),
      ],
    );
  }
}

class _BaraaTokhirgooPanel extends StatefulWidget {
  const _BaraaTokhirgooPanel({
    required this.l10n,
    required this.baiguullaga,
    required this.salbariinId,
    required this.onSaved,
  });

  final AppLocalizations l10n;
  final Map<String, dynamic>? baiguullaga;
  final String salbariinId;
  final Future<void> Function() onSaved;

  @override
  State<_BaraaTokhirgooPanel> createState() => _BaraaTokhirgooPanelState();
}

class _BaraaTokhirgooPanelState extends State<_BaraaTokhirgooPanel> {
  bool? _baraaUne;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromParent();
  }

  @override
  void didUpdateWidget(covariant _BaraaTokhirgooPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baiguullaga != widget.baiguullaga) _syncFromParent();
  }

  void _syncFromParent() {
    final sal = _findSalbar(widget.baiguullaga, widget.salbariinId);
    final baraa = sal?['tokhirgoo'] is Map ? (sal!['tokhirgoo'] as Map)['baraa'] : null;
    if (baraa is Map) {
      _baraaUne = baraa['baraaHudaldahUne'] == true;
    } else {
      _baraaUne = false;
    }
  }

  Map<String, dynamic>? _findSalbar(Map<String, dynamic>? org, String salId) {
    if (org == null) return null;
    final list = org['salbaruud'];
    if (list is! List) return null;
    for (final e in list) {
      if (e is Map && e['_id']?.toString() == salId) return Map<String, dynamic>.from(e);
    }
    return null;
  }

  Future<void> _save() async {
    final org = widget.baiguullaga;
    if (org == null) return;
    final list = org['salbaruud'];
    if (list is! List) return;
    var idx = -1;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is Map && e['_id']?.toString() == widget.salbariinId) {
        idx = i;
        break;
      }
    }
    if (idx < 0) return;
    setState(() => _saving = true);
    final ok = await posSettingsService.tokhirgooSalbarOruulya(
      branchIndex: idx,
      tokhirgooPayload: {
        'baiguullagiinId': org['_id']?.toString(),
        'baraa': {'baraaHudaldahUne': _baraaUne ?? false},
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? widget.l10n.tr('pos_settings_saved') : widget.l10n.tr('pos_settings_save_failed'),
        ),
      ),
    );
    if (ok) await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (widget.baiguullaga == null) {
      return Center(child: Text(l10n.tr('pos_settings_load_failed')));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.tr('pos_settings_baraa_head'), style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(
          title: Text(l10n.tr('pos_settings_baraa_une')),
          value: _baraaUne ?? false,
          onChanged: (v) => setState(() => _baraaUne = v),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.tr('save'))),
      ],
    );
  }
}

class _CategoryPanel extends StatefulWidget {
  const _CategoryPanel({required this.l10n, required this.baiguullagiinId});

  final AppLocalizations l10n;
  final String baiguullagiinId;

  @override
  State<_CategoryPanel> createState() => _CategoryPanelState();
}

class _CategoryPanelState extends State<_CategoryPanel> {
  final _svc = CategoryService();
  final _ctrl = TextEditingController();
  List<Category> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _svc.getCategories(baiguullagiinId: widget.baiguullagiinId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _list = r.success ? r.categories : [];
    });
  }

  Future<void> _add() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final ok = await posSettingsService.angilalNemii(
      baiguullagiinId: widget.baiguullagiinId,
      angilal: name,
    );
    if (!mounted) return;
    if (ok) {
      _ctrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.tr('pos_settings_saved'))),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.tr('pos_settings_save_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.tr('pos_settings_categories_head'), style: Theme.of(context).textTheme.titleMedium),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('pos_settings_category_new'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _add, child: Text(l10n.tr('pos_settings_category_add'))),
          ],
        ),
        const SizedBox(height: 12),
        for (final c in _list)
          ListTile(
            title: Text(c.angilal),
            dense: true,
          ),
      ],
    );
  }
}

class _EbarimtBranchPanel extends StatefulWidget {
  const _EbarimtBranchPanel({
    required this.l10n,
    required this.baiguullaga,
    required this.salbariinId,
    required this.onSaved,
  });

  final AppLocalizations l10n;
  final Map<String, dynamic>? baiguullaga;
  final String salbariinId;
  final Future<void> Function() onSaved;

  @override
  State<_EbarimtBranchPanel> createState() => _EbarimtBranchPanelState();
}

class _EbarimtBranchPanelState extends State<_EbarimtBranchPanel> {
  late bool _shine;
  late bool _borluulaltNuat;
  late bool _nuatTulukh;
  late bool _autoTax;
  final _tin = TextEditingController();
  final _district = TextEditingController();
  bool _saving = false;

  Map<String, dynamic>? _salMap() {
    final org = widget.baiguullaga;
    if (org == null) return null;
    final list = org['salbaruud'];
    if (list is! List) return null;
    for (final e in list) {
      if (e is Map && e['_id']?.toString() == widget.salbariinId) {
        return Map<String, dynamic>.from(e);
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _pull();
  }

  @override
  void didUpdateWidget(covariant _EbarimtBranchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baiguullaga != widget.baiguullaga) _pull();
  }

  void _pull() {
    final sal = _salMap();
    final t = sal?['tokhirgoo'];
    final m = t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
    _shine = m['eBarimtShine'] == true;
    _borluulaltNuat = m['borluulaltNUAT'] == true;
    _nuatTulukh = m['nuatTulukhEsekh'] == true;
    _autoTax = m['eBarimtAutomataarTatvarluuIlgeekh'] == true;
    _tin.text = m['merchantTin']?.toString() ?? '';
    _district.text = m['districtCode']?.toString() ?? '';
  }

  @override
  void dispose() {
    _tin.dispose();
    _district.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final org = widget.baiguullaga;
    if (org == null) return;
    final list = org['salbaruud'];
    if (list is! List) return;
    var idx = -1;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is Map && e['_id']?.toString() == widget.salbariinId) {
        idx = i;
        break;
      }
    }
    if (idx < 0) return;
    if (_shine) {
      if (_tin.text.trim().isEmpty || _district.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.tr('pos_settings_ebarimt_required'))),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final pl = <String, dynamic>{
      'baiguullagiinId': org['_id']?.toString(),
      'eBarimtShine': _shine,
      'borluulaltNUAT': _shine ? _borluulaltNuat : false,
      'nuatTulukhEsekh': _shine ? _nuatTulukh : false,
      'eBarimtAutomataarTatvarluuIlgeekh': _shine ? _autoTax : false,
    };
    if (_shine) {
      pl['merchantTin'] = _tin.text.trim();
      pl['districtCode'] = _district.text.trim();
    }
    final ok = await posSettingsService.tokhirgooSalbarOruulya(
      branchIndex: idx,
      tokhirgooPayload: pl,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? widget.l10n.tr('pos_settings_saved') : widget.l10n.tr('pos_settings_save_failed'),
        ),
      ),
    );
    if (ok) await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (widget.baiguullaga == null) {
      return Center(child: Text(l10n.tr('pos_settings_load_failed')));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.tr('pos_settings_ebarimt_head'), style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(title: Text(l10n.tr('pos_settings_ebarimt_shine')), value: _shine, onChanged: (v) => setState(() => _shine = v)),
        SwitchListTile(
          title: Text(l10n.tr('pos_settings_ebarimt_borluulalt_nuat')),
          value: _borluulaltNuat,
          onChanged: _shine ? (v) => setState(() => _borluulaltNuat = v) : null,
        ),
        SwitchListTile(
          title: Text(l10n.tr('pos_settings_ebarimt_nuat_pay')),
          value: _nuatTulukh,
          onChanged: _shine ? (v) => setState(() => _nuatTulukh = v) : null,
        ),
        SwitchListTile(
          title: Text(l10n.tr('pos_settings_ebarimt_auto_tax')),
          value: _autoTax,
          onChanged: _shine ? (v) => setState(() => _autoTax = v) : null,
        ),
        TextField(
          controller: _tin,
          enabled: _shine,
          decoration: InputDecoration(labelText: l10n.tr('pos_settings_ebarimt_tin')),
        ),
        TextField(
          controller: _district,
          enabled: _shine,
          decoration: InputDecoration(labelText: l10n.tr('pos_settings_ebarimt_district')),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.tr('save'))),
      ],
    );
  }
}

class _DansListPanel extends StatefulWidget {
  const _DansListPanel({required this.l10n, required this.salbariinId});

  final AppLocalizations l10n;
  final String salbariinId;

  @override
  State<_DansListPanel> createState() => _DansListPanelState();
}

class _DansListPanelState extends State<_DansListPanel> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await posSettingsService.fetchDansList(widget.salbariinId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rows = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.tr('pos_settings_dans_head'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.tr('pos_settings_dans_hint'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (_rows.isEmpty)
          Text(l10n.tr('pos_settings_dans_empty'))
        else
          for (final r in _rows)
            Card(
              child: ListTile(
                title: Text(r['dansniiNer']?.toString() ?? '—'),
                subtitle: Text('${r['dugaar'] ?? ''} · ${r['valyut'] ?? ''}'),
              ),
            ),
      ],
    );
  }
}

class _LoyaltyPanel extends StatefulWidget {
  const _LoyaltyPanel({required this.l10n, required this.baiguullagiinId});

  final AppLocalizations l10n;
  final String baiguullagiinId;

  @override
  State<_LoyaltyPanel> createState() => _LoyaltyPanelState();
}

class _LoyaltyPanelState extends State<_LoyaltyPanel> {
  bool _ashiglakh = false;
  final _khuvi = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _khuvi.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final doc = await posSettingsService.loyaltyErkhAvya(widget.baiguullagiinId);
    if (!mounted) return;
    dynamic root = doc;
    if (root is Map && root['data'] != null) root = root['data'];
    Map<String, dynamic>? m;
    if (root is Map) m = Map<String, dynamic>.from(root);
    final tok = m?['tokhirgoo'];
    final loy = tok is Map ? tok['loyalty'] : null;
    if (loy is Map) {
      _ashiglakh = loy['ashiglakhEsekh'] == true;
      _khuvi.text = loy['khunglukhKhuvi']?.toString() ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_ashiglakh) {
      final pct = int.tryParse(_khuvi.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (pct <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.tr('pos_settings_bonus_percent_required'))),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final pct = int.tryParse(_khuvi.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final ok = await posSettingsService.loyaltyErkhOruulya(
      baiguullagiinId: widget.baiguullagiinId,
      ashiglakhEsekh: _ashiglakh,
      khunglukhKhuvi: pct,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? widget.l10n.tr('pos_settings_saved') : widget.l10n.tr('pos_settings_save_failed'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.tr('pos_settings_bonus_head'), style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(
          title: Text(l10n.tr('pos_settings_bonus_use')),
          value: _ashiglakh,
          onChanged: (v) => setState(() => _ashiglakh = v),
        ),
        TextField(
          controller: _khuvi,
          enabled: _ashiglakh,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.tr('pos_settings_bonus_percent')),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.tr('save'))),
      ],
    );
  }
}

class _KhaaltPanel extends StatefulWidget {
  const _KhaaltPanel({
    required this.l10n,
    required this.baiguullaga,
    required this.baiguullagiinId,
    required this.onSaved,
  });

  final AppLocalizations l10n;
  final Map<String, dynamic>? baiguullaga;
  final String baiguullagiinId;
  final Future<void> Function() onSaved;

  @override
  State<_KhaaltPanel> createState() => _KhaaltPanelState();
}

class _KhaaltPanelState extends State<_KhaaltPanel> {
  bool _khaalt = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _KhaaltPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baiguullaga != widget.baiguullaga) _sync();
  }

  void _sync() {
    final t = widget.baiguullaga?['tokhirgoo'];
    if (t is Map) {
      _khaalt = t['khaaltAshiglakhEsekh'] == true;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await posSettingsService.tokhirgooOruulya(
      baiguullagiinId: widget.baiguullagiinId,
      tokhirgooFields: {'khaaltAshiglakhEsekh': _khaalt},
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? widget.l10n.tr('pos_settings_saved') : widget.l10n.tr('pos_settings_save_failed'),
        ),
      ),
    );
    if (ok) await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (widget.baiguullaga == null) {
      return Center(child: Text(l10n.tr('pos_settings_load_failed')));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.tr('pos_settings_door_head'), style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(
          title: Text(l10n.tr('pos_settings_door_use')),
          value: _khaalt,
          onChanged: (v) => setState(() => _khaalt = v),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.tr('save'))),
      ],
    );
  }
}

class _BranchesPanel extends StatefulWidget {
  const _BranchesPanel({required this.l10n, required this.baiguullagiinId});

  final AppLocalizations l10n;
  final String baiguullagiinId;

  @override
  State<_BranchesPanel> createState() => _BranchesPanelState();
}

class _BranchesPanelState extends State<_BranchesPanel> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await posSettingsService.fetchSalbaruud(widget.baiguullagiinId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rows = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.tr('pos_settings_branches_head'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(l10n.tr('pos_settings_branches_hint'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final b in _rows)
          Card(
            child: ListTile(
              title: Text(b['ner']?.toString() ?? '—'),
              subtitle: Text(
                '${l10n.tr('pos_settings_utas')}: ${b['utas'] ?? '—'}\n'
                '${l10n.tr('pos_settings_khayag')}: ${b['khayag'] ?? '—'}',
              ),
            ),
          ),
      ],
    );
  }
}
