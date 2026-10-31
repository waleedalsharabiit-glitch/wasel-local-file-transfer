import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TransferServer extends ChangeNotifier {
  TransferServer._({this._testDirectory, this._testBindAddress});

  @visibleForTesting
  TransferServer.forTesting({
    required Directory directory,
    InternetAddress? bindAddress,
  }) : this._(
         testDirectory: directory,
         testBindAddress: bindAddress ?? InternetAddress.loopbackIPv4,
       );

  static final TransferServer instance = TransferServer._();

  HttpServer? _server;
  Directory? _directory;
  final Directory? _testDirectory;
  final InternetAddress? _testBindAddress;
  Directory? _partialDirectory;
  static const int chunkSize = 4 * 1024 * 1024;
  final Map<String, _PendingTransfer> _pendingTransfers = {};
  final Set<String> _activeTransferWrites = {};

  String? _token;
  String? _url;
  String? _address;
  int? _port;

  bool get isRunning => _server != null;
  String? get token => _token;
  String? get url => _url;
  String? get address => _address;
  int? get port => _port;

  File localFile(String name) {
    final directory = _directory;
    if (directory == null) {
      throw StateError('Start the transfer server first.');
    }
    return File('${directory.path}/${_safeName(name)}');
  }

  List<Map<String, Object?>> files = [];
  final List<Map<String, Object?>> activity = [];

  String? lastError;

  void _recordActivity(String action, String name, int bytes) {
    activity.insert(0, {
      'action': action,
      'name': name,
      'size': bytes,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (activity.length > 100) activity.removeRange(100, activity.length);
  }

  Future<void> start() async {
    if (isRunning) return;

    lastError = null;

    try {
      final directory =
          _testDirectory ??
          Directory(
            '${(await getApplicationDocumentsDirectory()).path}/WaselTransfers',
          );

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      _directory = directory;
      final partialDirectory = Directory('${directory.path}/.partials');
      await partialDirectory.create(recursive: true);
      _partialDirectory = partialDirectory;
      await _loadPendingTransfers();

      final InternetAddress selectedBindAddress;
      final String selectedAddress;
      if (_testBindAddress != null) {
        selectedBindAddress = _testBindAddress;
        selectedAddress = _testBindAddress.address;
      } else {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        final addresses = interfaces
            .expand((interface) => interface.addresses)
            .where(
              (address) =>
                  address.type == InternetAddressType.IPv4 &&
                  !address.isLoopback &&
                  !address.address.startsWith('169.254.'),
            )
            .toList();
        if (addresses.isEmpty) {
          throw Exception(
            'No local IPv4 address found. Connect the phone to Wi-Fi or enable its hotspot.',
          );
        }
        selectedBindAddress = InternetAddress.anyIPv4;
        selectedAddress = addresses.first.address;
      }

      final random = Random.secure();
      final tokenBytes = List<int>.generate(24, (_) => random.nextInt(256));
      final token = tokenBytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();

      final server = await HttpServer.bind(
        selectedBindAddress,
        0,
        shared: false,
      );

      _server = server;
      _token = token;
      _address = selectedAddress;
      _port = server.port;
      _url = 'http://$selectedAddress:${server.port}/?token=$token';

      server.listen(
        _handleRequest,
        onError: (Object error) {
          lastError = error.toString();
          notifyListeners();
        },
      );

      await refreshFiles();
      notifyListeners();
    } catch (error) {
      await stop();
      lastError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;

    if (server != null) {
      await server.close(force: true);
    }

    _token = null;
    _url = null;
    _address = null;
    _port = null;

    notifyListeners();
  }

  bool _authorized(HttpRequest request) {
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );

    final expected = 'Bearer $_token';

    return _token != null && authorization == expected;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');

    final origin = request.headers.value('origin');
    if (origin != null && _isTrustedLocalWebOrigin(origin)) {
      response.headers.set(HttpHeaders.accessControlAllowOriginHeader, origin);
      response.headers.set(HttpHeaders.varyHeader, 'Origin');
      response.headers.set(
        HttpHeaders.accessControlAllowMethodsHeader,
        'GET, PUT, DELETE, OPTIONS',
      );
      response.headers.set(
        HttpHeaders.accessControlAllowHeadersHeader,
        'Authorization, Content-Type, Content-Range',
      );
      response.headers.set(
        HttpHeaders.accessControlExposeHeadersHeader,
        'Content-Disposition, Content-Length, Content-Range, Accept-Ranges',
      );
      response.headers.set(HttpHeaders.accessControlMaxAgeHeader, '600');
    }

    try {
      if (request.method == 'OPTIONS') {
        if (origin == null || !_isTrustedLocalWebOrigin(origin)) {
          response.statusCode = HttpStatus.forbidden;
        } else {
          response.statusCode = HttpStatus.noContent;
        }
        await response.close();
        return;
      }

      final path = request.uri.path;

      // The browser page requires the one-time session token.
      if (path == '/' && request.method == 'GET') {
        if (_token == null || request.uri.queryParameters['token'] != _token) {
          response.statusCode = HttpStatus.unauthorized;
          response.write('Unauthorized');
          await response.close();
          return;
        }

        response.headers.contentType = ContentType.html;
        response.write(_browserPage);
        await response.close();
        return;
      }

      if (!_authorized(request)) {
        response.statusCode = HttpStatus.unauthorized;
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({'error': 'Unauthorized'}));
        await response.close();
        return;
      }

      if (path == '/api/status' && request.method == 'GET') {
        await _sendJson(response, {
          'running': true,
          'name': 'Wasel',
          'version': '1.0',
        });
        return;
      }

      if (path == '/api/files' && request.method == 'GET') {
        await refreshFiles();
        await _sendJson(response, {'files': files});
        return;
      }

      if (path == '/api/upload' && request.method == 'PUT') {
        await _receiveFile(request);
        return;
      }

      if (path == '/api/download' && request.method == 'GET') {
        await _downloadFile(request);
        return;
      }

      if (path == '/api/files' && request.method == 'DELETE') {
        await _deleteFile(request);
        return;
      }

      if (path == '/api/v1/transfers' && request.method == 'POST') {
        await _createResumableTransfer(request);
        return;
      }

      final transferPath = RegExp(
        r'^/api/v1/transfers/([a-f0-9]{32})(?:/(complete))?$',
      ).firstMatch(path);
      if (transferPath != null) {
        final id = transferPath.group(1)!;
        final action = transferPath.group(2);
        if (request.method == 'GET' && action == null) {
          await _getResumableTransfer(request, id);
          return;
        }
        if (request.method == 'PUT' && action == null) {
          await _writeTransferChunk(request, id);
          return;
        }
        if (request.method == 'POST' && action == 'complete') {
          await _completeResumableTransfer(request, id);
          return;
        }
        if (request.method == 'DELETE' && action == null) {
          await _cancelResumableTransfer(request, id);
          return;
        }
      }

      response.statusCode = HttpStatus.notFound;
      response.write('Not found');
      await response.close();
    } catch (error) {
      // The response may already have been committed.
      // Try to send an error response, but never let a secondary
      // response-state error escape this request handler.
      try {
        response.statusCode = HttpStatus.internalServerError;
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({'error': error.toString()}));
        await response.close();
      } catch (_) {
        try {
          await response.close();
        } catch (_) {
          // The connection may already be closed.
        }
      }
    }
  }

  bool _isTrustedLocalWebOrigin(String origin) {
    final uri = Uri.tryParse(origin);
    if (uri == null || uri.scheme != 'http' || !uri.hasAuthority) return false;

    if (uri.host.toLowerCase() == 'localhost') return true;
    final address = InternetAddress.tryParse(uri.host);
    return address != null && address.isLoopback;
  }

  Future<void> _sendJson(
    HttpResponse response,
    Map<String, Object?> data,
  ) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }

  Future<void> _loadPendingTransfers() async {
    final partialDirectory = _partialDirectory;
    if (partialDirectory == null) return;

    await for (final entry in partialDirectory.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final data =
            jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
        final transfer = _PendingTransfer.fromJson(data);
        final part = _partFile(transfer.id);
        if (transfer.id !=
                entry.uri.pathSegments.last.replaceFirst('.json', '') ||
            !await part.exists() ||
            await part.length() > transfer.size) {
          await entry.delete();
          if (await part.exists()) await part.delete();
          continue;
        }
        _pendingTransfers[transfer.id] = transfer;
      } catch (_) {
        try {
          await entry.delete();
        } catch (_) {}
      }
    }
  }

  File _partFile(String id) => File('${_partialDirectory!.path}/$id.part');
  File _transferMetadataFile(String id) =>
      File('${_partialDirectory!.path}/$id.json');

  Future<void> _savePendingTransfer(_PendingTransfer transfer) async {
    final metadata = _transferMetadataFile(transfer.id);
    final temporary = File('${metadata.path}.tmp');
    await temporary.writeAsString(jsonEncode(transfer.toJson()), flush: true);
    if (await metadata.exists()) await metadata.delete();
    await temporary.rename(metadata.path);
  }

  Future<void> _createResumableTransfer(HttpRequest request) async {
    final body = await _readSmallJson(request, maxBytes: 16 * 1024);
    final nameValue = body['name'];
    final sizeValue = body['size'];
    final clientIdValue = body['clientId'];
    if (nameValue is! String ||
        sizeValue is! int ||
        clientIdValue is! String ||
        clientIdValue.isEmpty ||
        clientIdValue.length > 256 ||
        sizeValue < 0) {
      await _sendError(
        request.response,
        HttpStatus.badRequest,
        'invalid_transfer',
        'Invalid transfer metadata.',
      );
      return;
    }

    final name = _safeName(nameValue);
    _PendingTransfer? existing;
    for (final candidate in _pendingTransfers.values) {
      if (candidate.clientId == clientIdValue) {
        existing = candidate;
        break;
      }
    }
    if (existing != null) {
      if (existing.name != name || existing.size != sizeValue) {
        await _sendError(
          request.response,
          HttpStatus.conflict,
          'client_id_conflict',
          'This transfer key belongs to different file metadata.',
        );
        return;
      }
      await _sendTransferStatus(request.response, existing);
      return;
    }

    final id = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final transfer = _PendingTransfer(
      id: id,
      clientId: clientIdValue,
      name: name,
      size: sizeValue,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _partFile(id).create();
    _pendingTransfers[id] = transfer;
    await _savePendingTransfer(transfer);
    await _sendTransferStatus(
      request.response,
      transfer,
      statusCode: HttpStatus.created,
    );
  }

  Future<Map<String, dynamic>> _readSmallJson(
    HttpRequest request, {
    required int maxBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in request) {
      length += chunk.length;
      if (length > maxBytes) {
        throw const FormatException('Request body is too large.');
      }
      builder.add(chunk);
    }
    final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded;
  }

  Future<void> _sendTransferStatus(
    HttpResponse response,
    _PendingTransfer transfer, {
    int statusCode = HttpStatus.ok,
  }) async {
    response.statusCode = statusCode;
    await _sendJson(response, {
      'transferId': transfer.id,
      'name': transfer.name,
      'size': transfer.size,
      'offset': await _partFile(transfer.id).length(),
      'chunkSize': chunkSize,
      'state': 'receiving',
      'createdAt': transfer.createdAt,
    });
  }

  Future<void> _getResumableTransfer(HttpRequest request, String id) async {
    final transfer = _pendingTransfers[id];
    if (transfer == null) {
      await _sendError(
        request.response,
        HttpStatus.notFound,
        'transfer_not_found',
        'Transfer was not found.',
      );
      return;
    }
    await _sendTransferStatus(request.response, transfer);
  }

  Future<void> _writeTransferChunk(HttpRequest request, String id) async {
    final transfer = _pendingTransfers[id];
    if (transfer == null) {
      await _sendError(
        request.response,
        HttpStatus.notFound,
        'transfer_not_found',
        'Transfer was not found.',
      );
      return;
    }
    if (_activeTransferWrites.contains(id)) {
      await _sendError(
        request.response,
        HttpStatus.conflict,
        'transfer_busy',
        'A chunk for this transfer is already being written.',
      );
      return;
    }

    final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
        .firstMatch(request.headers.value('content-range') ?? '');
    if (range == null) {
      await _sendError(
        request.response,
        HttpStatus.badRequest,
        'invalid_range',
        'A valid Content-Range header is required.',
      );
      return;
    }
    final start = int.parse(range.group(1)!);
    final end = int.parse(range.group(2)!);
    final total = int.parse(range.group(3)!);
    final chunkLength = end - start + 1;
    final part = _partFile(id);
    final currentOffset = await part.length();
    if (total != transfer.size ||
        start != currentOffset ||
        end < start ||
        chunkLength > chunkSize ||
        end >= total ||
        (request.contentLength >= 0 && request.contentLength != chunkLength)) {
      await _sendError(
        request.response,
        HttpStatus.conflict,
        'invalid_offset',
        'Chunk range does not match the current transfer offset.',
      );
      return;
    }

    _activeTransferWrites.add(id);
    final sink = part.openWrite(mode: FileMode.append);
    var written = 0;
    try {
      await for (final bytes in request) {
        written += bytes.length;
        if (written > chunkLength) {
          throw const FormatException('Chunk body exceeds its declared range.');
        }
        sink.add(bytes);
      }
      await sink.flush();
      await sink.close();
      if (written != chunkLength) {
        throw const FormatException(
          'Chunk body is shorter than its declared range.',
        );
      }
      final offset = await part.length();
      await _savePendingTransfer(transfer);
      await _sendJson(request.response, {
        'transferId': id,
        'offset': offset,
        'state': 'receiving',
      });
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        await request.response.close();
      } catch (_) {}
    } finally {
      _activeTransferWrites.remove(id);
    }
  }

  Future<void> _completeResumableTransfer(
    HttpRequest request,
    String id,
  ) async {
    final transfer = _pendingTransfers[id];
    if (transfer == null) {
      await _sendError(
        request.response,
        HttpStatus.notFound,
        'transfer_not_found',
        'Transfer was not found.',
      );
      return;
    }
    if (_activeTransferWrites.contains(id)) {
      await _sendError(
        request.response,
        HttpStatus.conflict,
        'transfer_busy',
        'A chunk is still being written.',
      );
      return;
    }
    final part = _partFile(id);
    final size = await part.length();
    if (size != transfer.size) {
      await _sendError(
        request.response,
        HttpStatus.conflict,
        'incomplete_transfer',
        'The uploaded file is incomplete.',
      );
      return;
    }
    final digest = await sha256.bind(part.openRead()).first;
    final destination = await _uniqueDestination(transfer.name);
    final saved = await part.rename(destination.path);
    final savedName = saved.uri.pathSegments.last;
    final metadata = _transferMetadataFile(id);
    if (await metadata.exists()) await metadata.delete();
    _pendingTransfers.remove(id);
    _recordActivity('received', savedName, size);
    await refreshFiles();
    await _sendJson(request.response, {
      'success': true,
      'transferId': id,
      'name': savedName,
      'size': size,
      'sha256': digest.toString(),
    });
  }

  Future<void> _cancelResumableTransfer(HttpRequest request, String id) async {
    if (_activeTransferWrites.contains(id)) {
      await _sendError(
        request.response,
        HttpStatus.conflict,
        'transfer_busy',
        'Abort the active chunk before cancelling the transfer.',
      );
      return;
    }
    final transfer = _pendingTransfers.remove(id);
    if (transfer == null) {
      await _sendError(
        request.response,
        HttpStatus.notFound,
        'transfer_not_found',
        'Transfer was not found.',
      );
      return;
    }
    final part = _partFile(id);
    final metadata = _transferMetadataFile(id);
    if (await part.exists()) await part.delete();
    if (await metadata.exists()) await metadata.delete();
    await _sendJson(request.response, {
      'success': true,
      'transferId': id,
      'state': 'cancelled',
    });
  }

  Future<void> _sendError(
    HttpResponse response,
    int status,
    String code,
    String message,
  ) async {
    response.statusCode = status;
    await _sendJson(response, {'error': message, 'code': code});
  }

  String _safeName(String input) {
    var name = input.trim().split(RegExp(r'[/\\]')).last;

    name = name.replaceAll(RegExp(r'[\x00-\x1F<>:"|?*]'), '_');

    if (name.isEmpty || name == '.' || name == '..') {
      throw const FormatException('Invalid file name.');
    }

    if (name.length > 180) {
      name = name.substring(name.length - 180);
    }

    return name;
  }

  Future<File> _uniqueDestination(String requestedName) async {
    final directory = _directory;
    if (directory == null) {
      throw StateError('Transfer directory is not ready.');
    }

    final safeName = _safeName(requestedName);
    var candidate = safeName;
    var index = 1;

    while (await File('${directory.path}/$candidate').exists()) {
      final dot = safeName.lastIndexOf('.');
      final hasExtension = dot > 0;

      final base = hasExtension ? safeName.substring(0, dot) : safeName;
      final extension = hasExtension ? safeName.substring(dot) : '';

      candidate = '$base ($index)$extension';
      index++;
    }

    return File('${directory.path}/$candidate');
  }

  Future<void> _receiveFile(HttpRequest request) async {
    final requestedName = request.uri.queryParameters['name'];

    if (requestedName == null || requestedName.trim().isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Missing file name');
      await request.response.close();
      return;
    }

    final directory = _directory;
    if (directory == null) {
      throw StateError('Transfer directory is not ready.');
    }

    final destination = await _uniqueDestination(requestedName);
    final randomSuffix = Random.secure().nextInt(1 << 32);
    final temporary = File('${directory.path}/.upload-$randomSuffix.part');

    try {
      // Stream the incoming body to disk without loading the
      // entire file into memory.
      final sink = temporary.openWrite();

      try {
        await request.forEach(sink.add);
        await sink.flush();
      } finally {
        await sink.close();
      }

      final digest = await sha256.bind(temporary.openRead()).first;
      final savedFile = await temporary.rename(destination.path);
      _recordActivity(
        'received',
        savedFile.uri.pathSegments.last,
        await savedFile.length(),
      );

      await refreshFiles();

      await _sendJson(request.response, {
        'success': true,
        'name': savedFile.uri.pathSegments.last,
        'size': await savedFile.length(),
        'sha256': digest.toString(),
      });
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  Future<void> _downloadFile(HttpRequest request) async {
    final name = request.uri.queryParameters['name'];

    if (name == null || name.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Missing file name');
      await request.response.close();
      return;
    }

    final safeName = _safeName(name);
    final directory = _directory!;

    final file = File('${directory.path}/$safeName');

    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found');
      await request.response.close();
      return;
    }

    final length = await file.length();
    final requestedRange = request.headers.value(HttpHeaders.rangeHeader);
    var start = 0;
    var end = length == 0 ? 0 : length - 1;
    if (requestedRange != null) {
      final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(requestedRange);
      if (match == null || length == 0) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        request.response.headers.set('Content-Range', 'bytes */$length');
        await request.response.close();
        return;
      }
      start = int.parse(match.group(1)!);
      end = match.group(2)!.isEmpty ? length - 1 : int.parse(match.group(2)!);
      if (start >= length || end < start) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        request.response.headers.set('Content-Range', 'bytes */$length');
        await request.response.close();
        return;
      }
      end = min(end, length - 1);
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        'Content-Range',
        'bytes $start-$end/$length',
      );
    }

    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.headers.contentType = ContentType.binary;
    request.response.headers.set(
      'Content-Disposition',
      "attachment; filename*=UTF-8''${Uri.encodeComponent(safeName)}",
    );
    request.response.headers.contentLength = end - start + 1;

    await file.openRead(start, end + 1).pipe(request.response);
  }

  Future<void> _deleteFile(HttpRequest request) async {
    final name = request.uri.queryParameters['name'];

    if (name == null || name.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Missing file name');
      await request.response.close();
      return;
    }

    final safeName = _safeName(name);
    final directory = _directory!;
    final file = File('${directory.path}/$safeName');

    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found');
      await request.response.close();
      return;
    }

    final size = await file.length();
    await file.delete();
    _recordActivity('deleted', safeName, size);
    await refreshFiles();

    await _sendJson(request.response, {'success': true});
  }

  Future<void> refreshFiles() async {
    final directory = _directory;

    if (directory == null || !await directory.exists()) {
      files = [];
      notifyListeners();
      return;
    }

    final result = <Map<String, Object?>>[];

    await for (final entity in directory.list()) {
      if (entity is! File) continue;

      final name = entity.uri.pathSegments.last;

      if (name.startsWith('.')) continue;

      final size = await entity.length();
      final digest = await sha256.bind(entity.openRead()).first;

      result.add({'name': name, 'size': size, 'sha256': digest.toString()});
    }

    result.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));

    files = result;
    notifyListeners();
  }

  Future<int> pickFilesFromPhone() async {
    final directory = _directory;

    if (directory == null) {
      throw StateError('Start the transfer server first.');
    }

    final pickedFiles = await FilePicker.pickFiles(type: FileType.any);

    if (pickedFiles.isEmpty) return 0;

    var copied = 0;

    for (final picked in pickedFiles) {
      final sourcePath = picked.path;
      if (sourcePath == null) continue;

      final source = File(sourcePath);
      if (!await source.exists()) continue;

      final destination = await _uniqueDestination(picked.name);
      final copiedFile = await source.copy(destination.path);
      _recordActivity(
        'added',
        copiedFile.uri.pathSegments.last,
        await copiedFile.length(),
      );
      copied++;
    }

    await refreshFiles();
    return copied;
  }

  Future<void> deleteLocalFile(String name) async {
    final safeName = _safeName(name);
    final directory = _directory!;

    final file = File('${directory.path}/$safeName');

    if (await file.exists()) {
      final size = await file.length();
      await file.delete();
      _recordActivity('deleted', safeName, size);
      await refreshFiles();
    }
  }

  static const String _browserPage = r'''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#0284c7">
<title>Wasel — Local Transfer</title>
<style>
*{box-sizing:border-box}
body{margin:0;background:#f4f8fc;color:#0f172a;font-family:Arial,sans-serif}
header{background:linear-gradient(120deg,#0369a1,#0284c7,#38bdf8);color:white;padding:30px 20px}
.wrap{max-width:850px;margin:auto}
h1{margin:0;font-size:27px}
header p{margin:9px 0 0;opacity:.9}
main{max-width:850px;margin:22px auto;padding:0 16px}
.card{background:white;border:1px solid #e2e8f0;border-radius:18px;padding:20px;margin-bottom:16px;box-shadow:0 5px 20px #0f172a0a}
.drop{border:2px dashed #7dd3fc;background:#f0f9ff;border-radius:15px;text-align:center;padding:35px 15px}
button,.pick{border:0;border-radius:11px;padding:12px 17px;background:#0284c7;color:white;font-weight:bold;cursor:pointer}
button.secondary{background:#e0f2fe;color:#075985}
button.danger{background:#fee2e2;color:#991b1b}
input{display:none}
.item{display:flex;gap:12px;align-items:center;justify-content:space-between;padding:14px 0;border-bottom:1px solid #e2e8f0}
.item:last-child{border:0}
.meta{min-width:0;overflow-wrap:anywhere}
.meta small{display:block;color:#64748b;margin-top:5px}
.actions{display:flex;gap:7px;flex-shrink:0}
progress{width:100%;height:12px;margin-top:14px}
#status{color:#0369a1;font-size:14px;min-height:20px;margin-top:12px}
.empty{color:#64748b;text-align:center;padding:20px}
@media(max-width:560px){.item{align-items:flex-start;flex-direction:column}.actions{width:100%}.actions button{flex:1}}
</style>
</head>
<body>
<header><div class="wrap"><h1>Wasel</h1><p>Private file transfer over your local network</p></div></header>
<main>
<section class="card">
<h2>Send files to your phone</h2>
<div class="drop" id="drop">
<p>Choose files or drag them here</p>
<label class="pick" for="picker">Choose files</label>
<input id="picker" type="file" multiple>
</div>
<progress id="progress" value="0" max="100" hidden></progress>
<div id="status" role="status"></div>
</section>
<section class="card">
<h2>Files available on this phone</h2>
<button class="secondary" id="refresh">Refresh list</button>
<div id="files" class="empty">Loading files…</div>
</section>
</main>
<script>
const token=new URLSearchParams(location.search).get('token')||'';
const headers={'Authorization':'Bearer '+token};
const statusBox=document.getElementById('status');
const fileBox=document.getElementById('files');
const progress=document.getElementById('progress');

function message(text){statusBox.textContent=text}
function formatSize(n){
 if(n<1024)return n+' B';
 if(n<1048576)return (n/1024).toFixed(1)+' KB';
 if(n<1073741824)return (n/1048576).toFixed(1)+' MB';
 return (n/1073741824).toFixed(2)+' GB';
}
async function refreshFiles(){
 try{
  const r=await fetch('/api/files',{headers});
  if(!r.ok)throw new Error('Could not load files');
  const data=await r.json();
  fileBox.textContent='';
  if(!data.files.length){fileBox.className='empty';fileBox.textContent='No files yet';return}
  fileBox.className='';
  for(const f of data.files){
   const row=document.createElement('div');row.className='item';
   const meta=document.createElement('div');meta.className='meta';
   const name=document.createElement('strong');name.textContent=f.name;
   const details=document.createElement('small');
   details.textContent=formatSize(f.size)+' آ· SHA-256: '+f.sha256;
   meta.append(name,details);
   const actions=document.createElement('div');actions.className='actions';
   const download=document.createElement('button');download.textContent='Download';
   download.onclick=()=>downloadFile(f.name);
   const remove=document.createElement('button');remove.textContent='Delete';remove.className='danger';
   remove.onclick=()=>deleteFile(f.name);
   actions.append(download,remove);row.append(meta,actions);fileBox.append(row);
  }
 }catch(e){fileBox.textContent=e.message}
}
function upload(file){
 return new Promise((resolve,reject)=>{
  const xhr=new XMLHttpRequest();
  xhr.open('PUT','/api/upload?name='+encodeURIComponent(file.name));
  xhr.setRequestHeader('Authorization','Bearer '+token);
  xhr.upload.onprogress=e=>{
   if(e.lengthComputable){
    progress.hidden=false;progress.value=e.loaded/e.total*100;
    message('Uploading '+file.name+' — '+Math.round(progress.value)+'%');
   }
  };
  xhr.onload=()=>{
   progress.hidden=true;
   if(xhr.status>=200&&xhr.status<300)resolve(JSON.parse(xhr.responseText));
   else reject(new Error(xhr.responseText||'Upload failed'));
  };
  xhr.onerror=()=>reject(new Error('Network error during upload'));
  xhr.send(file);
 });
}
async function uploadFiles(files){
 for(const file of files){
  try{
   const result=await upload(file);
   message('Uploaded '+result.name+' آ· SHA-256 verified');
  }catch(e){message('Upload failed: '+e.message)}
 }
 await refreshFiles();
}
async function downloadFile(name){
 try{
  message('Preparing '+name);
  const r=await fetch('/api/download?name='+encodeURIComponent(name),{headers});
  if(!r.ok)throw new Error('Download failed');
  const blob=await r.blob();
  const a=document.createElement('a');
  const url=URL.createObjectURL(blob);
  a.href=url;a.download=name;a.click();
  URL.revokeObjectURL(url);
  message('Download started: '+name);
 }catch(e){message(e.message)}
}
async function deleteFile(name){
 if(!confirm('Delete '+name+' from the phone?'))return;
 const r=await fetch('/api/files?name='+encodeURIComponent(name),{method:'DELETE',headers});
 if(!r.ok){message('Delete failed');return}
 message('File deleted');await refreshFiles();
}
document.getElementById('picker').addEventListener('change',e=>uploadFiles(e.target.files));
document.getElementById('refresh').onclick=refreshFiles;
const drop=document.getElementById('drop');
drop.addEventListener('dragover',e=>{e.preventDefault();drop.style.background='#e0f2fe'});
drop.addEventListener('dragleave',()=>drop.style.background='#f0f9ff');
drop.addEventListener('drop',e=>{
 e.preventDefault();drop.style.background='#f0f9ff';uploadFiles(e.dataTransfer.files);
});
refreshFiles();
</script>
</body>
</html>
''';
}

class _PendingTransfer {
  const _PendingTransfer({
    required this.id,
    required this.clientId,
    required this.name,
    required this.size,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String name;
  final int size;
  final String createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'clientId': clientId,
    'name': name,
    'size': size,
    'createdAt': createdAt,
  };

  factory _PendingTransfer.fromJson(Map<String, dynamic> json) =>
      _PendingTransfer(
        id: json['id'] as String,
        clientId: json['clientId'] as String,
        name: json['name'] as String,
        size: json['size'] as int,
        createdAt: json['createdAt'] as String,
      );
}
