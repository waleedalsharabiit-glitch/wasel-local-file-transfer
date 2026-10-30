import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/transfer_server.dart';

class TransferCenter extends StatefulWidget {
  const TransferCenter({super.key, required this.connectionMode});

  final bool connectionMode;

  @override
  State<TransferCenter> createState() => _TransferCenterState();
}

class _TransferCenterState extends State<TransferCenter> {
  final TransferServer _server = TransferServer.instance;
  bool _busy = false;

  String _size(Object? value) {
    final bytes = (value as num?)?.toInt() ?? 0;

    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _start() async {
    setState(() => _busy = true);

    try {
      await _server.start();
      if (!mounted) return;
      _message('Local transfer server started.');
    } catch (error) {
      if (!mounted) return;
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    await _server.stop();
    if (mounted) _message('Transfer server stopped.');
  }

  Future<void> _pickFiles() async {
    setState(() => _busy = true);

    try {
      final count = await _server.pickFilesFromPhone();
      if (!mounted) return;
      _message('$count file(s) added to Wasel.');
    } catch (error) {
      if (!mounted) return;
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _message('$label copied.');
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _server,
      builder: (context, _) {
        final running = _server.isRunning;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.connectionMode ? 'Devices & connection' : 'File transfer',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              widget.connectionMode
                  ? 'Connect your phone and computer through the same local network.'
                  : 'Manage files sent from your computer and files you want to send.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            _connectionCard(running),
            if (!widget.connectionMode) ...[
              const SizedBox(height: 18),
              _filesCard(),
            ],
          ],
        );
      },
    );
  }

  Widget _connectionCard(bool running) {
    final color = running ? Colors.green : const Color(0xFF0284C7);

    return Card(
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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    running ? Icons.wifi_tethering_rounded : Icons.wifi_rounded,
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
                        running ? 'Server is running' : 'No active connection',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        running
                            ? 'Your computer can connect now.'
                            : 'Start a local session to receive files.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  running ? Icons.check_circle : Icons.circle_outlined,
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
                  label: const Text('Start receiving'),
                ),
              )
            else ...[
              _detailRow(
                'Computer address',
                _server.url ?? '',
                Icons.link_rounded,
              ),
              const SizedBox(height: 10),
              _detailRow(
                'Session access code',
                _server.token ?? '',
                Icons.key_rounded,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF0369A1)),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Open the address on a computer connected to the same Wi-Fi network. Keep this session code private.',
                        style: TextStyle(
                          color: Color(0xFF075985),
                          height: 1.5,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop transfer server'),
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
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy',
                onPressed: value.isEmpty ? null : () => _copy(value, label),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filesCard() {
    final files = _server.files;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Phone files',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                Text('${files.length}'),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'Choose files from your phone to make them available for download on your computer.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !_server.isRunning || _busy ? null : _pickFiles,
                icon: const Icon(Icons.add_to_drive_rounded),
                label: const Text('Add files from phone'),
              ),
            ),
            const SizedBox(height: 12),
            if (files.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No files available yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...files.map((file) {
                final name = file['name'] as String? ?? 'Unknown file';
                final hash = file['sha256'] as String? ?? '';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.insert_drive_file_outlined,
                    color: Color(0xFF0284C7),
                  ),
                  title: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_size(file['size'])}\nSHA-256: ${hash.length > 16 ? hash.substring(0, 16) : hash}…',
                    maxLines: 2,
                    style: const TextStyle(fontSize: 10),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Delete file',
                    onPressed: () async {
                      await _server.deleteLocalFile(name);
                      if (mounted) _message('File deleted.');
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
