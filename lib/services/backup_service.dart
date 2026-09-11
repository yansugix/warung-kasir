import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'app_settings.dart';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<bool> signIn() async {
    try {
      final user = await _googleSignIn.signIn();
      _currentUser = user;
      return user != null;
    } catch (e) {
      debugPrint('Google Sign In error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<bool> tryAutoSignIn() async {
    try {
      final user = await _googleSignIn.signInSilently();
      _currentUser = user;
      return user != null;
    } catch (_) {
      return false;
    }
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    if (_currentUser == null) return null;
    final authHeaders = await _currentUser!.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    return drive.DriveApi(client);
  }

  Future<String> _getDbPath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, 'warung_kasir.db');
  }

  Future<BackupResult> backup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return BackupResult.notSignedIn;

      final dbFilePath = await _getDbPath();
      final dbFile = File(dbFilePath);
      if (!await dbFile.exists()) return BackupResult.dbNotFound;

      final folderId = await _getOrCreateFolder(driveApi);

      final existingFiles = await driveApi.files.list(
        q: "name='warung_kasir_backup.db' and '$folderId' in parents and trashed=false",
      );

      final driveFileMetadata = drive.File()
        ..name = 'warung_kasir_backup.db'
        ..parents = [folderId];

      final media = drive.Media(
        dbFile.openRead(),
        await dbFile.length(),
        contentType: 'application/octet-stream',
      );

      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        final fileId = existingFiles.files!.first.id!;
        await driveApi.files.update(
          driveFileMetadata,
          fileId,
          uploadMedia: media,
        );
      } else {
        await driveApi.files.create(
          driveFileMetadata,
          uploadMedia: media,
        );
      }

      final now = DateTime.now().toIso8601String();
      await AppSettings.instance.setLastBackup(now);
      return BackupResult.success;
    } catch (e) {
      debugPrint('Backup error: $e');
      return BackupResult.error;
    }
  }

  Future<BackupResult> restore() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return BackupResult.notSignedIn;

      final folderId = await _getOrCreateFolder(driveApi);
      final files = await driveApi.files.list(
        q: "name='warung_kasir_backup.db' and '$folderId' in parents and trashed=false",
      );

      if (files.files == null || files.files!.isEmpty) {
        return BackupResult.noBackupFound;
      }

      final fileId = files.files!.first.id!;
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final dbPath = await _getDbPath();
      final outFile = File(dbPath);
      final sink = outFile.openWrite();
      await sink.addStream(media.stream);
      await sink.close();

      return BackupResult.success;
    } catch (e) {
      debugPrint('Restore error: $e');
      return BackupResult.error;
    }
  }

  Future<String> _getOrCreateFolder(drive.DriveApi driveApi) async {
    const folderName = 'Warung Kasir Backup';
    final existing = await driveApi.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false",
    );

    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id!;
    }

    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await driveApi.files.create(folder);
    return created.id!;
  }
}

enum BackupResult { success, error, notSignedIn, dbNotFound, noBackupFound }

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}