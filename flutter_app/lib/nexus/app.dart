import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../data/nexus_repository.dart';
import '../screens/login_screen.dart';
import 'design.dart';
import 'store.dart';
import 'screens.dart';

class NexusApp extends StatefulWidget {
  const NexusApp({super.key, this.store, this.config});
  final NexusStore? store;
  final SupabaseConfig? config;
  @override
  State<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends State<NexusApp> {
  late final NexusStore? _store;
  @override
  void initState() {
    super.initState();
    _store =
        widget.store ??
        (widget.config?.isConfigured != true
            ? null
            : NexusStore(
                repository: NexusRepository(Supabase.instance.client),
              ));
  }

  @override
  void dispose() {
    if (widget.store == null) _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null) {
      return MaterialApp(
        title: 'NEXUS',
        theme: ThemeData(scaffoldBackgroundColor: N.canvas, useMaterial3: true),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY para iniciar o NEXUS.',
              ),
            ),
          ),
        ),
      );
    }
    return NexusScope(
      store: store,
      child: MaterialApp(
        title: 'NEXUS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: N.canvas,
          colorScheme: ColorScheme.fromSeed(seedColor: N.wine),
          fontFamily: 'Roboto',
          textTheme: const TextTheme(bodyMedium: TextStyle(color: N.ink)),
          dividerColor: N.line,
        ),
        builder: (context, child) => AnimatedBuilder(
          animation: store,
          builder: (context, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: store.reduceMotion),
            child: child!,
          ),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session == null) return const LoginScreen();
        return NexusShell(onLogout: () => auth.signOut());
      },
    );
  }
}

class NexusShell extends StatefulWidget {
  const NexusShell({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<NexusShell> createState() => _NexusShellState();
}

class _NexusShellState extends State<NexusShell> {
  int index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NexusScope.of(context).refreshFromDatabase();
    });
  }

  static const labels = [
    'Início',
    'Espaços',
    'Dispositivos',
    'Alertas',
    'Perfil',
  ];
  static const icons = [
    Icons.home_outlined,
    Icons.grid_view_rounded,
    Icons.sensors_rounded,
    Icons.notifications_outlined,
    Icons.person_outline_rounded,
  ];
  void select(int value) => setState(() => index = value);
  Widget destination(int i, NexusStore store) => Expanded(
    child: Tooltip(
      message: labels[i],
      child: Semantics(
        label: labels[i],
        button: true,
        selected: index == i,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => select(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 230),
            height: 53,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == i ? N.wine : Colors.transparent,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icons[i],
                  color: index == i ? Colors.white : N.muted,
                  size: 23,
                ),
                if (i == 3 && store.activeAlerts > 0)
                  Positioned(
                    top: 7,
                    right: 10,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: N.peach,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final store = NexusScope.of(context);
    final pages = [
      HomePage(onTab: select),
      const SpacesPage(),
      const DevicesPage(),
      const AlertsPage(),
      ProfilePage(onLogout: widget.onLogout),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final content = AnimatedSwitcher(
      layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
      duration: Duration(milliseconds: store.reduceMotion ? 0 : 260),
      child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
    );
    final nav = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(44),
        boxShadow: [
          BoxShadow(
            color: N.wine.withValues(alpha: .12),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [for (var i = 0; i < 5; i++) destination(i, store)],
        ),
      ),
    );
    final sidebar = Container(
      width: 220,
      padding: const EdgeInsets.all(22),
      color: Colors.white,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            const Brand(),
            const SizedBox(height: 42),
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  selected: index == i,
                  selectedTileColor: N.canvas,
                  leading: Icon(icons[i]),
                  title: Text(labels[i]),
                  onTap: () => select(i),
                ),
              ),
            const Spacer(),
            const Text(
              'HOTEL INTELLIGENCE',
              style: TextStyle(fontSize: 10, letterSpacing: 2, color: N.muted),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  sidebar,
                  Expanded(child: content),
                ],
              )
            : Stack(
                children: [
                  Positioned.fill(child: content),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 14,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: nav,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/brand/nexus_logo.png',
          width: 38,
          height: 38,
        ),
      ),
      const SizedBox(width: 11),
      Text(
        'NEXUS',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 3,
          color: dark ? Colors.white : N.wine,
        ),
      ),
    ],
  );
}
