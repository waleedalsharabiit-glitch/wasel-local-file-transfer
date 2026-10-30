import 'package:flutter/material.dart';

void main() {
  runApp(const WaselApp());
}

class WaselApp extends StatefulWidget {
  const WaselApp({super.key});

  @override
  State<WaselApp> createState() => _WaselAppState();
}

class _WaselAppState extends State<WaselApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  void _toggleLanguage() {
    setState(() {
      _locale = _locale.languageCode == 'ar'
          ? const Locale('en')
          : const Locale('ar');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wasel | واصل',
      locale: _locale,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: WaselHome(
        isEnglish: _locale.languageCode == 'en',
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
        onToggleLanguage: _toggleLanguage,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0284C7),
      brightness: brightness,
      surface: dark ? const Color(0xFF101923) : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF0B1220)
          : const Color(0xFFF4F8FC),
      appBarTheme: AppBarTheme(
        backgroundColor: dark
            ? const Color(0xFF0B1220)
            : const Color(0xFFF4F8FC),
        foregroundColor: dark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF111D2B) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: dark ? const Color(0xFF263548) : const Color(0xFFE4ECF4),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF172333) : const Color(0xFFF1F6FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
    );
  }
}

class WaselHome extends StatefulWidget {
  const WaselHome({
    super.key,
    required this.isEnglish,
    required this.isDark,
    required this.onToggleTheme,
    required this.onToggleLanguage,
  });

  final bool isEnglish;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleLanguage;

  @override
  State<WaselHome> createState() => _WaselHomeState();
}

class _WaselHomeState extends State<WaselHome> {
  int _selectedIndex = 0;

  String t(String ar, String en) => widget.isEnglish ? en : ar;

  void _showInfo(String ar, String en) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(ar, en)), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildDevices(),
      _buildTransfers(),
      _buildHistory(),
      _buildSettings(),
    ];

    return Directionality(
      textDirection: widget.isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wasel',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
                  ),
                  Text(
                    t('واصل • نقل محلي آمن', 'Wasel • Local file transfer'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: t('تغيير المظهر', 'Toggle theme'),
              onPressed: widget.onToggleTheme,
              icon: Icon(
                widget.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: SingleChildScrollView(
              key: ValueKey(_selectedIndex),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              child: pages[_selectedIndex],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: t('الرئيسية', 'Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.devices_outlined),
              selectedIcon: const Icon(Icons.devices_rounded),
              label: t('الأجهزة', 'Devices'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.swap_horiz_rounded),
              selectedIcon: const Icon(Icons.sync_alt_rounded),
              label: t('النقل', 'Transfer'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_rounded),
              label: t('السجل', 'History'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: t('الإعدادات', 'Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF38BDF8)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t(
                        'نقل محلي بين أجهزتك',
                        'Local transfer between devices',
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t('ملفاتك،\\nتصل بسهولة.', 'Your files,\\nwithin easy reach.'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                t(
                  'جهّز الاتصال بين الهاتف والكمبيوتر لنقل ملفاتك عبر الشبكة المحلية.',
                  'Prepare a local connection between your phone and computer.',
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0369A1),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => setState(() => _selectedIndex = 1),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(
                    t('إعداد اتصال جديد', 'Set up a connection'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _sectionTitle(t('نظرة عامة', 'Overview')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.devices_rounded,
                title: t('الأجهزة', 'Devices'),
                value: '0',
                subtitle: t('لا توجد أجهزة مقترنة', 'No paired devices'),
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.swap_vert_rounded,
                title: t('عمليات النقل', 'Transfers'),
                value: '0',
                subtitle: t('لم تبدأ عمليات بعد', 'No transfers yet'),
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _sectionTitle(t('الوصول السريع', 'Quick access')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.upload_file_rounded,
                title: t('إرسال ملفات', 'Send files'),
                subtitle: t('من الهاتف', 'From phone'),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickAction(
                icon: Icons.folder_open_rounded,
                title: t('استقبال ملفات', 'Receive files'),
                subtitle: t('من الكمبيوتر', 'From computer'),
                onTap: () => setState(() => _selectedIndex = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0284C7),
                  size: 23,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('جاهز للإعداد', 'Ready to configure'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        t(
                          'هذه واجهة المرحلة الثانية. لم يبدأ خادم النقل المحلي بعد.',
                          'This is the phase-two interface. The local transfer server is not implemented yet.',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.6,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          t('الأجهزة والاتصال', 'Devices & connection'),
          t(
            'إدارة اتصال الهاتف بالكمبيوتر.',
            'Connect your phone and computer.',
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.wifi_tethering_rounded,
                    size: 39,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  t('لا يوجد اتصال نشط', 'No active connection'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'يجب أن يكون الهاتف والكمبيوتر على شبكة Wi-Fi نفسها أو على نقطة اتصال الهاتف.',
                    'The phone and computer must use the same Wi-Fi network or phone hotspot.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _showInfo(
                      'سيتم تشغيل خادم النقل المحلي في المرحلة الثالثة.',
                      'The local transfer server will be implemented in phase three.',
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(t('بدء الاستقبال', 'Start receiving')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(t('الأجهزة الموثوقة', 'Trusted devices')),
        const SizedBox(height: 12),
        _emptyCard(
          Icons.devices_other_rounded,
          t('لا توجد أجهزة موثوقة', 'No trusted devices'),
          t(
            'ستظهر الأجهزة بعد الإقران والموافقة.',
            'Devices appear after pairing and approval.',
          ),
        ),
      ],
    );
  }

  Widget _buildTransfers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          t('عمليات النقل', 'Transfers'),
          t(
            'تابع الملفات المرسلة والمستقبلة.',
            'Track sent and received files.',
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.file_upload_outlined,
                title: t('إرسال', 'Send'),
                subtitle: t('ملفات من الهاتف', 'Files from phone'),
                onTap: () => _showInfo(
                  'سيُربط اختيار الملفات بمحرك النقل في المرحلة الثالثة.',
                  'File selection will connect to the transfer engine in phase three.',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickAction(
                icon: Icons.file_download_outlined,
                title: t('استقبال', 'Receive'),
                subtitle: t('ملفات من الكمبيوتر', 'Files from computer'),
                onTap: () => _showInfo(
                  'سيعمل الاستقبال بعد تشغيل الخادم المحلي.',
                  'Receiving will be available when the local server is implemented.',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _emptyCard(
          Icons.swap_horiz_rounded,
          t('لا توجد عمليات نقل', 'No transfers yet'),
          t(
            'ستظهر هنا حالة النقل والسرعة والحجم والوقت المتبقي.',
            'Progress, speed, size, and remaining time will appear here.',
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          t('سجل العمليات', 'Transfer history'),
          t('الملفات والعمليات السابقة.', 'Previous files and operations.'),
        ),
        const SizedBox(height: 18),
        _emptyCard(
          Icons.history_rounded,
          t('السجل فارغ', 'History is empty'),
          t(
            'ستُسجل العمليات الفعلية بعد تنفيذ محرك النقل.',
            'Completed operations will appear after the transfer engine is implemented.',
          ),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          t('الإعدادات والخصوصية', 'Settings & privacy'),
          t('خصّص تجربة واصل.', 'Customize your Wasel experience.'),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(t('لغة التطبيق', 'App language')),
                subtitle: Text(widget.isEnglish ? 'English' : 'العربية'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onToggleLanguage,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(t('المظهر الداكن', 'Dark theme')),
                value: widget.isDark,
                onChanged: (_) => widget.onToggleTheme(),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(
                  t('الأمان والأجهزة الموثوقة', 'Security & trusted devices'),
                ),
                subtitle: Text(
                  t('الإقران والصلاحيات', 'Pairing and permissions'),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showInfo(
                  'سيتم تنفيذ إعدادات الأمان في مرحلة الإقران.',
                  'Security controls will be implemented in the pairing phase.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(t('حول واصل', 'About Wasel')),
                subtitle: const Text('Wasel • 0.1.0'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF0284C7)),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(IconData icon, String title, String description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 42, color: const Color(0xFF38BDF8)),
              const SizedBox(height: 13),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
