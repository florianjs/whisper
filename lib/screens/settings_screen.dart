import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/account_wiper.dart';
import '../data/backup_service.dart';
import '../data/channel_store.dart';
import '../data/db.dart';
import '../data/group_store.dart';
import '../logic/nickname.dart';
import '../logic/backup.dart';
import '../logic/platform_files.dart';
import '../data/identity_store.dart';
import '../data/lockable_vault.dart';
import '../data/message_store.dart';
import '../data/profile_store.dart';
import '../data/relay_service.dart';
import '../data/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/identity.dart';
import '../logic/relays.dart';
import '../logic/secure_platform.dart';
import '../logic/auto_lock.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import 'pin_setup_screen.dart';
import '../widgets/panic_sheet.dart';
import '../widgets/relay_status.dart' show watchTor;
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _a11yApps = const [];

  @override
  void initState() {
    super.initState();
    SecurePlatform.enabledAccessibilityServices().then((apps) {
      if (mounted) setState(() => _a11yApps = apps);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final settings = context.watch<SettingsStore>();
    final p = settings.paranoia;

    void setP(ParanoiaSettings v) => settings.setParanoia(v);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 40),
        children: [
          const _ProfileCard(),
          SectionCard(
            label: l.appearanceTitle,
            children: [
              SettingsTile(
                icon: Icons.translate_rounded,
                title: l.settingsLanguage,
                subtitle:
                    _languageNames[settings.languageCode] ?? l.languageSystem,
                chevron: true,
                onTap: () => _pickLanguage(context, settings),
              ),
              _ChoiceRow<ThemeMode>(
                icon: Icons.palette_outlined,
                title: l.themeTitle,
                value: settings.themeMode,
                onChanged: settings.setThemeMode,
                options: [
                  (ThemeMode.system, l.themeSystem),
                  (ThemeMode.dark, l.themeDark),
                  (ThemeMode.light, l.themeLight),
                ],
              ),
            ],
          ),
          SectionCard(
            label: l.sectionAppLock,
            divided: false,
            children: const [_AppLockSection()],
          ),
          SectionCard(
            label: l.sectionBackup,
            divided: false,
            children: const [_BackupSection()],
          ),
          SectionCard(
            label: l.sectionNetwork,
            children: [
              if (watchTor(context) case final tor?) ...[
                _Toggle(
                  icon: Icons.shield_moon_outlined,
                  title: l.torToggle,
                  body: l.torToggleBody,
                  value: tor.wanted,
                  onChanged: tor.setWanted,
                ),
                if (tor.wanted)
                  _Toggle(
                    icon: Icons.theater_comedy_outlined,
                    title: l.torDisguise,
                    body: l.torDisguiseBody,
                    value: tor.disguise,
                    onChanged: tor.setDisguise,
                  ),
              ],
              _Toggle(
                icon: Icons.notifications_active_outlined,
                title: l.bgToggle,
                body: l.bgToggleBody,
                value: settings.background,
                onChanged: settings.setBackground,
              ),
              _NavTile(
                icon: Icons.hub_outlined,
                label: l.relaysManage,
                trailing: '${context.watch<RelayService>().relays.length}',
                onTap: () => showAppSheet<void>(
                  context,
                  scrollable: true,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<RelayService>(),
                    child: const _RelayEditor(),
                  ),
                ),
              ),
              _NavTile(
                icon: Icons.block_rounded,
                label: l.blockedPeople,
                trailing:
                    '${context.watch<MessageStore>().blockedPeers.length}',
                onTap: () => showAppSheet<void>(
                  context,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<MessageStore>(),
                    child: const _BlockedList(),
                  ),
                ),
              ),
            ],
          ),
          if (watchTor(context) case final tor? when !tor.wanted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: NoticeCard(
                text: l.torOffWarning,
                icon: Icons.warning_amber_rounded,
                color: c.warning,
              ),
            ),
          SectionLabel(l.sectionParanoia),
          if (_a11yApps.isNotEmpty) _A11yWarning(apps: _a11yApps),
          SectionCard(
            children: [
              _Toggle(
                icon: Icons.policy_outlined,
                title: l.paranoiaMaster,
                body: l.paranoiaMasterBody,
                value: p.allOn,
                accent: c.danger,
                onChanged: (on) =>
                    setP(on ? ParanoiaSettings.all : const ParanoiaSettings()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SectionCard(
            children: [
              _Toggle(
                icon: Icons.keyboard_alt_outlined,
                title: l.paranoiaKeyboard,
                body: l.paranoiaKeyboardBody,
                value: p.inAppKeyboard,
                onChanged: (v) => setP(p.copyWith(inAppKeyboard: v)),
              ),
              _Toggle(
                icon: Icons.shuffle_rounded,
                title: l.paranoiaShuffle,
                body: l.paranoiaShuffleBody,
                value: p.shuffleKeys,
                enabled: p.inAppKeyboard,
                indent: true,
                onChanged: (v) => setP(p.copyWith(shuffleKeys: v)),
              ),
              _Toggle(
                icon: Icons.password_rounded,
                title: l.paranoiaMask,
                body: l.paranoiaMaskBody,
                value: p.maskInput,
                onChanged: (v) => setP(p.copyWith(maskInput: v)),
              ),
              _Toggle(
                icon: Icons.blur_on_rounded,
                title: l.paranoiaBlur,
                body: l.paranoiaBlurBody,
                value: p.blurHistory,
                onChanged: (v) => setP(p.copyWith(blurHistory: v)),
              ),
              _Toggle(
                icon: Icons.accessibility_new_rounded,
                title: l.paranoiaA11y,
                body: l.paranoiaA11yBody,
                value: p.hideFromAccessibility,
                onChanged: (v) => setP(p.copyWith(hideFromAccessibility: v)),
              ),
              _Toggle(
                icon: Icons.no_photography_outlined,
                title: l.paranoiaSecure,
                body: l.paranoiaSecureBody,
                value: p.secureAllScreens,
                onChanged: (v) => setP(p.copyWith(secureAllScreens: v)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(
              l.paranoiaLimits,
              style: context.text.bodySmall?.copyWith(color: c.faint),
            ),
          ),
          SectionCard(
            label: l.sectionDanger,
            children: [
              _NavTile(
                icon: Icons.shield_outlined,
                label: l.panicTitle,
                danger: true,
                onTap: () => showPanicSheet(context),
              ),
              _NavTile(
                icon: Icons.logout_rounded,
                label: l.signOut,
                danger: true,
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SettingsTile(
      icon: icon,
      title: label,
      danger: danger,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: context.text.bodyMedium?.copyWith(color: c.muted),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: c.faint),
        ],
      ),
    );
  }
}

/// Switch row; the whole row toggles.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.indent = false,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool indent;

  /// Track color when on; defaults to the accent.
  final Color? accent;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    duration: AppMotion.normal,
    opacity: enabled ? 1 : 0.4,
    child: Padding(
      padding: EdgeInsets.only(left: indent ? 20 : 0),
      child: SettingsTile(
        icon: icon,
        iconColor: accent,
        title: title,
        subtitle: body,
        onTap: enabled ? () => onChanged(!value) : null,
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeTrackColor: accent,
        ),
      ),
    ),
  );
}

/// Title row plus a soft segmented control (language, theme).
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, size: 36),
              const SizedBox(width: 16),
              Text(
                title,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Row(
              children: [
                for (final (option, label) in options)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: option == value,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(option),
                        child: AnimatedContainer(
                          duration: AppMotion.normal,
                          curve: AppMotion.curve,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: option == value ? c.surface : null,
                            borderRadius: BorderRadius.circular(
                              AppRadius.sm - 2,
                            ),
                            boxShadow: option == value
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: c.isDark ? 0.3 : 0.08,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelLarge?.copyWith(
                              fontSize: 14,
                              color: option == value ? c.fg : c.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _A11yWarning extends StatelessWidget {
  const _A11yWarning({required this.apps});

  final List<String> apps;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: c.isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.visibility_rounded,
                color: c.warning,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.a11yWarningTitle, style: context.text.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l.a11yWarningBody,
            style: context.text.bodySmall?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 6),
          for (final app in apps)
            Text('• $app', style: context.text.bodyMedium),
          TextButton(
            onPressed: SecurePlatform.openAccessibilitySettings,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: c.warning,
            ),
            child: Text(l.a11yWarningAction),
          ),
        ],
      ),
    );
  }
}

class _RelayEditor extends StatefulWidget {
  const _RelayEditor();

  @override
  State<_RelayEditor> createState() => _RelayEditorState();
}

class _RelayEditorState extends State<_RelayEditor> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> urls) =>
      context.read<RelayService>().setRelays(urls);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final service = context.watch<RelayService>();
    final urls = service.relays.keys.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.relaysTitle, style: context.text.titleLarge),
          const SizedBox(height: 16),
          SectionCard(
            margin: EdgeInsets.zero,
            children: [
              for (final url in urls)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: service.relays[url] == true
                            ? c.success
                            : c.faint,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          url.replaceFirst('wss://', ''),
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: l.relayRemove,
                        onPressed: urls.length <= 1
                            ? null
                            : () => _save([...urls]..remove(url)),
                        icon: Icon(Icons.remove_circle_outline, color: c.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (urls.length <= 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                l.relayKeepOne,
                style: context.text.bodySmall?.copyWith(color: c.faint),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: l.relayAddHint,
                    errorText: _error,
                    isDense: true,
                    fillColor: c.surface2,
                    prefixIcon: Icon(Icons.add_link_rounded, color: c.faint),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: TextButton(
                  onPressed: () {
                    final url = normalizeRelayUrl(_input.text);
                    if (url == null) {
                      setState(() => _error = l.relayInvalid);
                      return;
                    }
                    setState(() => _error = null);
                    _input.clear();
                    if (!urls.contains(url)) _save([...urls, url]);
                  },
                  child: Text(l.relayAdd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Profile header: photo, generated name, photo actions.
/// Each language in its own name, so anyone can find theirs.
const _languageNames = {
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'de': 'Deutsch',
  'ru': 'Русский',
  'zh': '中文（简体）',
};

void _pickLanguage(BuildContext context, SettingsStore settings) {
  final l = AppLocalizations.of(context);
  final current = settings.languageCode;
  showAppSheet<void>(
    context,
    scrollable: true,
    builder: (sheetContext) {
      final c = sheetContext.c;
      Widget option(String? code, String label) => ListTile(
        title: Text(label),
        trailing: code == current
            ? Icon(Icons.check_rounded, color: c.accent)
            : null,
        selected: code == current,
        selectedColor: c.fg,
        onTap: () {
          Navigator.pop(sheetContext);
          settings.setLanguage(code);
        },
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                l.settingsLanguage,
                style: sheetContext.text.titleLarge,
              ),
            ),
            option(null, l.languageSystem),
            for (final e in _languageNames.entries) option(e.key, e.value),
          ],
        ),
      );
    },
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final profile = context.read<ProfileStore>();
    final file = await AutoLock.suspendWhile(
      () => ImagePicker().pickImage(
        source: source,
        // Let the platform downscale (and convert HEIC); we re-encode anyway.
        maxWidth: 1024,
        maxHeight: 1024,
        requestFullMetadata: false,
      ),
    );
    if (file == null) return;
    try {
      await profile.setPhoto(await file.readAsBytes());
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.photoError)));
    }
  }

  Future<void> _editNickname(
    BuildContext context,
    String username,
    String? current,
  ) async {
    final l = AppLocalizations.of(context);
    final profile = context.read<ProfileStore>();
    final name = await showTextPrompt(
      context,
      title: l.nicknameTitle,
      initial: current,
      hint: l.nicknameHint,
      help: l.nicknameBody(username),
      maxLength: maxNicknameLength,
      capitalization: TextCapitalization.words,
    );
    if (name != null) await profile.setName(name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final me = context.watch<IdentityStore>().identity;
    final profile = context.watch<ProfileStore>();
    final hasPhoto = profile.myPhoto != null;
    final nickname = profile.myName;
    if (me == null) return const SizedBox.shrink();

    Widget chip(IconData icon, String label, VoidCallback onTap, [Color? fg]) =>
        Material(
          color: (fg ?? c.accent).withValues(alpha: c.isDark ? 0.14 : 0.09),
          borderRadius: BorderRadius.circular(100),
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: fg ?? c.accent),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: context.text.labelMedium?.copyWith(
                      color: fg ?? c.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedSwitcher(
                  duration: AppMotion.normal,
                  child: Avatar(
                    key: ValueKey(hasPhoto),
                    pubkey: me.publicKey,
                    size: 64,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname ?? me.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nickname == null ? l.sectionProfile : me.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(
                  Icons.badge_outlined,
                  l.nicknameTitle,
                  () => _editNickname(context, me.username, nickname),
                ),
                chip(
                  Icons.photo_library_outlined,
                  l.photoFromGallery,
                  () => _pick(context, ImageSource.gallery),
                ),
                chip(
                  Icons.photo_camera_outlined,
                  l.photoFromCamera,
                  () => _pick(context, ImageSource.camera),
                ),
                if (hasPhoto)
                  chip(
                    Icons.delete_outline_rounded,
                    l.photoRemove,
                    context.read<ProfileStore>().removePhoto,
                    c.danger,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l.photoPrivacy,
              style: context.text.bodySmall?.copyWith(color: c.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedList extends StatelessWidget {
  const _BlockedList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final store = context.watch<MessageStore>();
    final blocked = store.blockedPeers.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.blockedPeople, style: context.text.titleLarge),
          const SizedBox(height: 16),
          if (blocked.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l.blockedEmpty,
                style: context.text.bodyMedium?.copyWith(color: c.muted),
              ),
            )
          else
            SectionCard(
              margin: EdgeInsets.zero,
              children: [
                for (final peer in blocked)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(
                      children: [
                        Avatar(pubkey: peer, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            usernameFor(peer),
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => store.unblock(peer),
                          child: Text(l.unblock),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final wiper = context.read<AccountWiper>();
  final danger = context.c.danger;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.signOutTitle),
      content: Text(l.signOutBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: danger),
          child: Text(l.signOut),
        ),
      ],
    ),
  );
  // Same erase as the panic button, reached calmly.
  if (ok == true) await wiper.panic();
}

class _AppLockSection extends StatefulWidget {
  const _AppLockSection();

  @override
  State<_AppLockSection> createState() => _AppLockSectionState();
}

class _AppLockSectionState extends State<_AppLockSection> {
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    context.read<LockableVault>().biometricsAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  void _open(PinSetupMode mode) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => PinSetupScreen(mode: mode)));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    final vault = context.watch<LockableVault>();
    if (!vault.isEnabled) {
      return SettingsTile(
        icon: Icons.pin_outlined,
        title: l.appLockSetup,
        subtitle: l.appLockSetupBody,
        chevron: true,
        onTap: () => _open(PinSetupMode.enable),
      );
    }
    final autoLock = vault.autoLockAfter.inSeconds;
    final rows = <Widget>[
      if (_bioAvailable)
        _Toggle(
          icon: Icons.fingerprint_rounded,
          title: l.appLockBiometrics,
          body: l.appLockBiometricsBody,
          value: vault.biometricsEnabled,
          onChanged: (on) => vault.setBiometrics(
            on,
            title: l.lockBiometricPrompt,
            cancel: l.cancel,
          ),
        ),
      _NavTile(
        icon: Icons.password_rounded,
        label: l.appLockChangePin,
        onTap: () => _open(PinSetupMode.change),
      ),
      SettingsTile(
        icon: Icons.timer_outlined,
        title: l.appLockAutoLock,
        trailing: DropdownButton<int>(
          value: autoLock,
          dropdownColor: c.surface2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          underline: const SizedBox.shrink(),
          style: context.text.bodyMedium?.copyWith(color: c.muted),
          items: [
            DropdownMenuItem(value: 0, child: Text(l.autoLockImmediately)),
            DropdownMenuItem(value: 60, child: Text(l.autoLockMinute)),
            DropdownMenuItem(value: 300, child: Text(l.autoLockFiveMinutes)),
          ],
          onChanged: (v) => vault.setAutoLockAfter(Duration(seconds: v ?? 0)),
        ),
      ),
      SettingsTile(
        icon: Icons.warning_amber_rounded,
        iconColor: c.warning,
        title: vault.hasDuress ? l.appLockDuressRemove : l.appLockDuressSet,
        subtitle: l.appLockDuressBody,
        onTap: vault.hasDuress
            ? vault.removeDuressPin
            : () => _open(PinSetupMode.duress),
      ),
      _NavTile(
        icon: Icons.lock_open_rounded,
        label: l.appLockTurnOff,
        onTap: () => _open(PinSetupMode.disable),
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(indent: 68, color: c.border),
          rows[i],
        ],
      ],
    );
  }
}

class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  bool _busy = false;

  BackupService _service() => BackupService(
    db: context.read<DocStore>(),
    identity: context.read<IdentityStore>(),
    reloaders: [
      context.read<MessageStore>().reload,
      context.read<GroupStore>().reload,
      context.read<ChannelStore>().reload,
      context.read<ProfileStore>().reload,
      () => context.read<SettingsStore>().hydrate(),
    ],
  );

  Future<void> _run(Future<String?> Function(AppLocalizations l) job) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String? message;
    try {
      message = await job(l);
    } on BackupException catch (e) {
      message = switch (e.reason) {
        'key' => l.backupWrongKey,
        'version' => l.backupNewer,
        _ => l.backupBadFile,
      };
    } catch (_) {
      message = l.backupFailed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<String?> _export(AppLocalizations l) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.backupWorking)));
    final bytes = await _service().export();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    // Neutral name: a file called "whisper-…" in someone's cloud drive
    // tells who uses what.
    final saved = await PlatformFiles.save('backup-$day.bin', bytes);
    return saved ? l.backupSaved : null;
  }

  Future<String?> _import(AppLocalizations l) async {
    final bytes = await PlatformFiles.open();
    if (bytes == null) return null;
    final added = await _service().import(bytes);
    return l.backupImported(added);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AnimatedOpacity(
      duration: AppMotion.normal,
      opacity: _busy ? 0.5 : 1,
      child: Column(
        children: [
          SettingsTile(
            icon: Icons.upload_file_rounded,
            title: l.backupExport,
            subtitle: l.backupExportBody,
            onTap: _busy ? null : () => _run(_export),
          ),
          Divider(indent: 68, color: context.c.border),
          SettingsTile(
            icon: Icons.download_rounded,
            title: l.backupImport,
            subtitle: l.backupImportBody,
            onTap: _busy ? null : () => _run(_import),
          ),
        ],
      ),
    );
  }
}
