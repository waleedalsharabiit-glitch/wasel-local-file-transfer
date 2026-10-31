import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/transfer_server.dart';

class TransferCenter extends StatefulWidget {
  const TransferCenter({
    super.key,
    required this.connectionMode,
    this.isEnglish = false,
  });

  final bool connectionMode;
  final bool isEnglish;

  @override
  State<TransferCenter> createState() => _TransferCenterState();
}

class _TransferCenterState extends State<TransferCenter> {
  final TransferServer _server = TransferServer.instance;
  final TextEditingController _search = TextEditingController();
  bool _busy = false;
  String _kind = 'all';
  String _sort = 'name';

  String t(String ar, String en) => widget.isEnglish ? en : ar;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _size(Object? value) {
    final bytes = (value as num?)?.toInt() ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _extension(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool _image(String name) => const {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  }.contains(_extension(name));
  bool _video(String name) =>
      const {'mp4', 'mov', 'mkv', 'webm', 'avi'}.contains(_extension(name));
  bool _document(String name) => const {
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
  }.contains(_extension(name));
  bool _textFile(String name) => const {
    'txt',
    'md',
    'csv',
    'json',
    'xml',
    'yaml',
    'yml',
    'log',
  }.contains(_extension(name));

  IconData _fileIcon(String name) {
    if (_image(name)) return Icons.image_rounded;
    if (_video(name)) return Icons.movie_rounded;
    if (_document(name)) {
      return _extension(name) == 'pdf'
          ? Icons.picture_as_pdf_rounded
          : Icons.description_rounded;
    }
    if (const {'mp3', 'wav', 'm4a', 'aac', 'flac'}.contains(_extension(name))) {
      return Icons.audio_file_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await _server.start();
      if (mounted) {
        _message(
          t(
            'بدأت جلسة الاستقبال. افتح رابط الجلسة من واجهة الكمبيوتر.',
            'Receiving session started. Open the session link in the desktop interface.',
          ),
        );
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    await _server.stop();
    if (mounted) {
      _message(t('تم إيقاف جلسة النقل.', 'Transfer session stopped.'));
    }
  }

  Future<void> _pickFiles() async {
    setState(() => _busy = true);
    try {
      final count = await _server.pickFilesFromPhone();
      if (mounted) {
        _message(
          t(
            'أُضيف $count ملف إلى مساحة واصل.',
            '$count file(s) added to Wasel.',
          ),
        );
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _message(t('تم نسخ $label.', '$label copied.'));
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  void _preview(Map<String, Object?> item) {
    final name = item['name'] as String? ?? '';
    final file = _server.localFile(name);
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: _previewContent(file, name),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(_fileIcon(name), color: const Color(0xFF0284C7)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${_size(item['size'])} · ${_extension(name).toUpperCase()}',
                      ),
                    ),
                    IconButton(
                      tooltip: t('نسخ البصمة', 'Copy checksum'),
                      onPressed: () =>
                          _copy(item['sha256'] as String? ?? '', 'SHA-256'),
                      icon: const Icon(Icons.fingerprint_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewContent(File file, String name) {
    if (_image(name)) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _previewFallback(name),
      );
    }
    if (!_textFile(name)) return _previewFallback(name);

    return FutureBuilder<String>(
      future: file.openRead(0, 256 * 1024).transform(utf8.decoder).join(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _previewFallback(name);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            snapshot.data!.isEmpty
                ? t('الملف النصي فارغ.', 'This text file is empty.')
                : snapshot.data!,
            textDirection: Directionality.of(context),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
            ),
          ),
        );
      },
    );
  }

  Widget _previewFallback(String name) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_fileIcon(name), size: 58, color: const Color(0xFF0284C7)),
        const SizedBox(height: 12),
        Text(
          _video(name)
              ? t('معاينة الفيديو قيد الإعداد', 'Video preview is coming soon')
              : t(
                  'معاينة هذا النوع غير متاحة بعد',
                  'Preview is not available for this file type',
                ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _server,
      builder: (context, _) {
        final running = _server.isRunning;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _heading(
            widget.connectionMode
                ? t('الأجهزة والاتصال', 'Devices & connection')
                : t('لوحة النقل', 'Transfer dashboard'),
              widget.connectionMode
                  ? t(
                      'أنشئ جلسة محلية آمنة، ثم افتحها من متصفح الكمبيوتر.',
                      'Start a local session, then open it in your computer browser.',
                    )
                : t(
                    'تابع نشاط الجلسة، ثم ابحث في مكتبة الهاتف وعاين الملفات.',
                    'Review session activity, then search and preview files in your phone library.',
                  ),
            ),
            const SizedBox(height: 18),
            if (widget.connectionMode) _connectionCard(running),
            if (!widget.connectionMode) ...[
            _transferOverview(),
            const SizedBox(height: 17),
              _filesToolbar(),
              const SizedBox(height: 13),
              _filesCard(),
            ],
          ],
        );
      },
    );
  }

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 7),
      Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.55,
        ),
      ),
    ],
  );

  Widget _transferOverview() {
    final received = _server.activity
        .where((event) => event['action'] == 'received')
        .length;
    final added = _server.activity
        .where((event) => event['action'] == 'added')
        .length;
    final deleted = _server.activity
        .where((event) => event['action'] == 'deleted')
        .length;
    return Row(
      children: [
        Expanded(
          child: _overviewStat(
            Icons.call_received_rounded,
            '$received',
            t('مستلمة', 'Received'),
            const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _overviewStat(
            Icons.upload_rounded,
            '$added',
            t('مضافة', 'Added'),
            const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _overviewStat(
            Icons.delete_outline_rounded,
            '$deleted',
            t('محذوفة', 'Deleted'),
            const Color(0xFFDB2777),
          ),
        ),
      ],
    );
  }

  Widget _overviewStat(IconData icon, String value, String label, Color color) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 9),
              Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );

  Widget _connectionCard(bool running) {
    final color = running ? const Color(0xFF16A34A) : const Color(0xFF0284C7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        running
                            ? Icons.wifi_tethering_rounded
                            : Icons.wifi_rounded,
                        color: color,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            running
                                ? t('الجلسة جاهزة', 'Session is ready')
                                : t('لا توجد جلسة نشطة', 'No active session'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            running
                                ? t(
                                    'الكمبيوتر متصل بالشبكة ويمكنه البدء.',
                                    'Your computer can connect over the local network.',
                                  )
                                : t(
                                    'ابدأ الاستقبال لإظهار عنوان هذا الهاتف.',
                                    'Start receiving to show this phone’s address.',
                                  ),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      running
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (!running)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(t('بدء الاستقبال', 'Start receiving')),
                    ),
                  )
                else ...[
                  _detailRow(
                    t('رابط الجلسة', 'Session link'),
                    _server.url ?? '',
                    Icons.link_rounded,
                  ),
                  const SizedBox(height: 9),
                  _detailRow(
                    t('رمز الوصول', 'Access code'),
                    _server.token ?? '',
                    Icons.key_rounded,
                  ),
                  const SizedBox(height: 13),
                  _qrCard(),
                  const SizedBox(height: 13),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: Text(t('إيقاف الجلسة', 'Stop session')),
                    ),
                  ),
                ],
                if (_server.lastError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _server.lastError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 13),
        _networkTips(),
        const SizedBox(height: 19),
        _filesToolbar(),
        const SizedBox(height: 13),
        _filesCard(),
      ],
    );
  }

  Widget _qrCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.link_rounded,
            size: 37,
            color: Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t(
              'انسخ رابط الجلسة أو عنوان الهاتف إلى واجهة الكمبيوتر.',
              'Copy the session link or phone address into the desktop interface.',
            ),
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _networkTips() => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('قبل الاتصال', 'Before connecting'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _tip(
            Icons.wifi_rounded,
            t(
              'الهاتف والكمبيوتر على شبكة Wi-Fi نفسها.',
              'Keep the phone and computer on the same Wi-Fi network.',
            ),
          ),
          _tip(
            Icons.wifi_tethering_rounded,
            t(
              'أو اتصل بنقطة اتصال الهاتف من الكمبيوتر.',
              'Or connect the computer to the phone’s hotspot.',
            ),
          ),
          _tip(
            Icons.lock_outline_rounded,
            t(
              'أوقف الجلسة عند الانتهاء؛ رمز الوصول خاص بهذه الجلسة.',
              'Stop the session when finished; its access code is temporary.',
            ),
          ),
        ],
      ),
    ),
  );
  Widget _tip(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF0284C7)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _detailRow(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: t('نسخ', 'Copy'),
              onPressed: value.isEmpty ? null : () => _copy(value, label),
              icon: const Icon(Icons.copy_rounded, size: 17),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _filesToolbar() {
    final files = _visibleFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t('ملفات الهاتف', 'Phone files'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${files.length}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: t('ترتيب', 'Sort'),
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'name', child: Text(t('الاسم', 'Name'))),
                PopupMenuItem(value: 'size', child: Text(t('الحجم', 'Size'))),
              ],
              icon: const Icon(Icons.sort_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: t('ابحث باسم الملف…', 'Search files…'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _search.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 9),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in [
                ('all', t('الكل', 'All')),
                ('image', t('صور', 'Images')),
                ('document', t('مستندات', 'Documents')),
                ('video', t('فيديو', 'Video')),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 7),
                  child: ChoiceChip(
                    label: Text(entry.$2),
                    selected: _kind == entry.$1,
                    onSelected: (_) => setState(() => _kind = entry.$1),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, Object?>> get _visibleFiles {
    final query = _search.text.trim().toLowerCase();
    final result = _server.files.where((file) {
      final name = file['name'] as String? ?? '';
      if (query.isNotEmpty && !name.toLowerCase().contains(query)) return false;
      return switch (_kind) {
        'image' => _image(name),
        'document' => _document(name),
        'video' => _video(name),
        _ => true,
      };
    }).toList();
    result.sort(
      (a, b) => _sort == 'size'
          ? ((b['size'] as num?) ?? 0).compareTo((a['size'] as num?) ?? 0)
          : (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
    );
    return result;
  }

  Widget _filesCard() {
    final files = _visibleFiles;
    final running = _server.isRunning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('مكتبة الملفات', 'File library'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${files.length} ${t('عنصر', 'items')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t(
                'أضف ملفات من جهازك لتصبح متاحة للكمبيوتر.',
                'Add files from your phone to make them available to your computer.',
              ),
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: !running || _busy ? null : _pickFiles,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  _busy
                      ? t('جارٍ تجهيز الملفات…', 'Preparing files…')
                      : t('إضافة من الهاتف', 'Add from phone'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (files.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 27),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        _search.text.isNotEmpty || _kind != 'all'
                            ? Icons.search_off_rounded
                            : Icons.folder_open_rounded,
                        size: 35,
                        color: Theme.of(context).colorScheme.onSurfaceVariant
                            .withValues(alpha: .55),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _server.files.isEmpty
                            ? t('مكتبتك فارغة', 'Your library is empty')
                            : t('لا توجد نتائج مطابقة', 'No matching files'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _server.files.isEmpty
                            ? t(
                                'اختر ملفات لبدء مكتبتك المحلية.',
                                'Choose files to start your local library.',
                              )
                            : t(
                                'غيّر البحث أو نوع الملف.',
                                'Change your search or file type.',
                              ),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...files.map(_fileTile),
          ],
        ),
      ),
    );
  }

  Widget _fileTile(Map<String, Object?> item) {
    final name = item['name'] as String? ?? t('ملف غير معروف', 'Unknown file');
    final hash = item['sha256'] as String? ?? '';
    final color = _image(name)
        ? const Color(0xFF7C3AED)
        : _document(name)
        ? const Color(0xFF0284C7)
        : _video(name)
        ? const Color(0xFFDB2777)
        : const Color(0xFF16A34A);
    return InkWell(
      onTap: () => _preview(item),
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_fileIcon(name), color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_size(item['size'])} · SHA-256 ${hash.length > 12 ? hash.substring(0, 12) : hash}…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: t('معاينة', 'Preview'),
              onPressed: () => _preview(item),
              icon: const Icon(Icons.visibility_outlined, size: 20),
            ),
            IconButton(
              tooltip: t('حذف', 'Delete'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(t('حذف الملف؟', 'Delete file?')),
                    content: Text(
                      t(
                        'سيُحذف «$name» من مكتبة واصل.',
                        '“$name” will be removed from the Wasel library.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(t('إلغاء', 'Cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(t('حذف', 'Delete')),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _server.deleteLocalFile(name);
                  if (mounted) _message(t('تم حذف الملف.', 'File deleted.'));
                }
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
