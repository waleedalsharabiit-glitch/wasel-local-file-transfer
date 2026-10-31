import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareCenter extends StatefulWidget {
  const ShareCenter({super.key, required this.isEnglish});

  final bool isEnglish;

  @override
  State<ShareCenter> createState() => _ShareCenterState();
}

class _ShareCenterState extends State<ShareCenter> {
  final TextEditingController _draft = TextEditingController();
  String? _clipboardText;
  int _selected = 0;

  String t(String ar, String en) => widget.isEnglish ? en : ar;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _readClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted) setState(() => _clipboardText = data?.text ?? '');
  }

  Future<void> _copyDraft() async {
    if (_draft.text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _draft.text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('تم نسخ النص إلى الحافظة.', 'Text copied to clipboard.'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('مشاركة محلية', 'Local sharing'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          t(
            'مساحة جاهزة للرسائل والروابط ومحتوى الحافظة بين أجهزتك.',
            'A workspace for messages, links, and clipboard sharing between your devices.',
          ),
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.55),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              for (var index = 0; index < 2; index++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _selected == index
                            ? colors.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _selected == index
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .06),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          index == 0
                              ? t('محادثة', 'Chat')
                              : t('الحافظة', 'Clipboard'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _selected == index
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_selected == 0) _chatView(colors) else _clipboardView(colors),
        const SizedBox(height: 13),
        _phaseNote(colors),
      ],
    );
  }

  Widget _chatView(ColorScheme colors) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('محادثة الأجهزة', 'Device chat'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t(
                        'محادثة مشفرة محليًا بعد الإقران',
                        'Local conversation after pairing',
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            height: 205,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: colors.primary,
                        size: 27,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t(
                        'ابدأ محادثة مع جهازك',
                        'Start a conversation with your device',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      t(
                        'ستظهر الرسائل هنا بعد ربط جهاز موثوق.',
                        'Messages will appear here after a trusted device is connected.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _draft,
            onChanged: (_) => setState(() {}),
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: t('اكتب رسالة أو رابطًا…', 'Write a message or link…'),
              prefixIcon: const Icon(Icons.edit_outlined),
              suffixIcon: IconButton(
                tooltip: t('نسخ المسودة', 'Copy draft'),
                onPressed: _copyDraft,
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _draft.text.trim().isEmpty ? null : _copyDraft,
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                  label: Text(t('نسخ النص', 'Copy text')),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(t('إرسال', 'Send')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _clipboardView(ColorScheme colors) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.content_paste_rounded,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('الحافظة المشتركة', 'Shared clipboard'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t(
                        'اختر بنفسك متى تقرأ محتواها',
                        'Choose when to read its contents',
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(15),
            ),
            child: _clipboardText == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.content_paste_search_rounded,
                        size: 34,
                        color: colors.onSurfaceVariant.withValues(alpha: .65),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        t('لم تتم قراءة الحافظة', 'Clipboard not read'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(
                          'اضغط قراءة لمعاينة النص الموجود على هذا الهاتف.',
                          'Tap read to preview text currently on this phone.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _clipboardText!.isEmpty
                        ? t(
                            'الحافظة فارغة أو لا تحتوي نصًا.',
                            'Clipboard is empty or has no text.',
                          )
                        : _clipboardText!,
                    style: const TextStyle(height: 1.6),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _readClipboard,
              icon: const Icon(Icons.visibility_outlined),
              label: Text(
                t(
                  'قراءة الحافظة على هذا الهاتف',
                  'Read this phone’s clipboard',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _phaseNote(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: colors.primaryContainer.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: colors.primary, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t(
              'هذه واجهات وتجربة الحافظة المحلية على الهاتف. إرسال الرسائل ومزامنة الحافظة عبر الشبكة سيفعّلان بعد تنفيذ قناة التواصل في المرحلة 07.',
              'These screens preview local chat and clipboard flows. Network messaging and clipboard sync will be enabled with the communication service in phase 07.',
            ),
            style: TextStyle(
              fontSize: 11,
              height: 1.55,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
