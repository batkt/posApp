import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';
import '../pos_transaction_service.dart';
import 'online_tuluv.dart';

/// Синк хийгдээгүй (офлайн) нэг борлуулалт.
class OfflineGuilgee {
  OfflineGuilgee({
    required this.id,
    required this.salbarKey,
    required this.payload,
    required this.uusgesenOgnoo,
    this.tuluv = 'khuleegdej',
    this.aldaa,
    this.oroldlogo = 0,
    this.uldegdelKhasakh = const {},
  });

  /// `clientGuilgeeniiId` — сервер үүгээр давхардлыг шүүнэ.
  final String id;
  final String salbarKey;
  final Map<String, dynamic> payload;
  final DateTime uusgesenOgnoo;

  /// `khuleegdej` (илгээгдэхийг хүлээж буй) | `aldaa` (сервер татгалзсан).
  String tuluv;
  String? aldaa;
  int oroldlogo;

  /// Барааны id → сагсанд хассан тоо. Үлдэгдлийг серверээс/кэшээс дахин
  /// ачаалахад синк хийгдээгүй борлуулалтыг дахин хасахад хэрэглэнэ.
  final Map<String, int> uldegdelKhasakh;

  String get dugaar => payload['guilgeeniiDugaar']?.toString() ?? '';
  double get niitUne => (payload['niitUne'] as num?)?.toDouble() ?? 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'salbarKey': salbarKey,
        'payload': payload,
        'uusgesenOgnoo': uusgesenOgnoo.toIso8601String(),
        'tuluv': tuluv,
        'aldaa': aldaa,
        'oroldlogo': oroldlogo,
        'uldegdelKhasakh': uldegdelKhasakh,
      };

  static OfflineGuilgee fromJson(Map<String, dynamic> j) => OfflineGuilgee(
        id: j['id'].toString(),
        salbarKey: j['salbarKey']?.toString() ?? '',
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        uusgesenOgnoo:
            DateTime.tryParse(j['uusgesenOgnoo']?.toString() ?? '') ??
                DateTime.now(),
        tuluv: j['tuluv']?.toString() ?? 'khuleegdej',
        aldaa: j['aldaa']?.toString(),
        oroldlogo: (j['oroldlogo'] as num?)?.toInt() ?? 0,
        uldegdelKhasakh: (j['uldegdelKhasakh'] is Map)
            ? (j['uldegdelKhasakh'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toInt()),
              )
            : const {},
      );
}

/// Офлайн борлуулалтын дараалал. Төхөөрөмж дээр хадгалагдаж, холболт
/// сэргэмэгц хуучнаас нь эхлэн илгээгдэнэ. Сервер татгалзсан борлуулалт
/// (жишээ нь үлдэгдэл хүрэлцэхгүй) устгагдахгүй — алдаатайгаа үлдэж,
/// менежер шийдвэрлэнэ. Үлдэгдэл хасах руу хэзээ ч оруулахгүй.
class OfflineGuilgeeQueue extends ChangeNotifier {
  OfflineGuilgeeQueue._();
  static final OfflineGuilgeeQueue instance = OfflineGuilgeeQueue._();

  static const _prefsKey = 'posOfflineGuilgee';
  static const _fileNer = 'pos_offline_guilgee.json';
  static const Duration _sinkInterval = Duration(seconds: 30);

  final List<OfflineGuilgee> _jagsaalt = [];
  bool _achaalsan = false;
  bool _sinkKhiijBaina = false;
  Timer? _timer;
  Future<void>? _achaalakhFuture;

  /// Синк амжилттай болоход (үлдэгдэл, түүх шинэчлэх).
  final StreamController<int> _ilgeesenCtrl =
      StreamController<int>.broadcast();
  Stream<int> get ilgeesen => _ilgeesenCtrl.stream;

  bool get sinkKhiijBaina => _sinkKhiijBaina;

  static String salbarKeyAvakh(String baiguullagiinId, String salbariinId) =>
      '$baiguullagiinId|$salbariinId';

  List<OfflineGuilgee> salbariinJagsaalt(String salbarKey) =>
      _jagsaalt.where((e) => e.salbarKey == salbarKey).toList()
        ..sort((a, b) => a.uusgesenOgnoo.compareTo(b.uusgesenOgnoo));

  /// Синк хийгдээгүй борлуулалтуудын барааны хасах тоо (бүх салбар биш —
  /// тухайн салбарынх).
  Map<String, int> uldegdelKhasakh(String salbarKey) {
    final out = <String, int>{};
    for (final e in _jagsaalt) {
      if (e.salbarKey != salbarKey) continue;
      e.uldegdelKhasakh.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    }
    return out;
  }

  // ---------- Хадгалалт ----------

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileNer');
  }

  Future<void> achaalakh() {
    if (_achaalsan) return Future.value();
    return _achaalakhFuture ??= _achaalakhImpl();
  }

  Future<void> _achaalakhImpl() async {
    try {
      String? raw;
      if (kIsWeb) {
        raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      } else {
        final f = await _file();
        if (await f.exists()) raw = await f.readAsString();
      }
      if (raw != null && raw.trim().isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _jagsaalt
          ..clear()
          ..addAll(list.whereType<Map>().map(
              (m) => OfflineGuilgee.fromJson(Map<String, dynamic>.from(m))));
      }
    } catch (e) {
      debugPrint('[OfflineGuilgeeQueue] achaalakh алдаа: $e');
    }
    _achaalsan = true;
    notifyListeners();
  }

  Future<void> _khadgalakh() async {
    final raw = jsonEncode(_jagsaalt.map((e) => e.toJson()).toList());
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(_prefsKey, raw);
    } else {
      // Түр файлд бичээд солих — бичиж байх үед апп унтарвал хуучин
      // дараалал эвдрэхгүй.
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(raw, flush: true);
      await tmp.rename(f.path);
    }
  }

  // ---------- Нэмэх / устгах ----------

  /// Борлуулалтыг дараалалд нэмнэ. Хадгалж чадаагүй бол алдаа шиднэ —
  /// дуудагч "амжилттай" гэж харуулах ёсгүй.
  Future<OfflineGuilgee> nemekh({
    required Map<String, dynamic> payload,
    required Map<String, int> uldegdelKhasakh,
  }) async {
    await achaalakh();
    final entry = OfflineGuilgee(
      id: payload['clientGuilgeeniiId'].toString(),
      salbarKey: salbarKeyAvakh(
        payload['baiguullagiinId']?.toString() ?? '',
        payload['salbariinId']?.toString() ?? '',
      ),
      payload: payload,
      uusgesenOgnoo: DateTime.now(),
      uldegdelKhasakh: uldegdelKhasakh,
    );
    _jagsaalt.removeWhere((e) => e.id == entry.id);
    _jagsaalt.add(entry);
    try {
      await _khadgalakh();
    } catch (e) {
      _jagsaalt.removeWhere((x) => x.id == entry.id);
      rethrow;
    }
    notifyListeners();
    return entry;
  }

  Future<void> ustgakh(String id) async {
    await achaalakh();
    _jagsaalt.removeWhere((e) => e.id == id);
    await _khadgalakh();
    notifyListeners();
  }

  // ---------- Синк ----------

  /// Апп ажиллах хугацаанд: холболт сэргэх, 30 сек тутам автоматаар илгээнэ.
  void autoSinkEkhluulekh() {
    if (_timer != null) return;
    unawaited(achaalakh());
    OnlineTuluv.instance.ekhluulekh();
    OnlineTuluv.instance.addListener(() {
      if (OnlineTuluv.instance.online) unawaited(sinkKhiikh());
    });
    _timer = Timer.periodic(_sinkInterval, (_) {
      if (OnlineTuluv.instance.online) unawaited(sinkKhiikh());
    });
    unawaited(sinkKhiikh());
  }

  /// Дарааллыг илгээнэ (бүх салбар — payload бүр өөрийн салбартай).
  /// Сүлжээний алдаа гармагц зогсоно.
  Future<int> sinkKhiikh() async {
    await achaalakh();
    if (_sinkKhiijBaina || _jagsaalt.isEmpty) return 0;
    if (!OnlineTuluv.instance.online) return 0;
    // Нэвтрээгүй (токенгүй) үед илгээхгүй — нэвтэрсний дараа автоматаар.
    final token = posApiService.token;
    if (token == null || token.isEmpty) return 0;
    _sinkKhiijBaina = true;
    notifyListeners();
    var ilgeesenToo = 0;
    final svc = PosTransactionService();
    try {
      final daraalal = List<OfflineGuilgee>.from(_jagsaalt)
        ..sort((a, b) => a.uusgesenOgnoo.compareTo(b.uusgesenOgnoo));
      for (final entry in daraalal) {
        try {
          await svc.postGuilgeeBody(Map<String, dynamic>.from(entry.payload));
          _jagsaalt.removeWhere((e) => e.id == entry.id);
          ilgeesenToo++;
          await _khadgalakh();
          notifyListeners();
        } catch (e) {
          if (OnlineTuluv.holboltiinAldaaEsekh(e)) {
            OnlineTuluv.instance.holboltTasarsan();
            break;
          }
          final status = e is PosTransactionException ? e.statusCode : null;
          final msg = e is PosTransactionException ? e.message : e.toString();
          final nevtrekh = status == 401 ||
              msg.toLowerCase().contains('jwt') ||
              msg.toLowerCase().contains('token');
          entry
            ..tuluv = 'aldaa'
            ..aldaa = nevtrekh
                ? 'Нэвтрэлт дууссан байна. Дахин нэвтэрсний дараа автоматаар илгээгдэнэ.'
                : msg
            ..oroldlogo += 1;
          await _khadgalakh();
          notifyListeners();
          if (nevtrekh) break;
        }
      }
    } finally {
      _sinkKhiijBaina = false;
      notifyListeners();
    }
    if (ilgeesenToo > 0) _ilgeesenCtrl.add(ilgeesenToo);
    return ilgeesenToo;
  }

  // ---------- ID, баримтын дугаар ----------

  static final Random _rnd = Random.secure();

  static String clientIdUusgekh() {
    String hex(int n) => List.generate(
            n, (_) => _rnd.nextInt(16).toRadixString(16))
        .join();
    return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}';
  }

  /// Офлайн баримтын дугаар: ОФ + YYMMDD + төхөөрөмжийн код(4) + дараалал(3+).
  /// Вэбийнхтэй ижил хэлбэр; "-" ашиглахгүй (сервер буцаалтад ашигладаг).
  static Future<String> offlineDugaarUusgekh() async {
    final prefs = await SharedPreferences.getInstance();
    var kod = prefs.getString('posTokhooromjiinKod');
    if (kod == null || !RegExp(r'^\d{4}$').hasMatch(kod)) {
      kod = (1000 + _rnd.nextInt(9000)).toString();
      await prefs.setString('posTokhooromjiinKod', kod);
    }
    final d = DateTime.now();
    final yymmdd = '${(d.year % 100).toString().padLeft(2, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
    final toololKey = 'posOfflineToolol:$yymmdd';
    final daraagiin = (prefs.getInt(toololKey) ?? 0) + 1;
    await prefs.setInt(toololKey, daraagiin);
    return 'ОФ$yymmdd$kod${daraagiin.toString().padLeft(3, '0')}';
  }
}
