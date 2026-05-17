import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String agentServerUrl = 'http://localhost:3000';

// ─── Prompt Modal (protected — not editable by the agent) ────────────────────

class PromptModal extends StatefulWidget {
  const PromptModal({super.key, required this.onPromptComplete});

  final VoidCallback onPromptComplete;

  @override
  State<PromptModal> createState() => _PromptModalState();
}

class _PromptModalState extends State<PromptModal> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_Message> _messages = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;

    setState(() {
      _messages.add(_Message(text: prompt, isUser: true));
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse('$agentServerUrl/prompt'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 120));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'] as String? ?? 'No response';
      final isError = body['status'] == 'error';

      setState(() {
        _messages
            .add(_Message(text: message, isUser: false, isError: isError));
      });

      if (!isError) widget.onPromptComplete();
    } catch (e) {
      setState(() {
        _messages.add(_Message(
            text: 'Connection error: $e', isUser: false, isError: true));
      });
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Color(0xFF6C63FF), size: 20),
                    const SizedBox(width: 8),
                    const Text('AI Assistant',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _messages.isEmpty
                    ? const _EmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) =>
                            _MessageBubble(message: _messages[index]),
                      ),
              ),
              if (_loading)
                const LinearProgressIndicator(
                  backgroundColor: Color(0xFFEEEEEE),
                  color: Color(0xFF6C63FF),
                  minHeight: 2,
                ),
              _PromptInput(
                controller: _controller,
                loading: _loading,
                onSubmit: _sendPrompt,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 40, color: Colors.black12),
          SizedBox(height: 10),
          Text('Ask me to change the dashboard',
              style: TextStyle(color: Colors.black38, fontSize: 14)),
          SizedBox(height: 4),
          Text('e.g. "make the banner green"',
              style: TextStyle(color: Colors.black26, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PromptInput extends StatelessWidget {
  const _PromptInput({
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !loading,
                decoration: InputDecoration(
                  hintText: 'e.g. "make the banner green"',
                  hintStyle: const TextStyle(
                      color: Colors.black38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onSubmitted: loading ? null : onSubmit,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed:
                  loading ? null : () => onSubmit(controller.text),
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black12,
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
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF6C63FF)
              : message.isError
                  ? const Color(0xFFFFEBEE)
                  : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : message.isError
                    ? Colors.red.shade700
                    : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _Message {
  const _Message(
      {required this.text, required this.isUser, this.isError = false});

  final String text;
  final bool isUser;
  final bool isError;
}
