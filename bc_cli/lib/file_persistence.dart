import 'package:braincloud/data_persistence.dart';
import 'dart:convert';
import 'dart:io';

/// Simple File Persistence class that uses a basic cache and save to file in current directory.
class FilePersistence implements DataPersistenceBase {
  static const configFile = 'config.json';
  Map<String, dynamic>? configCache;

  @override
  Future<String?> getString(String key) async {
    var config = await readJsonFromFile(configFile);
    return config[key];
  }

  @override
  Future setString(String key, String value) async {
    var configdata = await readJsonFromFile(configFile);
    configdata[key] = value;
    writeJsonToFile(configFile, configdata);
  }

  void writeJsonToFile(String filePath, Map<String, dynamic> data) async {
    final file = File(filePath);

    // Ensure the directory exists
    await file.parent.create(recursive: true);

    final jsonString = jsonEncode(data);

    await file.writeAsString(jsonString);
  }

  Future<Map<String, dynamic>> readJsonFromFile(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      return {};
    }

    try {
      final jsonString = await file.readAsString();
      configCache = jsonDecode(jsonString);
      return configCache!;
    } catch (e) {
      // Bad data, so ignore it and return empty config.
      return configCache ?? {};
    }
  }
}
