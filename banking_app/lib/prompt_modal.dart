import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String agentServerUrl = 'http://localhost:3000';

// Collapses excessive newlines from the SDK/model stream. [trim] applies on every
// frame (including mid-stream): only the *displayed* string is trimmed; segment
// buffers keep appending raw deltas, so no content is lost before the next chunk.
String _normalizeStreamText(String input) {
  if (input.isEmpty) return input;
  var s = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

// ─── Data types ──────────────────────────────────────────────────────────────

enum _Role { user, assistant }

class _ChatMessage {
  _ChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
    this.timestamp,
  });

  final _Role role;
  final String text;
  final bool isError;
  final int? timestamp;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _ChatMessage(
        role: (json['role'] as String?) == 'user' ? _Role.user : _Role.assistant,
        text: json['text'] as String? ?? '',
        isError: json['isError'] as bool? ?? false,
        timestamp: json['timestamp'] as int?,
      );
}

class _ActivityEvent {
  const _ActivityEvent({
    required this.kind,
    this.callId,
    this.toolName,
    this.toolStatus,
    this.toolInput,
    this.delta,
    this.isError = false,
  });

  final String kind; // "tool" | "thinking" | "text_delta" | "done"
  final String? callId;
  final String? toolName;
  final String? toolStatus; // "running" | "completed" | "error"
  final String? toolInput; // file path extracted from tool args
  final String? delta;
  final bool isError;

  factory _ActivityEvent.fromJson(Map<String, dynamic> json) => _ActivityEvent(
        kind: json['kind'] as String? ?? 'done',
        callId: json['callId'] as String?,
        toolName: json['toolName'] as String?,
        toolStatus: json['toolStatus'] as String?,
        toolInput: json['toolInput'] as String?,
        delta: json['delta'] as String?,
        isError: json['isError'] as bool? ?? false,
      );
}

// ─── Stream state ─────────────────────────────────────────────────────────────

class _ToolEntry {
  _ToolEntry({required this.callId, required this.name, required this.status, this.input});
  final String callId;
  final String name;
  String status;
  final String? input; // file path, if available
}

// A segment is one of: a batch of tool calls, a block of thinking text,
// or a block of assistant text. All are kept in a single ordered list so
// the rendered output matches the actual sequence of agent activity.
enum _SegType { toolBatch, thinking, text }

class _Seg {
  _Seg.tools()
      : type = _SegType.toolBatch,
        content = '',
        tools = [],
        _toolIndex = {};
  _Seg.thinking(String initial)
      : type = _SegType.thinking,
        content = initial,
        tools = [],
        _toolIndex = {};
  _Seg.text(String initial)
      : type = _SegType.text,
        content = initial,
        tools = [],
        _toolIndex = {};

  final _SegType type;
  String content; // thinking / text
  final List<_ToolEntry> tools; // toolBatch
  final Map<String, int> _toolIndex;

  void addOrUpdateTool(String callId, String name, String status, {String? input}) {
    if (_toolIndex.containsKey(callId)) {
      tools[_toolIndex[callId]!].status = status;
    } else {
      _toolIndex[callId] = tools.length;
      tools.add(_ToolEntry(callId: callId, name: name, status: status, input: input));
    }
  }
}

class _StreamState {
  final List<_Seg> segments = [];

  bool get isEmpty => segments.isEmpty;

  void apply(_ActivityEvent e) {
    switch (e.kind) {
      case 'tool':
        if (e.toolName == null || e.toolStatus == null) return;
        final id = e.callId ?? '${e.toolName}-${segments.length}';
        // Search existing tool batches for this callId (handles running→completed).
        for (final seg in segments) {
          if (seg.type == _SegType.toolBatch && seg._toolIndex.containsKey(id)) {
            seg.addOrUpdateTool(id, e.toolName!, e.toolStatus!, input: e.toolInput);
            return;
          }
        }
        // New call — add to the last toolBatch or create one.
        if (segments.isNotEmpty && segments.last.type == _SegType.toolBatch) {
          segments.last.addOrUpdateTool(id, e.toolName!, e.toolStatus!, input: e.toolInput);
        } else {
          final batch = _Seg.tools();
          batch.addOrUpdateTool(id, e.toolName!, e.toolStatus!, input: e.toolInput);
          segments.add(batch);
        }
      case 'thinking':
        if (segments.isNotEmpty && segments.last.type == _SegType.thinking) {
          segments.last.content += e.delta ?? '';
        } else {
          segments.add(_Seg.thinking(e.delta ?? ''));
        }
      case 'text_delta':
        if (segments.isNotEmpty && segments.last.type == _SegType.text) {
          segments.last.content += e.delta ?? '';
        } else {
          segments.add(_Seg.text(e.delta ?? ''));
        }
    }
  }

  void clear() => segments.clear();
}

// ─── Prompt Modal ─────────────────────────────────────────────────────────────

class PromptModal extends StatefulWidget {
  const PromptModal({super.key, required this.onPromptComplete});

  final VoidCallback onPromptComplete;

  @override
  State<PromptModal> createState() => _PromptModalState();
}

class _PromptModalState extends State<PromptModal> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  final _StreamState _stream = _StreamState();

  bool _loading = false;
  bool _historyLoaded = false;

  // SSE
  http.Client? _sseClient;
  StreamSubscription<List<int>>? _sseSub;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connectSse();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sseSub?.cancel();
    _sseClient?.close();
    super.dispose();
  }

  // ── History ────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final resp = await http
          .get(Uri.parse('$agentServerUrl/messages'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          // Always replace — prevents duplicates from repeated reloads.
          _messages
            ..clear()
            ..addAll(list.map(
                (e) => _ChatMessage.fromJson(e as Map<String, dynamic>)));
          _historyLoaded = true;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _historyLoaded = true);
    }
  }

  // ── SSE ───────────────────────────────────────────────────────────────────

  void _connectSse() {
    final client = http.Client();
    _sseClient = client;

    final request = http.Request('GET', Uri.parse('$agentServerUrl/events'));
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    client.send(request).then((resp) {
      final sub = resp.stream.listen(
        _onSseBytes,
        onDone: _onSseDone,
        onError: (_) => _onSseDone(),
        cancelOnError: true,
      );
      _sseSub = sub;
    }).catchError((_) {
      // Server not up yet — silently ignore.
    });
  }

  final StringBuffer _sseBuffer = StringBuffer();

  void _onSseBytes(List<int> bytes) {
    _sseBuffer.write(utf8.decode(bytes));
    final raw = _sseBuffer.toString();

    // SSE frames are separated by double newlines.
    final parts = raw.split('\n\n');
    // Keep the last (possibly incomplete) chunk in the buffer.
    _sseBuffer
      ..clear()
      ..write(parts.last);

    for (final part in parts.sublist(0, parts.length - 1)) {
      final dataLine = part
          .split('\n')
          .firstWhere((l) => l.startsWith('data: '), orElse: () => '');
      if (dataLine.isEmpty) continue;
      final json = dataLine.substring(6).trim();
      try {
        final event = _ActivityEvent.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        _handleSseEvent(event);
      } catch (_) {}
    }
  }

  void _handleSseEvent(_ActivityEvent event) {
    if (!mounted) return;

    if (event.kind == 'done') {
      // Keep _stream visible — it freezes in place showing what the agent did.
      // It will be cleared only when the next prompt is sent.
      setState(() => _loading = false);
      widget.onPromptComplete();
      _loadHistory();
      _scrollToBottom();
      return;
    }

    setState(() {
      _stream.apply(event);
      _loading = true; // ensure loading stays true if SSE reconnect replays
    });
    _scrollToBottom();
  }

  void _onSseDone() {
    // Reconnect after a short delay — server may have restarted.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _connectSse();
    });
  }

  // ── Send prompt ───────────────────────────────────────────────────────────

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

  Future<void> _resetUi() async {
    setState(() => _loading = true);
    try {
      await http
          .post(Uri.parse('$agentServerUrl/reset'))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: _Role.user, text: prompt.trim()));
      _stream.clear();
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      await http
          .post(
            Uri.parse('$agentServerUrl/prompt'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 300));
      // The SSE 'done' event drives the UI update; nothing more to do here.
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
              role: _Role.assistant,
              text: 'Connection error: $e',
              isError: true));
          _loading = false;
          _stream.clear();
        });
        _scrollToBottom();
      }
    }
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  // Inserts the streaming bubble between the last user message and the last
  // assistant reply so the order is always: prompt → stream → response.
  List<Widget> _buildMessageList() {
    if (_stream.isEmpty) {
      return _messages.map<Widget>((m) => _MessageBubble(message: m)).toList();
    }

    // The streaming bubble already contains the full assistant reply via
    // text_delta, so skip the last assistant message to avoid duplication.
    final msgs = (_messages.isNotEmpty && _messages.last.role == _Role.assistant)
        ? _messages.sublist(0, _messages.length - 1)
        : _messages;

    return [
      ...msgs.map<Widget>((m) => _MessageBubble(message: m)),
      _StreamingBubble(
        state: _stream,
      ),
    ];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ──
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
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Color(0xFF6C63FF), size: 20),
                    const SizedBox(width: 8),
                    const Text('AI Assistant',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loading ? null : _resetUi,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Reset UI',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // ── Chat list ──
              Expanded(
                child: !_historyLoaded
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      )
                    : _messages.isEmpty && _stream.isEmpty
                        ? const _EmptyChat()
                        : ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            children: _buildMessageList(),
                          ),
              ),
              // ── Progress bar ──
              if (_loading)
                const LinearProgressIndicator(
                  backgroundColor: Color(0xFFEEEEEE),
                  color: Color(0xFF6C63FF),
                  minHeight: 2,
                ),
              // ── Input ──
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

// ─── Streaming bubble ────────────────────────────────────────────────────────
// A single bubble that accumulates tool calls, thinking, and assistant text
// during an active run. All events for one turn appear here in one place.

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({
    required this.state,
  });

  final _StreamState state;

  static const _bg = Color(0xFFF5F3FF);
  static const _border = Color(0xFFE8E0FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < state.segments.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            if (state.segments[i].type == _SegType.toolBatch)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: state.segments[i].tools
                    .map((t) => _ToolRow(name: t.name, status: t.status, input: t.input))
                    .toList(),
              )
            else if (state.segments[i].type == _SegType.thinking)
              _ThinkingBlock(
                text: state.segments[i].content,
              )
            else
              Text(
                _normalizeStreamText(state.segments[i].content),
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87, height: 1.4),
              ),
          ],
        ],
      ),
    );
  }
}

class _ThinkingBlock extends StatefulWidget {
  const _ThinkingBlock({
    required this.text,
  });
  final String text;

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _collapsed = !_collapsed),
          child: Row(children: [
            const Icon(Icons.psychology_outlined, size: 13, color: Color(0xFF9C8FE8)),
            const SizedBox(width: 5),
            const Text('Thinking',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9C8FE8),
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(
              _collapsed ? Icons.expand_more : Icons.expand_less,
              size: 13,
              color: const Color(0xFF9C8FE8),
            ),
          ]),
        ),
        if (!_collapsed) ...[
          const SizedBox(height: 2),
          Text(
            _normalizeStreamText(widget.text),
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
        ],
      ],
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.name, required this.status, this.input});

  final String name;
  final String status;
  final String? input;

  static const _labels = <String, String>{
    'read_file': 'Reading',
    'edit_file': 'Editing',
    'write_file': 'Writing',
    'create_file': 'Creating',
    'delete_file': 'Deleting',
    'list_dir': 'Listing directory',
    'grep': 'Searching code',
    'glob': 'Searching files',
    'semSearch': 'Semantic search',
    'mcp': 'Calling tool',
    'bash': 'Running command',
    'shell': 'Running command',
  };

  // Returns just the last path component for brevity.
  static String _basename(String p) {
    final parts = p.replaceAll(r'\', '/').split('/');
    return parts.lastWhere((s) => s.isNotEmpty, orElse: () => p);
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = status == 'running';
    final isError = status == 'error';
    final color = isError
        ? Colors.red.shade400
        : isRunning
            ? const Color(0xFF6C63FF)
            : Colors.green.shade600;
    final icon = isError
        ? Icons.error_outline
        : isRunning
            ? Icons.sync
            : Icons.check_circle_outline;
    final baseLabel = _labels[name] ?? name.replaceAll('_', ' ');
    final fileLabel = input != null ? _basename(input!) : null;
    final label = fileLabel != null ? '$baseLabel $fileLabel' : baseLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 11, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ─── Static widgets ──────────────────────────────────────────────────────────

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
                  hintStyle:
                      const TextStyle(color: Colors.black38, fontSize: 13),
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
              onPressed: loading ? null : () => onSubmit(controller.text),
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

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
