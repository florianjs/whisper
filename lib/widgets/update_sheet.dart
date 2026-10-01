import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/update_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'app_button.dart';
import 'ui.dart';

/// Version, what happens, and the download / install button with progress.
Future<void> showUpdateSheet(BuildContext context) {
  final updates = context.read<UpdateService>();
  return showAppSheet<void>(
    context,
    scrollable: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: updates,
      child: const _UpdateSheet(),
    ),
  );
}

String? failureText(AppLocalizations l, UpdateFailure? failure) =>
    switch (failure) {
      null => null,
      UpdateFailure.network => l.updateFailedNetwork,
      UpdateFailure.checksum => l.updateFailedChecksum,
      UpdateFailure.signature => l.updateFailedSignature,
      UpdateFailure.permission => l.updateFailedPermission,
      UpdateFailure.install => l.updateFailedInstall,
    };

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet();

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  /// On each time the sheet opens: going off Tor is a one-off choice.
  bool _viaTor = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final updates = context.watch<UpdateService>();
    final latest = updates.latest;
    final busy =
        updates.stage == UpdateStage.downloading ||
        updates.stage == UpdateStage.installing;
    final error = failureText(l, updates.failure);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: IconBadge(
              icon: Icons.system_update_rounded,
              size: 64,
              circle: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            latest == null ? l.updateUpToDate : l.updateBanner('$latest'),
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
          if (updates.current case final current?) ...[
            const SizedBox(height: 4),
            Text(
              l.aboutVersion('$current'),
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: c.faint),
            ),
          ],
          const SizedBox(height: 16),
          NoticeCard(
            icon: Icons.verified_user_outlined,
            color: c.success,
            text: l.updateSheetBody,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            NoticeCard(
              icon: Icons.error_outline_rounded,
              color: c.danger,
              text: error,
            ),
          ],
          if (!busy) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(Icons.shield_moon_outlined, color: c.accent),
              title: Text(l.updateViaTor),
              subtitle: Text(l.updateViaTorBody),
              value: _viaTor,
              onChanged: (v) => setState(() => _viaTor = v),
            ),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              child: _viaTor
                  ? const SizedBox(width: double.infinity)
                  : NoticeCard(
                      icon: Icons.visibility_outlined,
                      color: c.danger,
                      text: l.updateDirectWarning,
                    ),
            ),
          ],
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: AppMotion.normal,
            child: busy
                ? Column(
                    key: const ValueKey('busy'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: updates.stage == UpdateStage.downloading
                              ? updates.progress
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        updates.stage == UpdateStage.downloading
                            ? l.updateDownloading
                            : l.updateInstalling,
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(color: c.muted),
                      ),
                    ],
                  )
                : AppButton(
                    key: const ValueKey('button'),
                    expand: true,
                    icon: Icons.download_rounded,
                    label: l.updateInstall,
                    onPressed: latest == null
                        ? null
                        : () => updates.install(viaTor: _viaTor),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Home row shown while a newer version waits.
class UpdateRow extends StatelessWidget {
  const UpdateRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final latest = context.watch<UpdateService>().latest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: c.success.withValues(alpha: c.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => showUpdateSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.system_update_rounded, color: c.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.updateBanner('$latest'),
                    style: context.text.titleSmall?.copyWith(color: c.fg),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.success),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
