/// Screen/feature flags derived from `ajiltan.tsonkhniiTokhirgoo` and `AdminEsekh`
/// (parity with web `khereglegchiinErkhiinTokhirgoo.js`).
///
/// Non-admin staff only get features whose web routes are explicitly set to true in
/// `tsonkhniiTokhirgoo` — no implicit “full” access when the map is missing or empty.
class StaffScreenAccess {
  const StaffScreenAccess({
    required this.hasFullAccess,
    required this.allowsKiosk,
    required this.allowsMobile,
    required this.allowsPosSystem,
    required this.allowsAnyAguulakhRoute,
    required this.allowsBaraaMatrial,
    required this.allowsBaraaOrlogokh,
    required this.allowsToollogo,
    required this.allowsBarimtiinJagsaalt,
    required this.allowsKhariltsagch,
    required this.allowsDashboard,
    required this.allowsEbarimt,
    required this.allowsHynalt,
    required this.allowsTailan,
    required this.allowsBaraaEdit,
  });

  /// Only `AdminEsekh` — used for unrestricted UI (e.g. CAdmin) and legacy “see all”.
  final bool hasFullAccess;

  final bool allowsKiosk;

  /// Web route `/khyanalt/mobile` — phone/tablet POS without kiosk drawer or split cart.
  final bool allowsMobile;
  final bool allowsPosSystem;

  /// Any granted path under `/khyanalt/aguulakh/` (role hints, future screens).
  final bool allowsAnyAguulakhRoute;

  /// `/khyanalt/aguulakh/baraaMatrial` — out-of-stock list; main product list is [InventoryScreen] (merged with Orlogokh).
  final bool allowsBaraaMatrial;

  /// `/khyanalt/aguulakh/baraaOrlogokh` — inventory / «Бараа материал».
  final bool allowsBaraaOrlogokh;

  /// `/khyanalt/aguulakh/toollogo` — тооллого.
  final bool allowsToollogo;

  /// `/khyanalt/aguulakh/barimtiinJagsaalt` — sales / receipt list.
  final bool allowsBarimtiinJagsaalt;

  /// `/khyanalt/khariltsagch` — customers.
  final bool allowsKhariltsagch;

  /// Home / summary tile: admins always; also staff who only use POS shells
  /// ([allowsPosSystem], [allowsKiosk], [allowsMobile]) so kiosk/mobile drawers
  /// are not empty (same screen header shows “POS Менежер” on [DashboardScreen]).
  final bool allowsDashboard;

  /// Web route `/khyanalt/eBarimt` and similar (per-employee `tsonkhniiTokhirgoo`).
  final bool allowsEbarimt;

  /// Web `/khyanalt/hynalt` — Хяналт dashboard (Орлого summary + top-selling table).
  final bool allowsHynalt;

  /// Web `/khyanalt/tailan/*` — Тайлан (reports).
  final bool allowsTailan;

  /// `tsonkhniiTokhirgoo['baraaZasakh']` or admin — бараа засах (app-only key, see staff editor).
  final bool allowsBaraaEdit;

  /// Same as [allowsBarimtiinJagsaalt] — barcode/receipt history screen guard.
  bool get allowsSalesHistory => allowsBarimtiinJagsaalt;

  /// Cashier vs manager heuristic ([AuthService]): any warehouse module permission.
  bool get allowsAguulakh =>
      hasFullAccess || allowsAnyAguulakhRoute;

  /// Kiosk / full POS: poll for mobile-initiated UniPOS card requests at this branch.
  bool get canPollTerminalPaySignals =>
      hasFullAccess || allowsKiosk || allowsPosSystem;

  /// Non-admins must have at least one truthy route in `tsonkhniiTokhirgoo`
  /// (missing, empty, or all-`false` counts as unconfigured for login).
  static bool isPermissionConfigurationMissing(Map<String, dynamic>? data) {
    if (data == null) return true;
    if (data['AdminEsekh'] == true || data['adminEsekh'] == true) return false;
    final raw = data['tsonkhniiTokhirgoo'];
    if (raw == null) return true;
    if (raw is! Map || raw.isEmpty) return true;
    if (!raw.values.any(_truthy)) return true;
    return false;
  }

  static StaffScreenAccess fromAjiltan(Map<String, dynamic>? data) {
    if (data == null) {
      return denied;
    }
    final admin = data['AdminEsekh'] == true || data['adminEsekh'] == true;
    final raw = data['tsonkhniiTokhirgoo'];
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = <String, dynamic>{};
      raw.forEach((k, v) {
        map![k.toString()] = v;
      });
    }

    if (!admin) {
      if (map == null || map.isEmpty) {
        return denied;
      }
      if (!map.values.any(_truthy)) {
        return denied;
      }
    }

    final full = admin;

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
    final anyAguulakh =
        full || paths.any((p) => p.contains('/aguulakh/'));
    final baraaMatrial = full || match('baraaMatrial');
    final baraaOrlogokh = full || match('baraaOrlogokh');
    final toollogo = full || match('toollogo');
    final barimtiinJagsaalt = full || match('barimtiinJagsaalt');
    final khariltsagch = full || match('khariltsagch');
    final posShellUser = pos || kiosk || mobile;
    final dashboard = full || posShellUser;
    final ebarimt = full || match('ebarimt');
    final hynalt = full ||
        match('/khyanalt/hynalt') ||
        match('khyanalt/hynalt');
    final tailan = full || match('khyanalt/tailan');
    final baraaZasakh = full ||
        (map != null && (_truthy(map['baraaZasakh']) || _truthy(map['baraa_zasakh'])));

    return StaffScreenAccess(
      hasFullAccess: full,
      allowsKiosk: kiosk,
      allowsMobile: mobile,
      allowsPosSystem: pos,
      allowsAnyAguulakhRoute: anyAguulakh,
      allowsBaraaMatrial: baraaMatrial,
      allowsBaraaOrlogokh: baraaOrlogokh,
      allowsToollogo: toollogo,
      allowsBarimtiinJagsaalt: barimtiinJagsaalt,
      allowsKhariltsagch: khariltsagch,
      allowsDashboard: dashboard,
      allowsEbarimt: ebarimt,
      allowsHynalt: hynalt,
      allowsTailan: tailan,
      allowsBaraaEdit: baraaZasakh,
    );
  }

  static const StaffScreenAccess denied = StaffScreenAccess(
    hasFullAccess: false,
    allowsKiosk: false,
    allowsMobile: false,
    allowsPosSystem: false,
    allowsAnyAguulakhRoute: false,
    allowsBaraaMatrial: false,
    allowsBaraaOrlogokh: false,
    allowsToollogo: false,
    allowsBarimtiinJagsaalt: false,
    allowsKhariltsagch: false,
    allowsDashboard: false,
    allowsEbarimt: false,
    allowsHynalt: false,
    allowsTailan: false,
    allowsBaraaEdit: false,
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
