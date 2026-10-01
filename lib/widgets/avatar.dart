import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/profile_store.dart';
import '../logic/identity.dart';
import '../theme/tokens.dart';

/// Profile photo if this contact shared one with me (accepted contacts only),
/// else a deterministic color + initials of the derived username
/// (`swift-otter-4821` → "SO").
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.pubkey, this.size = 44});

  final String pubkey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = context.select<ProfileStore, Uint8List?>(
      (p) => p.photoOf(pubkey),
    );
    if (photo != null) {
      return ClipOval(
        child: Image.memory(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Decode at display size, not the full 256 px, for long lists.
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      );
    }
    final parts = usernameFor(pubkey).split('-');
    final initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    final color =
        avatarPalette[int.parse(pubkey.substring(0, 2), radix: 16) %
            avatarPalette.length];
    final c = context.c;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: c.isDark ? 0.34 : 0.26),
            color.withValues(alpha: c.isDark ? 0.14 : 0.10),
          ],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: c.isDark ? color : Color.lerp(color, Colors.black, 0.25),
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
