import 'dart:convert';

/// License module row from `erkhiinMedeelelAvya` → `moduluud` (same shape as web
/// `erkhiinTokhirgooModal` / `khereglegchiinErkhiinTokhirgoo.js`).
///
/// `odoogiin` is counted live by posBackv2 on every request. Mobile / terminal
/// modules come back with `tuhuurumj` ("mobile" | "terminal") and `idevkhtei`
/// (enabled for the organization on admin.zevtabs.mn) — they are NOT seat
/// counted, only on/off.
class StaffLicenseModule {
  StaffLicenseModule({
    required this.id,
    required this.ner,
    required this.zam,
    required this.bolomjit,
    required this.odoogiin,
    this.tuhuurumj,
    this.idevkhtei = true,
  });

  final String id;
  final String ner;
  final String zam;
  final int? bolomjit;
  final int odoogiin;
  final String? tuhuurumj;
  final bool idevkhtei;

  bool get isDevice => tuhuurumj != null;

  /// Remaining seats (may be negative when already over license, like web).
  /// `null` = not limited (device module or no `bolomjit`).
  int? get initialRemaining =>
      isDevice || bolomjit == null ? null : bolomjit! - odoogiin;

  factory StaffLicenseModule.fromJson(Map<String, dynamic> m) {
    final t = m['tuhuurumj']?.toString();
    return StaffLicenseModule(
      id: m['_id']?.toString() ?? m['id']?.toString() ?? '',
      ner: m['ner']?.toString() ?? '',
      zam: StaffLicenseGroupBuilder.normalizeZam(m['zam']?.toString() ?? ''),
      bolomjit: _toIntOrNull(m['bolomjit']),
      odoogiin: _toIntOrNull(m['odoogiin']) ?? 0,
      tuhuurumj: (t == 'mobile' || t == 'terminal') ? t : null,
      idevkhtei: m['idevkhtei'] != false,
    );
  }

  static int? _toIntOrNull(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// One toggleable window route (`tsonkhniiTokhirgoo[href]`).
class StaffWindowPermRow {
  StaffWindowPermRow({
    required this.href,
    required this.label,
    required this.initialRemaining,
    this.switchDisabled = false,
    this.tuhuurumj,
    this.idevkhtei = true,
  });

  final String href;
  final String label;

  /// Remaining seats when the editor opened (`null` = unlimited / device).
  final int? initialRemaining;
  final bool switchDisabled;
  final String? tuhuurumj;
  final bool idevkhtei;

  bool get isDevice => tuhuurumj != null;
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

  /// Same as web `tsonkhniiTokhirgooJigdlye`: keys may be stored with a full
  /// URL prefix — always compare in `/khyanalt/...` form.
  static String normalizeZam(String zam) {
    var z = zam.trim();
    final i = z.indexOf('/khyanalt/');
    if (i > 0) z = z.substring(i);
    if (z.isNotEmpty && !z.startsWith('/') && !z.startsWith('http')) {
      z = '/$z';
    }
    return z;
  }

  /// Normalizes every key of a stored `tsonkhniiTokhirgoo`, merging duplicates
  /// towards `true` (web parity).
  static Map<String, dynamic> normalizeTokhirgoo(Map raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      final key = k.toString().contains('/khyanalt/')
          ? normalizeZam(k.toString())
          : k.toString();
      final on = v == true || (v is String && v.toLowerCase() == 'true');
      if (on || out[key] == true) {
        out[key] = true;
      } else {
        out.putIfAbsent(key, () => false);
      }
    });
    return out;
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
        tuhuurumj: a.tuhuurumj,
        idevkhtei: a.idevkhtei,
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
