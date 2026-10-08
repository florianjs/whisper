import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// What the pinned banner shows.
class PinnedInfo {
  const PinnedInfo({required this.id, required this.preview, this.onUnpin});

  /// Id of the pinned item, as [ChatList.idAt] gives it.
  final String id;

  /// One line of it; null hides it (blurred history).
  final String? preview;

  /// Null: not mine to unpin.
  final VoidCallback? onUnpin;
}

/// A conversation's message list, newest at the bottom: the pinned banner
/// on top (tap: scroll to it), an arrow back to the latest messages once
/// scrolled up.
class ChatList extends StatefulWidget {
  const ChatList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.idAt,
    this.padding,
    this.pinned,
    this.firstUnreadId,
  });

  /// Index 0 is the newest (the list is reversed).
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String Function(int index) idAt;
  final EdgeInsetsGeometry? padding;
  final PinnedInfo? pinned;

  /// The oldest message I haven't seen: a "New messages" divider goes
  /// above it, and the list opens there when it's out of view.
  final String? firstUnreadId;

  @override
  State<ChatList> createState() => ChatListState();
}

class ChatListState extends State<ChatList> {
  final _controller = ScrollController();
  final _target = GlobalKey();
  bool _showLatest = false;
  String? _flashing;
  Timer? _flashTimer;

  /// The item [jumpTo] is looking for (holds [_target]).
  String? _focus;

  /// How far up before the "latest messages" arrow shows.
  static const latestThreshold = 400.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    final unread = widget.firstUnreadId;
    if (unread != null) {
      // A few new messages are on screen already: stay at the bottom.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _keyFor(unread)?.currentContext;
        final box = ctx?.findRenderObject() as RenderBox?;
        final viewport = context.findRenderObject() as RenderBox?;
        if (box != null && viewport != null && box.hasSize) {
          final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
          if (top >= 0) return;
        }
        jumpTo(unread, flash: false);
      });
    }
  }

  GlobalKey? _keyFor(String id) =>
      id == (_focus ?? _defaultFocus) ? _target : null;

  String? get _defaultFocus => widget.firstUnreadId ?? widget.pinned?.id;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _controller.offset > latestThreshold;
    if (show != _showLatest) setState(() => _showLatest = show);
  }

  void jumpToLatest() => _controller.animateTo(
    0,
    duration: AppMotion.slow,
    curve: AppMotion.curve,
  );

  /// Items are built lazily and their heights vary: jump close by
  /// estimate until the item exists, then bring it to the middle.
  Future<void> jumpTo(String id, {bool flash = true}) async {
    var index = -1;
    for (var i = 0; i < widget.itemCount && index < 0; i++) {
      if (widget.idAt(i) == id) index = i;
    }
    if (index < 0) return;
    if (_focus != id) {
      setState(() => _focus = id);
      await WidgetsBinding.instance.endOfFrame;
    }
    for (var attempt = 0; attempt < 12 && mounted; attempt++) {
      final target = _target.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: AppMotion.slow,
          curve: AppMotion.curve,
        );
        if (!mounted || !flash) return;
        setState(() => _flashing = id);
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _flashing = null);
        });
        return;
      }
      final pos = _controller.position;
      final ratio = index / max(1, widget.itemCount - 1);
      _controller.jumpTo(
        (pos.maxScrollExtent * ratio).clamp(0, pos.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pinned = widget.pinned;
    return Column(
      children: [
        if (pinned != null)
          PinnedBanner(
            preview: pinned.preview,
            onTap: () => jumpTo(pinned.id),
            onClose: pinned.onUnpin,
          ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _controller,
                reverse: true,
                padding: widget.padding,
                itemCount: widget.itemCount,
                itemBuilder: (context, i) {
                  var item = widget.itemBuilder(context, i);
                  final id = widget.idAt(i);
                  if (id == widget.firstUnreadId) {
                    item = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [const _NewMessagesDivider(), item],
                    );
                  }
                  final key = _keyFor(id);
                  if (key == null) return item;
                  return KeyedSubtree(
                    key: key,
                    child: AnimatedContainer(
                      duration: AppMotion.normal,
                      decoration: BoxDecoration(
                        color: _flashing == id
                            ? c.accentSoft
                            : c.accentSoft.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: item,
                    ),
                  );
                },
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: _LatestButton(visible: _showLatest, onTap: jumpToLatest),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: c.accent.withValues(alpha: 0.4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              l.chatNewMessages,
              style: context.text.labelMedium?.copyWith(
                color: c.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: c.accent.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

class _LatestButton extends StatelessWidget {
  const _LatestButton({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1 : 0,
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        child: Tooltip(
          message: l.chatJumpLatest,
          child: Material(
            color: c.surface,
            shape: CircleBorder(side: BorderSide(color: c.border)),
            elevation: 3,
            shadowColor: Colors.black26,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.keyboard_arrow_down_rounded, color: c.fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar under the app bar with the pinned message.
class PinnedBanner extends StatelessWidget {
  const PinnedBanner({
    super.key,
    required this.preview,
    required this.onTap,
    this.onClose,
  });

  final String? preview;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return Material(
      color: c.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          padding: EdgeInsets.fromLTRB(16, 8, onClose == null ? 16 : 4, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.push_pin_rounded, size: 18, color: c.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.pinnedMessage,
                      style: context.text.labelMedium?.copyWith(
                        color: c.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview != null)
                      Text(
                        preview!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium,
                      ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: l.unpinMessage,
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, size: 18, color: c.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Long-press menu of a message. Null callbacks hide their action.
Future<void> showMessageActions(
  BuildContext context, {
  VoidCallback? onReply,
  bool pinned = false,
  VoidCallback? onTogglePin,
}) async {
  final l = AppLocalizations.of(context);
  final picked = await showAppSheet<VoidCallback>(
    context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReply != null)
            SettingsTile(
              icon: Icons.reply_rounded,
              title: l.replyAction,
              onTap: () => Navigator.pop(sheetContext, onReply),
            ),
          if (onTogglePin != null)
            SettingsTile(
              icon: pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              title: pinned ? l.unpinMessage : l.pinMessage,
              onTap: () => Navigator.pop(sheetContext, onTogglePin),
            ),
        ],
      ),
    ),
  );
  picked?.call();
}
