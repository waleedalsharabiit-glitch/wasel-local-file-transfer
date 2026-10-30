import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TransferServer extends ChangeNotifier {
  TransferServer._();

  static final TransferServer instance = TransferServer._();

  HttpServer? _server;
  Directory? _directory;

  String? _token;
  String? _url;
  String? _address;
  int? _port;

  bool get isRunning => _server != null;
  String? get token => _token;
  String? get url => _url;
  String? get address => _address;
  int? get port => _port;

  List<Map<String, Object?>> files = [];

  String? lastError;

  Future<void> start() async {
    if (isRunning) return;

    lastError = null;

    try {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}/WaselTransfers');

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      _directory = directory;

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

      final selectedAddress = addresses.first.address;

      final random = Random.secure();
      final tokenBytes = List<int>.generate(24, (_) => random.nextInt(256));
      final token = tokenBytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();

      final server = await HttpServer.bind(
        InternetAddress.anyIPv4,
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

    try {
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

      response.statusCode = HttpStatus.notFound;
      response.write('Not found');
      await response.close();
    } catch (error) {
      if (!response.headersSent) {
        response.statusCode = HttpStatus.internalServerError;
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({'error': error.toString()}));
        await response.close();
      } else {
        await response.close();
      }
    }
  }

  Future<void> _sendJson(
    HttpResponse response,
    Map<String, Object?> data,
  ) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
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
      // Stream the incoming body to disk; do not load the entire file
      // into memory.
      await request.pipe(temporary.openWrite());

      final digest = await sha256.bind(temporary.openRead()).first;
      final savedFile = await temporary.rename(destination.path);

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

    request.response.headers.contentType = ContentType.binary;
    request.response.headers.set(
      HttpHeaders.contentDispositionHeader,
      "attachment; filename*=UTF-8''${Uri.encodeComponent(safeName)}",
    );
    request.response.headers.contentLength = await file.length();

    await file.openRead().pipe(request.response);
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

    await file.delete();
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

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return 0;

    var copied = 0;

    for (final picked in result.files) {
      final sourcePath = picked.path;
      if (sourcePath == null) continue;

      final source = File(sourcePath);
      if (!await source.exists()) continue;

      final destination = await _uniqueDestination(picked.name);
      await source.copy(destination.path);
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
      await file.delete();
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
   details.textContent=formatSize(f.size)+' · SHA-256: '+f.sha256;
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
   message('Uploaded '+result.name+' · SHA-256 verified');
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
