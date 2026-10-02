import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/strings.dart';
import 'store/app_state.dart';
import 'ui/calendar_screen.dart';
import 'ui/growth_screen.dart';
import 'ui/inbox_screen.dart';
import 'ui/more_screen.dart';
import 'ui/today_screen.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  state.load();
  runApp(ChangeNotifierProvider.value(value: state, child: const SchoolSiftApp()));
}

class SchoolSiftApp extends StatelessWidget {
  const SchoolSiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().language;
    return MaterialApp(
      onGenerateTitle: (c) => S.of(c).appName,
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Shell(),
    );
  }
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E6BE6),
    brightness: b,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'NotoSansSC',
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF5F7FB) : null,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: b == Brightness.light ? Colors.white : scheme.surfaceContainer,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: b == Brightness.light ? const Color(0xFFF5F7FB) : null,
      scrolledUnderElevation: 0,
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  bool welcomeShown = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<AppState>();
    if (!st.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (st.children.isEmpty && !welcomeShown) {
      welcomeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _welcome(context));
    }
    final pages = [
      TodayScreen(onGo: (i) => setState(() => index = i)),
      const InboxScreen(),
      const CalendarScreen(),
      const GrowthScreen(),
      const MoreScreen(),
    ];
    final dests = [
      (Icons.wb_sunny_outlined, Icons.wb_sunny, s.tabToday),
      (Icons.inbox_outlined, Icons.inbox, s.tabInbox),
      (Icons.calendar_month_outlined, Icons.calendar_month, s.tabCalendar),
      (Icons.insights_outlined, Icons.insights, s.tabGrowth),
      (Icons.more_horiz, Icons.more_horiz, s.tabMore),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final body = IndexedStack(index: index, children: pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: AppLogo(size: 40),
            ),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: body))),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          for (final d in dests) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }

  Future<void> _welcome(BuildContext context) async {
    final s = S.read(context);
    final st = context.read<AppState>();
    final r = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Row(children: [const AppLogo(size: 32), const SizedBox(width: 10), Expanded(child: Text(s.welcomeTitle))]),
        content: Text(s.welcomeBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'child'), child: Text(s.startFresh)),
          FilledButton(onPressed: () => Navigator.pop(c, 'demo'), child: Text(s.loadDemo)),
        ],
      ),
    );
    if (!context.mounted) return;
    if (r == 'demo') {
      st.loadDemo();
    } else {
      setState(() => index = 4);
      await showChildEditor(context);
    }
  }
}
