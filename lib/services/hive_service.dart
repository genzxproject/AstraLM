import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

/// Keys that match this pattern are stored in Android Keystore via
/// flutter_secure_storage instead of plain Hive.
const _secureKeyPatterns = ['api_key', 'secret', 'token'];

class HiveService extends GetxService {
  final _secureStorage = const FlutterSecureStorage();
  late Box _sessionsBox;
  late Box _messagesBox;
  late Box _tasksBox;
  late Box _settingsBox;

  Box get sessionsBox => _sessionsBox;
  Box get messagesBox => _messagesBox;
  Box get tasksBox => _tasksBox;
  Box get settingsBox => _settingsBox;

  Future<HiveService> init() async {
    _sessionsBox = await Hive.openBox(AppConstants.chatSessionsBox);
    _messagesBox = await Hive.openBox(AppConstants.chatMessagesBox);
    _tasksBox = await Hive.openBox(AppConstants.tasksBox);
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
    // Preserve current local-server settings and purge obsolete provider data.
    final obsoleteServerKeys = _settingsBox.keys.where((key) =>
        key is String &&
        key.startsWith('server_') &&
        key != AppConstants.keyServerApiKey &&
        key != AppConstants.keyServerUseApiKey);
    await _settingsBox.deleteAll(obsoleteServerKeys);
    return this;
  }

  // ─── Settings helpers ───────────────────────────

  bool _isSecureKey(String key) =>
      _secureKeyPatterns.any((p) => key.toLowerCase().contains(p));

  /// Read sensitive keys from Android Keystore (async).
  Future<String?> getSecureSetting(String key) async {
    return await _secureStorage.read(key: key);
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> setSetting(String key, dynamic value) async {
    // Sensitive keys: write to Android Keystore (and remove from plain Hive).
    if (_isSecureKey(key)) {
      if (value == null || value.toString().isEmpty) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: value.toString());
      }
      await _settingsBox.delete(key); // purge plain-text copy
      return;
    }
    await _settingsBox.put(key, value);
  }

  // ─── Chat Sessions ─────────────────────────────

  List<Map<dynamic, dynamic>> getAllSessions() {
    return _sessionsBox.values
        .map((v) => Map<dynamic, dynamic>.from(v))
        .toList();
  }

  Future<void> saveSession(String id, Map<String, dynamic> data) async {
    await _sessionsBox.put(id, data);
  }

  Future<void> deleteSession(String id) async {
    await _sessionsBox.delete(id);
    // Delete all messages for this session
    final keysToDelete = <dynamic>[];
    for (var key in _messagesBox.keys) {
      final msg = _messagesBox.get(key);
      if (msg is Map && msg['chatId'] == id) {
        keysToDelete.add(key);
      }
    }
    await _messagesBox.deleteAll(keysToDelete);
  }

  // ─── Chat Messages ─────────────────────────────

  List<Map<dynamic, dynamic>> getMessagesForChat(String chatId) {
    return _messagesBox.values
        .where((v) => v is Map && v['chatId'] == chatId)
        .map((v) => Map<dynamic, dynamic>.from(v))
        .toList();
  }

  Future<void> saveMessage(String id, Map<String, dynamic> data) async {
    await _messagesBox.put(id, data);
  }

  // ─── Tasks ─────────────────────────────────────

  List<Map<dynamic, dynamic>> getAllTasks() {
    return _tasksBox.values.map((v) => Map<dynamic, dynamic>.from(v)).toList();
  }

  Future<void> saveTask(String id, Map<String, dynamic> data) async {
    await _tasksBox.put(id, data);
  }

  Future<void> deleteTask(String id) async {
    await _tasksBox.delete(id);
  }
}
