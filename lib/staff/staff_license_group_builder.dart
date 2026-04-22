import 'dart:convert';

/// License module row from `erkhiinMedeelelAvya` → `moduluud` (same shape as web
/// `erkhiinTokhirgooModal` / `khereglegchiinErkhiinTokhirgoo.js`).
class StaffLicenseModule {
  StaffLicenseModule({
    required this.id,
    required this.ner,
    required this.zam,
    required this.bolomjit,
    required this.odoogiin,
  });

  final String id;
  final String ner;
  final String zam;
  final int bolomjit;
  final int odoogiin;

  int get initialRemaining => (bolomjit - odoogiin).clamp(0, 1 << 30);

  factory StaffLicenseModule.fromJson(Map<String, dynamic> m) {
    return StaffLicenseModule(
      id: m['_id']?.toString() ?? m['id']?.toString() ?? '',
      ner: m['ner']?.toString() ?? '',
      zam: m['zam']?.toString() ?? '',
      bolomjit: _toInt(m['bolomjit']),
      odoogiin: _toInt(m['odoogiin']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

/// One toggleable window route (`tsonkhniiTokhirgoo[href]`).
class StaffWindowPermRow {
  StaffWindowPermRow({
    required this.href,
    required this.label,
    required this.initialRemaining,
    this.switchDisabled = false,
  }) : remaining = initialRemaining;

  final String href;
  final String label;
  final int initialRemaining;
  final bool switchDisabled;

  /// Remaining license seats while editing (mirrors web `uldegdel` mutation).
  int remaining;
}

/// Top-level POS route (`/khyanalt/…` with 3 segments) vs folder with children.
class StaffWindowPermBlock {
  StaffWindowPermBlock.leaf(StaffWindowPermRow row)
      : leaf = row,
        children = const [],
        title = _titleForLeafHref(row.href);

  StaffWindowPermBlock.folder({
    required this.title,
    required this.children,
  }) : leaf = null;

  static String _titleForLeafHref(String href) {
    final parts = href.split('/');
    if (parts.length > 2) {
      return StaffLicenseGroupBuilder.titleForSegment(parts[2]);
    }
    return href;
  }

  final String title;
  final StaffWindowPermRow? leaf;
  final List<StaffWindowPermRow> children;

  bool get isLeaf => leaf != null;
}

/// Builds UI blocks from `moduluud` — parity with `khereglegchiinErkhiinTokhirgoo.js`
/// `ekhniiTsonkhruuOchyo` grouping (admin editor: include every module).
class StaffLicenseGroupBuilder {
  StaffLicenseGroupBuilder._();

  /// `khuudasniiNer` → Mongolian group title (extends web `khuudasnuud`).
  static const Map<String, String> _groupTitles = {
    'possystem': 'POS',
    'aguulakh': 'Агуулах',
    'ebarimt': 'И-Баримт',
    'tootsoo': 'Тооцоо',
    'tailan': 'Тайлан',
    'hynalt': 'Хяналт',
    'khariltsagch': 'Харилцагч',
    'hereglegchburtgel': 'Хэрэглэгч',
    'mobile': 'Mobile',
    'kiosk': 'Kiosk',
    'khyanalt': 'Хяналт',
  };

  static String _normKey(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String titleForSegment(String groupSegment) {
    final k = _normKey(groupSegment);
    return _groupTitles[k] ?? groupSegment;
  }

  /// Paths where the web disables the switch (user registry).
  static bool isHrefSwitchDisabled(String href) {
    final h = href.toLowerCase();
    return h.contains('/hereglegchiinburtgel') ||
        h == '/khyanalt/hereglegchburtgel'.toLowerCase();
  }

  static List<StaffLicenseModule> parseModules(dynamic raw) {
    if (raw is! List) return [];
    final out = <StaffLicenseModule>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final mod = StaffLicenseModule.fromJson(m);
      if (mod.zam.isEmpty) continue;
      // Web parity: general journal (`yrunhiiJurnal`) is not offered in staff window perms.
      if (mod.zam.toLowerCase().contains('yrunhiijurnal')) continue;
      out.add(mod);
    }
    return out;
  }

  /// Returns ordered blocks for the “Цонхны эрх” list.
  static List<StaffWindowPermBlock> buildBlocks(List<StaffLicenseModule> modules) {
    final blocks = <StaffWindowPermBlock>[];
    final folderChildren = <String, List<StaffWindowPermRow>>{};
    final folderOrder = <String>[];

    for (final a in modules) {
      final charValue = a.zam.split('/');
      if (charValue.length < 3) continue;
      final group = charValue[2];
      final isLeaf = charValue.length == 3;
      final row = StaffWindowPermRow(
        href: a.zam,
        label: a.ner,
        initialRemaining: a.initialRemaining,
        switchDisabled: isHrefSwitchDisabled(a.zam),
      );

      if (isLeaf) {
        blocks.add(StaffWindowPermBlock.leaf(row));
        continue;
      }

      if (!folderChildren.containsKey(group)) {
        folderChildren[group] = [];
        folderOrder.add(group);
      }
      folderChildren[group]!.add(row);
    }

    for (final g in folderOrder) {
      final title = titleForSegment(g);
      blocks.add(
        StaffWindowPermBlock.folder(
          title: title,
          children: folderChildren[g] ?? [],
        ),
      );
    }

    return blocks;
  }

  static String encodeQueryMap(Map<String, dynamic> query) => jsonEncode(query);
}
