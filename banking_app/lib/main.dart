import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// When running on an Android emulator, use 10.0.2.2 instead of localhost.
// For iOS simulator or desktop, localhost works fine.
const String _agentServerUrl = 'http://localhost:3000';

void main() {
  runApp(const BankingPlaygroundApp());
}

class BankingPlaygroundApp extends StatelessWidget {
  const BankingPlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banking Playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C63FF),
          surface: const Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      ),
      home: const PlaygroundScreen(),
    );
  }
}

class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_Message> _messages = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;

    setState(() {
      _messages.add(_Message(text: prompt, isUser: true));
      _loading = true;
    });
    _controller.clear();

    try {
      final response = await http
          .post(
            Uri.parse('$_agentServerUrl/prompt'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 120));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'] as String? ?? 'No response';
      final isError = body['status'] == 'error';

      setState(() {
        _messages.add(_Message(text: message, isUser: false, isError: isError));
      });
    } catch (e) {
      setState(() {
        _messages.add(
          _Message(text: 'Connection error: $e', isUser: false, isError: true),
        );
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Banking Playground',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined, color: Colors.white70),
            tooltip: 'Check server health',
            onPressed: _checkHealth,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: _messages[index]),
                  ),
          ),
          if (_loading)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF2A2A3E),
              color: Color(0xFF6C63FF),
            ),
          _PromptBar(
            controller: _controller,
            loading: _loading,
            onSubmit: _sendPrompt,
          ),
        ],
      ),
    );
  }

  Future<void> _checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_agentServerUrl/health'))
          .timeout(const Duration(seconds: 5));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server OK — ${body['timestamp']}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server unreachable: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

class _PromptBar extends StatelessWidget {
  const _PromptBar({
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      color: const Color(0xFF16213E),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !loading,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tell the agent what to change…',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A3E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: loading ? null : onSubmit,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: loading ? null : () => onSubmit(controller.text),
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF6C63FF)
              : message.isError
                  ? Colors.red.shade900
                  : const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white, height: 1.4),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 48, color: Colors.white24),
          SizedBox(height: 12),
          Text(
            'Send a command to update the UI',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _Message {
  const _Message({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}
