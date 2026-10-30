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
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: store.reduceMotionListenable,
          child: child,
          builder: (context, reduceMotion, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
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
  int _previousIndex = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NexusScope.of(context).refreshFromDatabase();
    });
  }

  static const labels = ['Início', 'Espaços', 'Sensores', 'Alertas', 'Perfil'];
  static const icons = [
    Icons.home_outlined,
    Icons.grid_view_rounded,
    Icons.sensors_rounded,
    Icons.notifications_outlined,
    Icons.person_outline_rounded,
  ];
  void select(int value) {
    if (value == index) return;
    setState(() {
      _previousIndex = index;
      index = value;
    });
  }

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
            duration: Duration(milliseconds: store.reduceMotion ? 0 : 320),
            curve: Curves.easeOutBack,
            height: 58,
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: Duration(
                    milliseconds: store.reduceMotion ? 0 : 320,
                  ),
                  curve: Curves.easeOutBack,
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == i ? N.wine : Colors.transparent,
                  ),
                ),
                AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: store.reduceMotion ? 0 : 260,
                  ),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: index == i
                      ? Icon(
                          icons[i],
                          key: const ValueKey('selected'),
                          color: Colors.white,
                          size: 23,
                        )
                      : Icon(
                          icons[i],
                          key: const ValueKey('unselected'),
                          color: N.muted,
                          size: 23,
                        ),
                ),
                if (i == 3 && store.activeAlerts > 0)
                  Positioned(
                    top: 1,
                    right: 3,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 19,
                        minHeight: 19,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: N.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          store.activeAlerts > 9
                              ? '9+'
                              : '${store.activeAlerts}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
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
      duration: Duration(milliseconds: store.reduceMotion ? 0 : 420),
      reverseDuration: Duration(milliseconds: store.reduceMotion ? 0 : 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final key = child.key;
        final childIndex = key is ValueKey<int> ? key.value : index;
        final entering = childIndex == index;
        final movingForward = index > _previousIndex;
        final startX = entering
            ? (movingForward ? .16 : -.16)
            : (movingForward ? -.10 : .10);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(startX, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
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
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      color: Colors.white,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/brand/nexus_logo.png',
                width: 38,
                height: 38,
              ),
            ),
            const SizedBox(height: 32),
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Tooltip(
                  message: labels[i],
                  child: Semantics(
                    label: labels[i],
                    button: true,
                    selected: index == i,
                    child: IconButton(
                      onPressed: () => select(i),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(54, 54),
                        backgroundColor: index == i ? N.wine : N.canvas,
                        foregroundColor: index == i ? Colors.white : N.muted,
                        shape: const CircleBorder(),
                      ),
                      icon: Icon(icons[i]),
                    ),
                  ),
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: RepaintBoundary(child: NexusBackdrop())),
          SafeArea(
            child: wide
                ? Row(
                    children: [
                      sidebar,
                      Expanded(child: content),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: content),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
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
        ],
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
