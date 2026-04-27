import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  Future<bool> postVersion({
    required String baseUrl,
    required String project,
    required String platform,
    required String version,
    required bool isForceUpdate,
    required String updateUrl,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/app-version"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "project": project,
          "platform": platform,
          "version": version,
          "minVersion": version, // per mapping version -> minVersion
          "isForceUpdate": isForceUpdate,
          "updateUrl": updateUrl,
          "message": message,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error posting version: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> getLatestVersion(String project, String platform, String baseUrl) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/app-version/$project/$platform"));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Error fetching latest version: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkUpdate(String project, String platform, String baseUrl) async {
    try {
      print("VersionService: checking update for $project on $platform using $baseUrl");
      final latest = await getLatestVersion(project, platform, baseUrl);
      print("VersionService: API returned $latest");
      if (latest == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final latestVersion = latest['version']?.toString()?.trim() ?? '';
      
      print("VersionService: current=$currentVersion, latest=$latestVersion");

      if (latestVersion.isNotEmpty && _isVersionHigher(latestVersion, currentVersion)) {
        print("VersionService: update available!");
        return latest;
      }
      return null;
    } catch (e) {
      print("Error checking for update: $e");
      return null;
    }
  }

  bool _isVersionHigher(String latest, String current) {
    // Strip anything after + or - in the version string (like build numbers or alpha tags)
    String cleanLatest = latest.split('+')[0].split('-')[0];
    String cleanCurrent = current.split('+')[0].split('-')[0];

    List<int> latestParts = cleanLatest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    List<int> currentParts = cleanCurrent.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }
}

final versionService = VersionService();
