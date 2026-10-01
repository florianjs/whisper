import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/identity_store.dart';
import '../data/message_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/contact_code.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';

/// Shows the 60-digit safety number shared with [peer], to compare out of
/// band, and lets the user mark the contact as verified.
class SafetyNumberScreen extends StatelessWidget {
  const SafetyNumberScreen({super.key, required this.peer});

  final String peer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = context.watch<IdentityStore>().identity;
    final store = context.watch<MessageStore>();
    if (me == null) return const Scaffold();
    final groups = safetyNumber(me.publicKey, peer).split(' ');
    final name = store.displayName(peer);

    final c = context.c;
    final verified = store.isVerified(peer);
    return Scaffold(
      appBar: AppBar(title: Text(l.safetyNumber)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Avatar(pubkey: me.publicKey, size: 60),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: IconBadge(
                    icon: verified
                        ? Icons.verified_user_rounded
                        : Icons.sync_alt_rounded,
                    color: verified ? c.success : c.muted,
                    size: 36,
                    circle: true,
                  ),
                ),
                Avatar(pubkey: peer, size: 60),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l.safetyNumberBody(name),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: verified ? c.success.withValues(alpha: 0.4) : c.border,
                ),
              ),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.1,
                children: [
                  for (final g in groups)
                    Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        g,
                        style: TextStyle(
                          color: c.fg,
                          fontSize: 19,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              margin: EdgeInsets.zero,
              children: [
                SettingsTile(
                  icon: Icons.verified_rounded,
                  iconColor: c.success,
                  title: l.safetyMarkVerified,
                  onTap: () => store.setVerified(peer, !verified),
                  trailing: Switch(
                    value: verified,
                    onChanged: (v) => store.setVerified(peer, v),
                    activeTrackColor: c.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
