/// Screen/feature flags derived from `ajiltan.tsonkhniiTokhirgoo` and `AdminEsekh`
/// (parity with web `khereglegchiinErkhiinTokhirgoo.js`).
class StaffScreenAccess {
  const StaffScreenAccess({
    required this.hasFullAccess,
    required this.allowsKiosk,
    required this.allowsMobile,
    required this.allowsPosSystem,
    required this.allowsAguulakh,
    required this.allowsKhariltsagch,
    required this.allowsDashboard,
    required this.allowsSalesHistory,
    required this.allowsEbarimt,
  });

  /// Admin or no explicit permission map → treat as unrestricted (legacy / safe default).
  final bool hasFullAccess;

  final bool allowsKiosk;

  /// Web route `/khyanalt/mobile` — phone/tablet POS without kiosk drawer or split cart.
  final bool allowsMobile;
  final bool allowsPosSystem;
  final bool allowsAguulakh;
  final bool allowsKhariltsagch;
  final bool allowsDashboard;
  final bool allowsSalesHistory;

  /// Web route `/khyanalt/eBarimt` and similar (per-employee `tsonkhniiTokhirgoo`).
  final bool allowsEbarimt;

  /// Kiosk / full POS: poll for mobile-initiated UniPOS card requests at this branch.
  bool get canPollTerminalPaySignals =>
      hasFullAccess || allowsKiosk || allowsPosSystem;

  static StaffScreenAccess fromAjiltan(Map<String, dynamic>? data) {
    if (data == null) {
      return denied;
    }
    final admin = data['AdminEsekh'] == true;
    final raw = data['tsonkhniiTokhirgoo'];
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = <String, dynamic>{};
      raw.forEach((k, v) {
        map![k.toString()] = v;
      });
    }
    final hasExplicit = map != null && map.isNotEmpty;
    final full = admin || !hasExplicit;

    final paths = <String>{};
    map?.forEach((key, value) {
      if (_truthy(value)) {
        paths.add(_normalizePath(key));
      }
    });

    bool match(String fragment) =>
        paths.any((p) => p.contains(fragment.toLowerCase()));

    // Full URLs like `https://pos.zevtabs.mn/khyanalt/kiosk` → `/khyanalt/kiosk`
    final kiosk = full ||
        match('kiosk') ||
        match('/khyanalt/kiosk') ||
        match('khyanalt/kiosk');
    final mobile = full ||
        match('/khyanalt/mobile') ||
        match('khyanalt/mobile');
    final pos = full ||
        match('possystem') ||
        match('pos-system') ||
        match('/khyanalt/possystem') ||
        match('khyanalt/possystem');
    final aguulakh = full || match('aguulakh');
    final khariltsagch = full || match('khariltsagch');
    final dashboard = full;
    final history = full ||
        pos ||
        match('jagsaalt') ||
        match('jurnal') ||
        match('guilgee') ||
        match('borluulalt');
    final ebarimt = full || match('ebarimt');

    return StaffScreenAccess(
      hasFullAccess: full,
      allowsKiosk: kiosk,
      allowsMobile: mobile,
      allowsPosSystem: pos,
      allowsAguulakh: aguulakh,
      allowsKhariltsagch: khariltsagch,
      allowsDashboard: dashboard,
      allowsSalesHistory: history,
      allowsEbarimt: ebarimt,
    );
  }

  static const StaffScreenAccess denied = StaffScreenAccess(
    hasFullAccess: false,
    allowsKiosk: false,
    allowsMobile: false,
    allowsPosSystem: false,
    allowsAguulakh: false,
    allowsKhariltsagch: false,
    allowsDashboard: false,
    allowsSalesHistory: false,
    allowsEbarimt: false,
  );

  static bool _truthy(dynamic v) {
    if (v == true) return true;
    if (v is num && v != 0) return true;
    if (v is String && v.toLowerCase() == 'true') return true;
    return false;
  }

  /// Strip scheme/host, query, and hash; lowercase path for substring checks.
  static String _normalizePath(String key) {
    var s = key.trim();
    final schemeIdx = s.indexOf('://');
    if (schemeIdx != -1) {
      final pathStart = s.indexOf('/', schemeIdx + 3);
      s = pathStart == -1 ? '' : s.substring(pathStart);
    }
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);
    final h = s.indexOf('#');
    if (h >= 0) s = s.substring(0, h);
    if (s.length > 1 && s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s.toLowerCase();
  }
}
