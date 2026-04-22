import 'api_service.dart';
import '../staff/staff_license_group_builder.dart';

/// Admin-only APIs mirroring web `erkhiinTokhirgooModal` / `baiguullagaRoute.js`.
class StaffAdminService {
  StaffAdminService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  /// POST `/erkhiinMedeelelAvya` — returns body that includes `moduluud`.
  Future<Map<String, dynamic>?> fetchLicenseInfo({
    required String baiguullagiinId,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/erkhiinMedeelelAvya',
        body: {'baiguullagiinId': baiguullagiinId},
        parser: (data) => data,
      );
      if (!response.success || response.data == null) return null;
      final d = response.data;
      if (d is Map<String, dynamic>) return d;
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return null;
  }

  Future<List<StaffLicenseModule>> fetchLicenseModules({
    required String baiguullagiinId,
  }) async {
    final body = await fetchLicenseInfo(baiguullagiinId: baiguullagiinId);
    if (body == null) return [];
    return StaffLicenseGroupBuilder.parseModules(body['moduluud']);
  }

  /// GET `/baiguullaga/:id` — branches for “Хэрэглэгчийн салбарын эрх”.
  Future<List<Map<String, dynamic>>> fetchBranches({
    required String baiguullagiinId,
  }) async {
    final oid = baiguullagiinId.trim();
    if (oid.isEmpty) return [];
    try {
      final response = await _api.get<dynamic>(
        '/baiguullaga/$oid',
        parser: (data) => data,
      );
      if (!response.success || response.data == null) return [];
      dynamic doc = response.data;
      if (doc is Map && doc['data'] is Map) {
        doc = doc['data'];
      }
      if (doc is! Map) return [];
      final m = Map<String, dynamic>.from(doc);
      final sal = m['salbaruud'];
      if (sal is! List) return [];
      return sal
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Paginated employee list (zevback-style query string).
  Future<StaffListPage> listAjiltan({
    required String baiguullagiinId,
    int page = 1,
    int pageSize = 100,
  }) async {
    final oid = baiguullagiinId.trim();
    if (oid.isEmpty) {
      return const StaffListPage(
        items: [],
        currentPage: 1,
        totalPages: 1,
        totalRows: 0,
      );
    }
    final queryStr = StaffLicenseGroupBuilder.encodeQueryMap({
      'baiguullagiinId': oid,
    });
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/ajiltan',
        queryParams: {
          'query': queryStr,
          'order': '{"createdAt":-1}',
          'khuudasniiDugaar': '$page',
          'khuudasniiKhemjee': '$pageSize',
          'baiguullagiinId': oid,
        },
        parser: (data) => data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map),
      );
      if (!response.success || response.data == null) {
        return const StaffListPage(
          items: [],
          currentPage: 1,
          totalPages: 1,
          totalRows: 0,
        );
      }
      final d = response.data!;
      final rawList = d['jagsaalt'];
      final items = <Map<String, dynamic>>[];
      if (rawList is List) {
        for (final e in rawList) {
          if (e is Map) {
            items.add(Map<String, dynamic>.from(e));
          }
        }
      }
      final totalRows = _readInt(d['niitMur'], items.length);
      final totalPages = _readInt(d['niitKhuudas'], 1).clamp(1, 99999);
      final currentPage = _readInt(d['khuudasniiDugaar'], page);
      return StaffListPage(
        items: items,
        currentPage: currentPage,
        totalPages: totalPages,
        totalRows: totalRows,
      );
    } catch (_) {
      return const StaffListPage(
        items: [],
        currentPage: 1,
        totalPages: 1,
        totalRows: 0,
      );
    }
  }

  static int _readInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// POST `/ajiltandErkhUgyu` — same body as web `erkhiinTokhirgooModal.khadgalya`.
  Future<StaffSaveResult> saveStaffPermissions({
    required String ajiltaniiId,
    required String baiguullagiinId,
    required Map<String, dynamic> tsonkhniiTokhirgoo,
    required List<String> salbaruud,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        '/ajiltandErkhUgyu',
        body: {
          'ajiltaniiId': ajiltaniiId,
          'baiguullagiinId': baiguullagiinId,
          'tsonkhniiTokhirgoo': tsonkhniiTokhirgoo,
          'salbaruud': salbaruud,
        },
        parser: (data) => data,
      );
      final ok = response.success &&
          (response.data == 'Amjilttai' ||
              response.data?.toString() == 'Amjilttai');
      return StaffSaveResult(
        success: ok,
        message: ok ? null : (response.message ?? 'Алдаа'),
      );
    } catch (e) {
      return StaffSaveResult(success: false, message: e.toString());
    }
  }
}

final staffAdminService = StaffAdminService();

class StaffListPage {
  const StaffListPage({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalRows,
  });

  final List<Map<String, dynamic>> items;
  final int currentPage;
  final int totalPages;
  final int totalRows;
}

class StaffSaveResult {
  const StaffSaveResult({required this.success, this.message});

  final bool success;
  final String? message;
}
