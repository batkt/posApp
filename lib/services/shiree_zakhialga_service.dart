import 'dart:convert';

import 'api_service.dart';

/// Ширээ (Объект) ба захиалгын дараалал — вэб `posSystem/index.js`
/// (ширээний зураглал) болон `ZakhialgiinDaraalal` / KDS-тэй ижил endpoint-ууд.
///
/// * `GET /Objekt` — идэвхтэй объект, доторх `shireenuud`
/// * `GET /guilgeeniiTuukh` — ширээний нээлттэй захиалга (`tuluv: 0`, `shiree`)
/// * `POST /zakhialguudAvya` — киоск/KDS захиалгын дараалал
/// * `POST /zakhialgiinTuluvSolyo`, `/zakhialgaTsutslaya`, `/kioskZakhialgaBurtgey`
/// * `POST /shireeniiZakhialgaShiljuulye` — ширээ шилжүүлэх/нэгтгэх
class ShireeZakhialgaService {
  ShireeZakhialgaService({ApiService? api}) : _api = api ?? posApiService;

  final ApiService _api;

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _jagsaalt(dynamic data) {
    final raw = data is List
        ? data
        : (data is Map ? (data['jagsaalt'] ?? data['data']) : null);
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String _aldaa(ApiResponse r, String fallback) {
    final m = r.message?.trim();
    return (m == null || m.isEmpty) ? fallback : m;
  }

  /// POS дээр зураглал болгох идэвхтэй объектууд (`idevkhteiEsekh: true`),
  /// `daraalal`-аар эрэмбэлсэн. Өөр салбарт хамаарах объектыг хасна.
  Future<List<ShireeObjekt>> idevkhteiObjektuud({
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    final r = await _api.get<dynamic>(
      '/Objekt',
      queryParams: {
        'query': jsonEncode({
          'baiguullagiinId': baiguullagiinId,
          'idevkhteiEsekh': true,
        }),
        'order': jsonEncode({'daraalal': 1, 'createdAt': 1}),
        'khuudasniiDugaar': '1',
        'khuudasniiKhemjee': '200',
        'baiguullagiinId': baiguullagiinId,
      },
      parser: (d) => d,
    );
    if (!r.success) {
      throw ShireeZakhialgaException(_aldaa(r, 'Ширээний мэдээлэл авахад алдаа'));
    }
    return _jagsaalt(r.data)
        .where((o) {
          final sid = o['salbariinId']?.toString() ?? '';
          return sid.isEmpty || sid == salbariinId;
        })
        .map(ShireeObjekt.fromJson)
        .toList();
  }

  /// Ширээнүүдийн нээлттэй (төлөгдөөгүй) захиалгууд — `shireeniiId` → doc.
  Future<Map<String, Map<String, dynamic>>> shireeniiZakhialguud({
    required String baiguullagiinId,
    required String salbariinId,
  }) async {
    final r = await _api.get<dynamic>(
      '/guilgeeniiTuukh',
      queryParams: {
        'query': jsonEncode({
          'baiguullagiinId': baiguullagiinId,
          'salbariinId': salbariinId,
          'tuluv': 0,
          'shiree.shireeniiId': {r'$exists': true},
        }),
        'khuudasniiDugaar': '1',
        'khuudasniiKhemjee': '500',
        'baiguullagiinId': baiguullagiinId,
      },
      parser: (d) => d,
    );
    if (!r.success) {
      throw ShireeZakhialgaException(_aldaa(r, 'Ширээний захиалга авахад алдаа'));
    }
    final out = <String, Map<String, dynamic>>{};
    for (final z in _jagsaalt(r.data)) {
      final id = _map(z['shiree'])['shireeniiId']?.toString() ?? '';
      if (id.isNotEmpty) out[id] = z;
    }
    return out;
  }

  /// Ширээ шилжүүлэх (`"shiljuulekh"`), солих (`"solikh"`), нэгтгэх (`"negtgekh"`).
  Future<void> shireeniiZakhialgaShiljuulye({
    required String baiguullagiinId,
    required String salbariinId,
    required String turul,
    required String ekhShireeniiId,
    required Map<String, dynamic> zorilt,
  }) async {
    final r = await _api.post<dynamic>(
      '/shireeniiZakhialgaShiljuulye',
      body: {
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'turul': turul,
        'ekhShireeniiId': ekhShireeniiId,
        'zorilt': zorilt,
      },
      parser: (d) => d,
    );
    if (!r.success) {
      throw ShireeZakhialgaException(_aldaa(r, 'Ширээ шилжүүлэхэд алдаа'));
    }
  }

  /// Захиалгын дараалал: идэвхтэй + (сонгосон бол) сүүлд олгосон 20.
  Future<ZakhialgiinDaraalal> zakhialguudAvya({
    required String baiguullagiinId,
    required String salbariinId,
    bool olgosonOruulakh = false,
  }) async {
    final r = await _api.post<dynamic>(
      '/zakhialguudAvya',
      body: {
        'baiguullagiinId': baiguullagiinId,
        'salbariinId': salbariinId,
        'olgosonOruulakh': olgosonOruulakh,
      },
      parser: (d) => d,
    );
    if (!r.success) {
      throw ShireeZakhialgaException(_aldaa(r, 'Захиалга авахад алдаа'));
    }
    final d = _map(r.data);
    return ZakhialgiinDaraalal(
      idevkhtei: _jagsaalt(d['idevkhtei']).map(ZakhialgaMur.new).toList(),
      olgoson: _jagsaalt(d['olgoson']).map(ZakhialgaMur.new).toList(),
    );
  }

  /// `shine` → `beltgejBui` → `belenBolson` → `olgosan` (олгохын өмнө төлөгдсөн байх).
  Future<void> tuluvSolyo(String id, String tuluv) async {
    final r = await _api.post<dynamic>(
      '/zakhialgiinTuluvSolyo',
      body: {'id': id, 'tuluv': tuluv},
      parser: (d) => d,
    );
    if (!r.success) {
      throw ShireeZakhialgaException(_aldaa(r, 'Төлөв солиход алдаа'));
    }
  }

  Future<void> tsutslaya(String id, {String? shaltgaan}) async {
    final r = await _api.post<dynamic>(
      '/zakhialgaTsutslaya',
      body: {
        'id': id,
        if (shaltgaan != null && shaltgaan.trim().isNotEmpty)
          'shaltgaan': shaltgaan.trim(),
      },
      parser: (d) => d,
    );
    if (!r.success) {
      throw ShireeZakhialgaException(_aldaa(r, 'Захиалга цуцлахад алдаа'));
    }
  }

  /// Дууссан захиалгыг ПОС болон KDS-ээс устгах (нуух) — `/zakhialgaUstgaya`.
  /// Борлуулалтын бичлэг хэвээр; 12 цагаас хуучин нь автоматаар алга болно.
  Future<void> ustgaya(String id) async {
    final r = await _api.post<dynamic>(
      '/zakhialgaUstgaya',
      body: {'id': id},
      parser: (d) => d,
    );
    if (!r.success) {
      throw ShireeZakhialgaException(_aldaa(r, 'Захиалга устгахад алдаа'));
    }
  }

  /// Киоск дээр QPay-ээр төлөгдсөн боловч бүртгэгдээгүй захиалгыг бүртгэнэ.
  Future<void> kioskZakhialgaBurtgey(String id) async {
    final r = await _api.post<dynamic>(
      '/kioskZakhialgaBurtgey',
      body: {'id': id},
      parser: (d) => d,
    );
    if (!r.success) {
      throw ShireeZakhialgaException(_aldaa(r, 'Захиалга бүртгэхэд алдаа'));
    }
  }
}

final shireeZakhialgaService = ShireeZakhialgaService();

class ShireeZakhialgaException implements Exception {
  ShireeZakhialgaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShireeObjekt {
  ShireeObjekt({
    required this.id,
    required this.ner,
    required this.shireenuud,
  });

  final String id;
  final String ner;
  final List<ShireeMedeelel> shireenuud;

  factory ShireeObjekt.fromJson(Map<String, dynamic> j) {
    final id = j['_id']?.toString() ?? '';
    final ner = j['ner']?.toString() ?? '';
    final raw = j['shireenuud'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((s) => ShireeMedeelel.fromJson(
                  Map<String, dynamic>.from(s),
                  objektiinId: id,
                  objektiinNer: ner,
                ))
            .where((s) => s.id.isNotEmpty)
            .toList()
        : <ShireeMedeelel>[];
    // Торон дээрх байрлалаар (мөр, багана) эрэмбэлнэ — зураглалын дарааллаар.
    list.sort((a, b) {
      final m = a.mur.compareTo(b.mur);
      return m != 0 ? m : a.bagana.compareTo(b.bagana);
    });
    return ShireeObjekt(id: id, ner: ner, shireenuud: list);
  }
}

class ShireeMedeelel {
  ShireeMedeelel({
    required this.id,
    required this.ner,
    required this.objektiinId,
    required this.objektiinNer,
    this.mur = 0,
    this.bagana = 0,
    this.suudal = 0,
  });

  final String id;
  final String ner;
  final String objektiinId;
  final String objektiinNer;
  final int mur;
  final int bagana;
  final int suudal;

  factory ShireeMedeelel.fromJson(
    Map<String, dynamic> j, {
    required String objektiinId,
    required String objektiinNer,
  }) {
    int n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return ShireeMedeelel(
      id: j['_id']?.toString() ?? '',
      ner: j['ner']?.toString() ?? '',
      objektiinId: objektiinId,
      objektiinNer: objektiinNer,
      mur: n(j['mur']),
      bagana: n(j['bagana']),
      suudal: n(j['suudal']),
    );
  }

  /// Гүйлгээнд хадгалагдах `shiree` объект (вэбтэй ижил талбарууд).
  Map<String, dynamic> toGuilgeeShiree() => {
        'objektiinId': objektiinId,
        'objektiinNer': objektiinNer,
        'shireeniiId': id,
        'shireeniiNer': ner,
      };
}

class ZakhialgiinDaraalal {
  ZakhialgiinDaraalal({required this.idevkhtei, required this.olgoson});
  final List<ZakhialgaMur> idevkhtei;
  final List<ZakhialgaMur> olgoson;
}

class ZakhialgaMur {
  ZakhialgaMur(this.doc);

  final Map<String, dynamic> doc;

  Map<String, dynamic> get _z =>
      doc['zakhialga'] is Map ? Map<String, dynamic>.from(doc['zakhialga']) : const {};

  String get id => doc['_id']?.toString() ?? '';
  String get dugaar => _z['dugaar']?.toString() ?? '';
  String get turul => _z['turul']?.toString() ?? '';
  String get tuluv => (_z['tuluv']?.toString() ?? '').isEmpty ? 'shine' : _z['tuluv'].toString();
  bool get tulugdsun => doc['tuluv'] == 1;
  bool get shireeTei {
    final sh = doc['shiree'];
    return sh is Map && (sh['shireeniiId']?.toString() ?? '').isNotEmpty;
  }

  bool get duussan => tuluv == 'belenBolson' || tuluv == 'olgosan';

  /// Backend `/zakhialgaUstgaya`-ийн нөхцөлтэй ижил (дууссан бүхнийг).
  bool get ustgakhBolomjtoi => duussan;
  bool get qpayTulsunBurtgeegui => !tulugdsun && _z['qpayTulsun'] == true;
  String get guilgeeniiDugaar => doc['guilgeeniiDugaar']?.toString() ?? '';
  double get niitUne {
    final v = doc['niitUne'];
    return v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  }

  DateTime? get ognoo {
    final raw = _z['ognoo'] ?? doc['createdAt'];
    return raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
  }

  /// `[(нэр, тоо)]` — картад харуулах барааны мөрүүд.
  List<MapEntry<String, num>> get muruud {
    final b = doc['baraanuud'];
    if (b is! List) return const [];
    return b.whereType<Map>().map((m) {
      final baraa = m['baraa'] is Map ? m['baraa'] as Map : const {};
      final too = m['too'];
      return MapEntry(
        baraa['ner']?.toString() ?? '—',
        too is num ? too : num.tryParse('$too') ?? 0,
      );
    }).toList();
  }
}
