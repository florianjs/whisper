import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/keyboard_layout.dart';
import '../theme/tokens.dart';

/// Text being typed on [SecureKeyboard]. Deliberately not a
/// TextEditingController: nothing here is ever attached to a platform text
/// input connection, so the system keyboard (IME) never receives it.
class SecureTextController extends ValueNotifier<String> {
  SecureTextController() : super('');

  void insert(String s) => value = value + s;

  void backspace() {
    if (value.isEmpty) return;
    // Remove one user-perceived character, not half an emoji or accent.
    final chars = value.characters;
    value = chars.take(chars.length - 1).toString();
  }

  void clear() => value = '';
}

/// Whisper's own keyboard (paranoia mode). No key previews, excluded from the
/// accessibility tree, optional per-open shuffled layout.
class SecureKeyboard extends StatefulWidget {
  const SecureKeyboard({
    super.key,
    required this.controller,
    required this.languageCode,
    required this.shuffle,
    required this.spaceLabel,
    this.random,
  });

  final SecureTextController controller;
  final String languageCode;
  final bool shuffle;
  final String spaceLabel;
  final Random? random;

  @override
  State<SecureKeyboard> createState() => _SecureKeyboardState();
}

class _SecureKeyboardState extends State<SecureKeyboard> {
  KeyboardPage _page = KeyboardPage.letters;
  bool _shift = false;
  late final Random _random = widget.random ?? Random.secure();

  // Shuffled once per keyboard opening (i.e. per State), not per key press:
  // a layout that moves under the finger would be unusable.
  late List<List<String>> _letters = _lettersFor(widget.languageCode);

  List<List<String>> _lettersFor(String lang) {
    final base = KeyboardLayout.letters(lang);
    return widget.shuffle ? KeyboardLayout.shuffle(base, _random) : base;
  }

  @override
  void didUpdateWidget(SecureKeyboard old) {
    super.didUpdateWidget(old);
    if (old.languageCode != widget.languageCode ||
        old.shuffle != widget.shuffle) {
      _letters = _lettersFor(widget.languageCode);
    }
  }

  List<List<String>> get _rows => _page == KeyboardPage.letters
      ? _letters
      : KeyboardLayout.page(_page, widget.languageCode);

  void _type(String key) {
    HapticFeedback.selectionClick();
    widget.controller.insert(_shift ? KeyboardLayout.upper(key) : key);
    if (_shift) setState(() => _shift = false);
  }

  void _setPage(KeyboardPage page) => setState(() {
    _page = page;
    _shift = false;
  });

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return ExcludeSemantics(
      child: Container(
        color: context.c.isDark ? context.c.surface : context.c.surface2,
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(rows[0].map(_charKey).toList()),
            _row(rows[1].map(_charKey).toList()),
            _row([
              _ActionKey(
                flex: 3,
                icon: _page == KeyboardPage.letters
                    ? (_shift
                          ? Icons.keyboard_capslock_rounded
                          : Icons.arrow_upward_rounded)
                    : null,
                highlighted: _shift,
                onTap: _page == KeyboardPage.letters
                    ? () => setState(() => _shift = !_shift)
                    : null,
              ),
              ...rows[2].map(_charKey),
              _BackspaceKey(onDelete: widget.controller.backspace),
            ]),
            _row([
              _ActionKey(
                flex: 3,
                label: _page == KeyboardPage.symbols ? 'ABC' : '?123',
                onTap: () => _setPage(
                  _page == KeyboardPage.symbols
                      ? KeyboardPage.letters
                      : KeyboardPage.symbols,
                ),
              ),
              _ActionKey(
                flex: 2,
                label: _page == KeyboardPage.accents ? 'ABC' : 'éà',
                onTap: () => _setPage(
                  _page == KeyboardPage.accents
                      ? KeyboardPage.letters
                      : KeyboardPage.accents,
                ),
              ),
              _CharKey(label: ',', onTap: () => _type(',')),
              _ActionKey(
                flex: 8,
                label: widget.spaceLabel,
                onTap: () => _type(' '),
              ),
              _CharKey(label: '.', onTap: () => _type('.')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _charKey(String c) => _CharKey(
    label: _shift ? KeyboardLayout.upper(c) : c,
    onTap: () => _type(c),
  );

  Widget _row(List<Widget> keys) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: keys),
  );
}

class _KeyShell extends StatefulWidget {
  const _KeyShell({
    required this.flex,
    required this.child,
    required this.onTapDown,
    this.color,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final int flex;
  final Widget child;
  final VoidCallback? onTapDown;

  /// Null = a regular character key.
  final Color? color;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  @override
  State<_KeyShell> createState() => _KeyShellState();
}

class _KeyShellState extends State<_KeyShell> {
  bool _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = widget.color ?? (c.isDark ? c.surface2 : c.surface);
    return Expanded(
      flex: widget.flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5),
        child: GestureDetector(
          // Fire on touch-down: typing feels immediate, no press delay.
          onTapDown: widget.onTapDown == null
              ? null
              : (_) {
                  _press(true);
                  widget.onTapDown!();
                },
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          onLongPressStart: widget.onLongPressStart == null
              ? null
              : (_) => widget.onLongPressStart!(),
          onLongPressEnd: (_) {
            _press(false);
            widget.onLongPressEnd?.call();
          },
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _pressed ? Color.alphaBlend(c.accentSoft, base) : base,
              borderRadius: BorderRadius.circular(10),
              boxShadow: c.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _CharKey extends StatelessWidget {
  const _CharKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _KeyShell(
    flex: 2,
    onTapDown: onTap,
    child: Text(label, style: TextStyle(color: context.c.fg, fontSize: 20)),
  );
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.flex,
    this.label,
    this.icon,
    this.onTap,
    this.highlighted = false,
  });

  final int flex;
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => _KeyShell(
    flex: flex,
    onTapDown: onTap,
    color: highlighted ? context.c.accent : context.c.border,
    child: icon != null
        ? Icon(
            icon,
            size: 20,
            color: highlighted ? context.c.onAccent : context.c.fg,
          )
        : Text(
            label ?? '',
            style: TextStyle(
              color: context.c.fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
  );
}

/// Deletes on touch; held down, keeps deleting.
class _BackspaceKey extends StatefulWidget {
  const _BackspaceKey({required this.onDelete});

  final VoidCallback onDelete;

  @override
  State<_BackspaceKey> createState() => _BackspaceKeyState();
}

class _BackspaceKeyState extends State<_BackspaceKey> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _KeyShell(
    flex: 3,
    color: context.c.border,
    onTapDown: () {
      HapticFeedback.selectionClick();
      widget.onDelete();
    },
    onLongPressStart: () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 70),
        (_) => widget.onDelete(),
      );
    },
    onLongPressEnd: () => _repeat?.cancel(),
    child: Icon(Icons.backspace_outlined, size: 20, color: context.c.fg),
  );
}
