import 'package:intl/intl.dart';

import 'api_service.dart';

/// POST helpers for web-parity tailan endpoints (`hooks/tailan/*.js`, posBack routes).
class TailanService {
  TailanService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  static final _df = DateFormat('yyyy-MM-dd HH:mm:ss');

  static Map<String, dynamic> _dates(
    DateTime ekhlekh,
    DateTime duusakh,
  ) =>
      <String, dynamic>{
        'ekhlekhOgnoo': _df.format(ekhlekh),
        'duusakhOgnoo': _df.format(duusakh),
      };

  /// Web `searchGenerator`: empty query matches “all rows” like the Next.js client.
  static String formatDateTime(DateTime dt) => _df.format(dt);

  static List<Map<String, dynamic>> regexOrKeys(Iterable<String> keys) =>
      keys
          .map(
            (k) => <String, dynamic>{
              k: <String, dynamic>{
                r'$regex': '',
                r'$options': 'i',
              },
            },
          )
          .toList();

  Future<TailanPostResult> post({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _api.post<dynamic>(
        path,
        body: body,
        parser: (d) => d,
      );
      if (response.success) {
        return TailanPostResult.ok(response.data);
      }
      return TailanPostResult.fail(response.message ?? 'Алдаа');
    } catch (e) {
      return TailanPostResult.fail(e.toString());
    }
  }

  /// Тайлан — `borluulaltToimAvya` (борлуулалт vs ашиг by period).
  Future<TailanPostResult> borluulaltToim({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ekhlekh,
    required DateTime duusakh,
    String nariivchlal = 'month',
  }) {
    return post(
      path: '/borluulaltToimAvya',
      body: {
        ..._dates(ekhlekh, duusakh),
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'nariivchlal': nariivchlal,
      },
    );
  }

  Map<String, dynamic> pagedQueryBody({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ekhlekh,
    required DateTime duusakh,
    required List<String> searchKeys,
    Map<String, dynamic>? order,
    int page = 1,
    int pageSize = 100,

    /// Some Mongo pipelines use `{ \$in: salbariinId }` (e.g. [borluulaltiinTailanAvya]).
    bool salbariinIdForIn = false,
  }) =>
      <String, dynamic>{
        ..._dates(ekhlekh, duusakh),
        'baiguullagiinId': baiguullagiinId,
        'salbariinId':
            salbariinIdForIn ? <String>[salbariinId] : salbariinId,
        'khuudasniiDugaar': page,
        'khuudasniiKhemjee': pageSize,
        'order': order ?? const {'createdAt': -1},
        'query': <String, dynamic>{
          r'$or': regexOrKeys(searchKeys),
        },
      };

  Map<String, dynamic> avlagaUglugBody({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ekhlekh,
    required DateTime duusakh,
  }) =>
      <String, dynamic>{
        ..._dates(ekhlekh, duusakh),
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'order': const {'createdAt': -1},
      };

  Map<String, dynamic> uramshuulalTovchooBody({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ekhlekh,
    required DateTime duusakh,
  }) =>
      <String, dynamic>{
        ..._dates(ekhlekh, duusakh),
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'order': const {'_id.ner': 1},
      };

  Map<String, dynamic> uramshuulalDelgerenguiBody({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ekhlekh,
    required DateTime duusakh,
  }) =>
      <String, dynamic>{
        ..._dates(ekhlekh, duusakh),
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'order': const {'createdAt': -1},
      };

  Map<String, dynamic> hudaldanAvaltTailanBody({
    required String baiguullagiinId,
    required String salbariinId,
    required DateTime ekhlekh,
    required DateTime duusakh,
  }) =>
      pagedQueryBody(
        baiguullagiinId: baiguullagiinId,
        salbariinId: salbariinId,
        ekhlekh: ekhlekh,
        duusakh: duusakh,
        searchKeys: const ['khariltsagchiinNer'],
        order: const {
          '_id.khariltsagchiinId': -1,
          '_id.salbariinId': -1,
          '_id.khelber': -1,
        },
        salbariinIdForIn: true,
      );
}

class TailanPostResult {
  const TailanPostResult._({
    required this.ok,
    this.data,
    this.error,
  });

  final bool ok;
  final dynamic data;
  final String? error;

  factory TailanPostResult.ok(dynamic data) =>
      TailanPostResult._(ok: true, data: data);

  factory TailanPostResult.fail(String message) =>
      TailanPostResult._(ok: false, error: message);
}
