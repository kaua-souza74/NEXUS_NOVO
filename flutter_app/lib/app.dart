import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      return MaterialApp(
        title: 'NEXUS',
        theme: ThemeData(colorSchemeSeed: const Color(0xff22577a), useMaterial3: true),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY para iniciar o NEXUS.'),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'NEXUS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xff22577a), useMaterial3: true),
      home: const _AuthGate(),
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
        return const AppShell();
      },
    );
  }
}
