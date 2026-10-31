import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_app/services/transfer_server.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _RealHttpOverrides();
  });

  late Directory directory;
  late TransferServer server;
  late HttpClient client;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wasel-transfer-test-');
    server = TransferServer.forTesting(directory: directory);
    client = HttpClient();
    await server.start();
  });

  tearDown(() async {
    await server.stop();
    client.close(force: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Uri endpoint(String path) =>
      Uri(scheme: 'http', host: '127.0.0.1', port: server.port!).resolve(path);

  Future<_Result> send(
    String method,
    String path, {
    Object? json,
    List<int>? bytes,
    Map<String, String> headers = const {},
    bool authenticate = true,
  }) async {
    final request = await client.openUrl(method, endpoint(path));
    if (authenticate) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${server.token}',
      );
    }
    headers.forEach(request.headers.set);
    if (json != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(json));
    }
    if (bytes != null) request.add(bytes);
    final response = await request.close();
    final responseBytes = await response.fold<List<int>>(
      <int>[],
      (accumulated, chunk) => accumulated..addAll(chunk),
    );
    return _Result(response.statusCode, responseBytes, response.headers);
  }

  Future<Map<String, dynamic>> createTransfer(
    String name,
    List<int> bytes, {
    String? clientId,
  }) async {
    final result = await send(
      'POST',
      '/api/v1/transfers',
      json: {
        'name': name,
        'size': bytes.length,
        'clientId': clientId ?? 'test-${Random().nextInt(1 << 32)}',
      },
    );
    expect(result.status, HttpStatus.created);
    return jsonDecode(result.body) as Map<String, dynamic>;
  }

  Future<void> writeChunks(
    String id,
    List<int> bytes, {
    int chunkSize = 128 * 1024,
  }) async {
    for (var start = 0; start < bytes.length; start += chunkSize) {
      final end = min(start + chunkSize, bytes.length) - 1;
      final chunk = bytes.sublist(start, end + 1);
      final result = await send(
        'PUT',
        '/api/v1/transfers/$id',
        bytes: chunk,
        headers: {'Content-Range': 'bytes $start-$end/${bytes.length}'},
      );
      expect(result.status, HttpStatus.ok, reason: result.body);
      expect(
        (jsonDecode(result.body) as Map<String, dynamic>)['offset'],
        end + 1,
      );
    }
  }

  test(
    'uploads in chunks, verifies SHA-256, and downloads a byte range',
    () async {
      final bytes = List<int>.generate(
        TransferServer.chunkSize * 2 + 37,
        (index) => (index * 31) % 256,
      );
      final transfer = await createTransfer('sample.bin', bytes);
      final id = transfer['transferId'] as String;

      await writeChunks(id, bytes, chunkSize: TransferServer.chunkSize);
      final completed = await send('POST', '/api/v1/transfers/$id/complete');

      expect(completed.status, HttpStatus.ok);
      final completion = jsonDecode(completed.body) as Map<String, dynamic>;
      expect(completion['name'], 'sample.bin');
      expect(completion['size'], bytes.length);
      expect(completion['sha256'], sha256.convert(bytes).toString());

      final list = await send('GET', '/api/files');
      final listed =
          (jsonDecode(list.body) as Map<String, dynamic>)['files'] as List;
      expect(list.status, HttpStatus.ok);
      expect(listed.single['sha256'], sha256.convert(bytes).toString());

      final range = await send(
        'GET',
        '/api/download?name=sample.bin',
        headers: {'Range': 'bytes=12345-12399'},
      );
      expect(range.status, HttpStatus.partialContent);
      expect(
        range.headers.value('content-range'),
        'bytes 12345-12399/${bytes.length}',
      );
      expect(range.bytes, bytes.sublist(12345, 12400));

      final ticketResponse = await send(
        'POST',
        '/api/download-ticket',
        json: {'name': 'sample.bin'},
      );
      final ticket = (jsonDecode(ticketResponse.body) as Map)['ticket'];
      final ticketDownload = await send(
        'GET',
        '/api/download?name=sample.bin&ticket=$ticket',
        authenticate: false,
        headers: {'Range': 'bytes=0-15'},
      );
      expect(ticketDownload.status, HttpStatus.partialContent);
      expect(ticketDownload.bytes, bytes.sublist(0, 16));
      final wrongName = await send(
        'GET',
        '/api/download?name=another.bin&ticket=$ticket',
        authenticate: false,
      );
      expect(wrongName.status, HttpStatus.unauthorized);
    },
  );

  test(
    'resumes a partially uploaded file after restarting the local server',
    () async {
      final bytes = List<int>.generate(350000, (index) => (index * 7) % 256);
      final transfer = await createTransfer(
        'resume.dat',
        bytes,
        clientId: 'resume-case',
      );
      final id = transfer['transferId'] as String;
      final firstChunk = bytes.sublist(0, 120000);
      final first = await send(
        'PUT',
        '/api/v1/transfers/$id',
        bytes: firstChunk,
        headers: {
          'Content-Range': 'bytes 0-${firstChunk.length - 1}/${bytes.length}',
        },
      );
      expect(first.status, HttpStatus.ok);

      await server.stop();
      await server.start();

      final resumed = await send('GET', '/api/v1/transfers/$id');
      expect(resumed.status, HttpStatus.ok);
      expect(
        (jsonDecode(resumed.body) as Map<String, dynamic>)['offset'],
        firstChunk.length,
      );

      final duplicateCreate = await send(
        'POST',
        '/api/v1/transfers',
        json: {
          'name': 'resume.dat',
          'size': bytes.length,
          'clientId': 'resume-case',
        },
      );
      expect(duplicateCreate.status, HttpStatus.ok);
      expect(
        (jsonDecode(duplicateCreate.body)
            as Map<String, dynamic>)['transferId'],
        id,
      );

      for (
        var start = firstChunk.length;
        start < bytes.length;
        start += 100000
      ) {
        final end = min(start + 100000, bytes.length) - 1;
        final result = await send(
          'PUT',
          '/api/v1/transfers/$id',
          bytes: bytes.sublist(start, end + 1),
          headers: {'Content-Range': 'bytes $start-$end/${bytes.length}'},
        );
        expect(result.status, HttpStatus.ok, reason: result.body);
      }

      final completed = await send('POST', '/api/v1/transfers/$id/complete');
      expect(completed.status, HttpStatus.ok);
      expect(
        (jsonDecode(completed.body) as Map<String, dynamic>)['sha256'],
        sha256.convert(bytes).toString(),
      );
    },
  );

  test(
    'rejects an incorrect offset and supports explicit cancellation',
    () async {
      final bytes = List<int>.filled(4096, 5);
      final transfer = await createTransfer('cancel.bin', bytes);
      final id = transfer['transferId'] as String;
      final wrongOffset = await send(
        'PUT',
        '/api/v1/transfers/$id',
        bytes: bytes.sublist(100, 200),
        headers: {'Content-Range': 'bytes 100-199/${bytes.length}'},
      );
      expect(wrongOffset.status, HttpStatus.conflict);

      final cancelled = await send('DELETE', '/api/v1/transfers/$id');
      expect(cancelled.status, HttpStatus.ok);
      final status = await send('GET', '/api/v1/transfers/$id');
      expect(status.status, HttpStatus.notFound);
    },
  );

  test('accepts independent concurrent transfers', () async {
    final payloads = [
      List<int>.generate(160000, (index) => index % 197),
      List<int>.generate(190000, (index) => index % 223),
    ];
    final transfers = await Future.wait([
      createTransfer('parallel-a.bin', payloads[0]),
      createTransfer('parallel-b.bin', payloads[1]),
    ]);
    await Future.wait([
      writeChunks(transfers[0]['transferId'] as String, payloads[0]),
      writeChunks(transfers[1]['transferId'] as String, payloads[1]),
    ]);
    final completions = await Future.wait([
      send('POST', '/api/v1/transfers/${transfers[0]['transferId']}/complete'),
      send('POST', '/api/v1/transfers/${transfers[1]['transferId']}/complete'),
    ]);
    expect(
      completions.map((result) => result.status),
      everyElement(HttpStatus.ok),
    );
    final listed = await send('GET', '/api/files');
    expect(
      (jsonDecode(listed.body) as Map<String, dynamic>)['files'],
      hasLength(2),
    );
  });
}

class _Result {
  const _Result(this.status, this.bytes, this.headers);

  final int status;
  final List<int> bytes;
  final HttpHeaders headers;
  String get body => utf8.decode(bytes, allowMalformed: true);
}

class _RealHttpOverrides extends HttpOverrides {}
