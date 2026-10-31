import 'package:flutter/material.dart';

import 'screens/transfer_center.dart';

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
      title: 'Wasel | ظˆط§طµظ„',
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
                    t(
                      'ظˆط§طµظ„ • ظ†ظ‚ظ„ ظ…ط­ظ„ي ط¢ظ…ظ†',
                      'Wasel • Local file transfer',
                    ),
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
              tooltip: t('طھط؛ظٹظٹط± ط§ظ„ظ…ط¸ظ‡ط±', 'Toggle theme'),
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
              label: t('ط§ظ„ط±ط¦ظٹط³ظٹط©', 'Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.devices_outlined),
              selectedIcon: const Icon(Icons.devices_rounded),
              label: t('ط§ظ„ط£ط¬ظ‡ط²ط©', 'Devices'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.swap_horiz_rounded),
              selectedIcon: const Icon(Icons.sync_alt_rounded),
              label: t('ط§ظ„ظ†ظ‚ظ„', 'Transfer'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_rounded),
              label: t('ط§ظ„ط³ط¬ظ„', 'History'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: t('ط§ظ„ط¥ط¹ط¯ط§ط¯ط§ت', 'Settings'),
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
                        'ظ†ظ‚ظ„ ظ…ط­ظ„ي ط¨ظٹظ† ط£ط¬ظ‡ط²طھظƒ',
                        'Local transfer between devices',
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t(
                  'ظ…ظ„ظپط§طھظƒطŒ\\nطھطµظ„ ط¨ط³ظ‡ظˆظ„ط©.',
                  'Your files,\\nwithin easy reach.',
                ),
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
                  'ط¬ظ‡ظ‘ط² ط§ظ„ط§طھطµط§ظ„ ط¨ظٹظ† ط§ظ„ظ‡ط§تف ظˆط§ظ„ظƒظ…ط¨ظٹظˆطھط± ظ„ظ†ظ‚ظ„ ظ…ظ„ظپط§طھظƒ ط¹ط¨ط± ط§ظ„ط´ط¨ظƒط© ط§ظ„ظ…ط­ظ„ظٹط©.',
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
                    t('ط¥ط¹ط¯ط§ط¯ ط§طھطµط§ظ„ ط¬ط¯ظٹط¯', 'Set up a connection'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _sectionTitle(t('ظ†ط¸ط±ط© ط¹ط§ظ…ط©', 'Overview')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.devices_rounded,
                title: t('ط§ظ„ط£ط¬ظ‡ط²ط©', 'Devices'),
                value: '0',
                subtitle: t(
                  'ظ„ط§ طھظˆط¬ط¯ ط£ط¬ظ‡ط²ط© ظ…ظ‚طھط±ظ†ط©',
                  'No paired devices',
                ),
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.swap_vert_rounded,
                title: t('ط¹ظ…ظ„ظٹط§ت ط§ظ„ظ†ظ‚ظ„', 'Transfers'),
                value: '0',
                subtitle: t(
                  'ظ„ظ… طھط¨ط¯ط£ ط¹ظ…ظ„ظٹط§ت ط¨ط¹ط¯',
                  'No transfers yet',
                ),
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _sectionTitle(t('ط§ظ„ظˆطµظˆظ„ ط§ظ„ط³ط±ظٹط¹', 'Quick access')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.upload_file_rounded,
                title: t('ط¥ط±ط³ط§ظ„ ظ…ظ„ظپط§ت', 'Send files'),
                subtitle: t('ظ…ظ† ط§ظ„ظ‡ط§تف', 'From phone'),
                onTap: () => setState(() => _selectedIndex = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickAction(
                icon: Icons.folder_open_rounded,
                title: t('ط§ط³طھظ‚ط¨ط§ظ„ ظ…ظ„ظپط§ت', 'Receive files'),
                subtitle: t('ظ…ظ† ط§ظ„ظƒظ…ط¨ظٹظˆطھط±', 'From computer'),
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
                        t('ط¬ط§ظ‡ط² ظ„ظ„ط¥ط¹ط¯ط§ط¯', 'Ready to configure'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        t(
                          'ظ‡ط°ظ‡ ظˆط§ط¬ظ‡ط© ط§ظ„ظ…ط±ط­ظ„ط© ط§ظ„ط«ط§ظ†ظٹط©. ظ„ظ… ظٹط¨ط¯ط£ ط®ط§ط¯ظ… ط§ظ„ظ†ظ‚ظ„ ط§ظ„ظ…ط­ظ„ي ط¨ط¹ط¯.',
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
    return const TransferCenter(connectionMode: true);
  }

  Widget _buildTransfers() {
    return const TransferCenter(connectionMode: false);
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeading(
          t('ط³ط¬ظ„ ط§ظ„ط¹ظ…ظ„ظٹط§ت', 'Transfer history'),
          t(
            'ط§ظ„ظ…ظ„ظپط§ت ظˆط§ظ„ط¹ظ…ظ„ظٹط§ت ط§ظ„ط³ط§ط¨ظ‚ط©.',
            'Previous files and operations.',
          ),
        ),
        const SizedBox(height: 18),
        _emptyCard(
          Icons.history_rounded,
          t('ط§ظ„ط³ط¬ظ„ ظپط§ط±غ', 'History is empty'),
          t(
            'ط³طھظڈط³ط¬ظ„ ط§ظ„ط¹ظ…ظ„ظٹط§ت ط§ظ„ظپط¹ظ„ظٹط© ط¨ط¹ط¯ طھظ†ظپظٹط° ظ…ط­ط±ظƒ ط§ظ„ظ†ظ‚ظ„.',
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
          t('ط§ظ„ط¥ط¹ط¯ط§ط¯ط§ت ظˆط§ظ„ط®طµظˆطµظٹط©', 'Settings & privacy'),
          t(
            'ط®طµظ‘طµ طھط¬ط±ط¨ط© ظˆط§طµظ„.',
            'Customize your Wasel experience.',
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(t('ظ„ط؛ط© ط§ظ„طھط·ط¨ظٹظ‚', 'App language')),
                subtitle: Text(widget.isEnglish ? 'English' : 'ط§ظ„ط¹ط±ط¨ظٹط©'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onToggleLanguage,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(t('ط§ظ„ظ…ط¸ظ‡ط± ط§ظ„ط¯ط§ظƒظ†', 'Dark theme')),
                value: widget.isDark,
                onChanged: (_) => widget.onToggleTheme(),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(
                  t(
                    'ط§ظ„ط£ظ…ط§ظ† ظˆط§ظ„ط£ط¬ظ‡ط²ط© ط§ظ„ظ…ظˆط«ظˆظ‚ط©',
                    'Security & trusted devices',
                  ),
                ),
                subtitle: Text(
                  t(
                    'ط§ظ„ط¥ظ‚ط±ط§ظ† ظˆط§ظ„طµظ„ط§ط­ظٹط§ت',
                    'Pairing and permissions',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showInfo(
                  'ط³ظٹطھظ… طھظ†ظپظٹط° ط¥ط¹ط¯ط§ط¯ط§ت ط§ظ„ط£ظ…ط§ظ† في ظ…ط±ط­ظ„ط© ط§ظ„ط¥ظ‚ط±ط§ظ†.',
                  'Security controls will be implemented in the pairing phase.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(t('ط­ظˆظ„ ظˆط§طµظ„', 'About Wasel')),
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
