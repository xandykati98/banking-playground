// ─── Bootstrap (protected — do not edit) ─────────────────────────────────────
// Owns: app entry point, layout fetching, polling loop.
// The entire UI lives in app_shell.dart — edit that instead.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_shell.dart';
import 'layout_model.dart';
import 'prompt_modal.dart';

void main() {
  runApp(const BankingPlaygroundApp());
}

// ─── Layout notifier ─────────────────────────────────────────────────────────

class _LayoutNotifier extends ChangeNotifier {
  LayoutData _data = LayoutData.empty;
  bool _loaded = false;

  LayoutData get data => _data;
  bool get loaded => _loaded;

  Future<void> reload() async {
    try {
      final response = await http
          .get(Uri.parse('$agentServerUrl/layout'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _data = LayoutData.fromJson(json);
        _loaded = true;
        notifyListeners();
      }
    } catch (_) {
      // Server not running yet — silently skip.
    }
  }
}

// ─── App ─────────────────────────────────────────────────────────────────────

class BankingPlaygroundApp extends StatelessWidget {
  const BankingPlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banking Playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const DashboardScreen(),
    );
  }
}

// ─── Dashboard Screen ─────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _LayoutNotifier _layout = _LayoutNotifier();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _layout.reload();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _layout.reload(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _layout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _layout,
      builder: (context, _) {
        if (!_layout.loaded) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            ),
          );
        }
        return AppShell(
          layout: _layout.data,
          onReload: _layout.reload,
        );
      },
    );
  }
}
