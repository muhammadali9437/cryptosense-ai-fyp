import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_scope.dart';
import '../services/sage_brain.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/explain.dart';
import '../widgets/tappable.dart';

/// Ask Sage: chat with the guide. Answers come from the backend RAG chatbot
/// (with sources) or, when the backend is offline, from built-in rules.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  int _lastCount = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    _input.clear();
    context.app.ask(q, context.market);
    _focus.requestFocus();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final pad = narrow ? 16.0 : 28.0;

    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final count = app.chat.length + (app.sageTyping ? 1 : 0);
        if (count != _lastCount) {
          _lastCount = count;
          _scrollToEnd();
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(pad, 24, pad, 12),
                    itemCount: count,
                    itemBuilder: (context, i) {
                      if (i >= app.chat.length) return const _Typing();
                      return _Bubble(message: app.chat[i]);
                    },
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: pad),
                    itemCount: SageBrain.suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _Suggestion(
                      text: SageBrain.suggestions[i],
                      onTap: () => _send(SageBrain.suggestions[i]),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 10, pad, pad),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                focusNode: _focus,
                                autofocus: !narrow,
                                onSubmitted: (_) => _send(),
                                textInputAction: TextInputAction.send,
                                style: AppText.body(15),
                                decoration: const InputDecoration(
                                  hintText: 'Ask about a coin, a chart, or how to use CryptoSense',
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: 'Send',
                              icon: Icons.arrow_upward_rounded,
                              onTap: app.sageTyping ? null : _send,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sage explains the market. It doesn't give financial advice or trade for you.",
                        style: AppText.body(12.5, color: AppColors.faint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: user ? AppColors.brass.fade(0.14) : AppColors.panel,
          border: Border.all(color: user ? AppColors.brass.fade(0.35) : AppColors.line),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(user ? 18 : 4),
            topRight: Radius.circular(user ? 4 : 18),
            bottomLeft: const Radius.circular(18),
            bottomRight: const Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message.text, style: AppText.body(15, height: 1.6)),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Sources', style: AppText.body(12, color: AppColors.faint, w: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < message.sources.length; i++)
                    _SourceChip(n: i + 1, source: message.sources[i]),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[const SageAvatar(size: 32), const SizedBox(width: 10)],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const SageAvatar(size: 32),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.muted.fade(
                          0.3 + 0.7 * (((_c.value * 3 - i) % 3) < 1 ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tappable(
        onTap: onTap,
        semanticLabel: text,
        builder: (context, s) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: s.hover ? AppColors.panelHi : AppColors.ink,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: s.focus ? AppColors.text : AppColors.brass.fade(0.35)),
          ),
          child: Text(text, style: AppText.body(13.5, color: AppColors.text)),
        ),
      );
}

/// One RAG source under a Sage answer, e.g. "[1] Funding rate and futures traders".
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.n, required this.source});
  final int n;
  final ChatSource source;

  @override
  Widget build(BuildContext context) {
    final label = switch (source.kind) {
      'news' => 'News',
      'signal' => 'AI signal',
      'academy' => 'Academy',
      'app_guide' => 'App guide',
      'methodology' => 'How signals work',
      _ => 'Source',
    };
    return Tooltip(
      message: source.url.isEmpty ? label : '$label: ${source.url}',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          '[$n] ${source.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(12, color: AppColors.muted),
        ),
      ),
    );
  }
}