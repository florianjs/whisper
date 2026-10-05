import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'data/account_wiper.dart';
import 'data/db.dart';
import 'data/background_delivery.dart';
import 'data/channel_relays.dart';
import 'data/channel_store.dart';
import 'data/group_store.dart';
import 'data/identity_store.dart';
import 'data/key_vault.dart';
import 'data/lockable_vault.dart';
import 'data/notifier.dart';
import 'data/message_store.dart';
import 'data/native_biometrics.dart';
import 'data/profile_store.dart';
import 'data/relay_service.dart';
import 'data/settings_store.dart';
import 'data/tor_service.dart';
import 'data/update_service.dart';
import 'l10n/app_localizations.dart';
import 'logic/auto_lock.dart';
import 'logic/channel.dart';
import 'logic/secure_platform.dart';
import 'logic/tor_proxy.dart';
import 'logic/identity.dart';
import 'logic/relays.dart';
import 'screens/channel_info_screen.dart';
import 'screens/channel_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/join_channel_screen.dart';
import 'screens/new_channel_screen.dart';
import 'screens/create_identity_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/group_info_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_group_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/new_chat_screen.dart';
import 'screens/requests_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/restore_screen.dart';
import 'screens/verify_seed_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _start();
  } on KeyVaultUnavailableException {
    // Nothing was deleted: a restart usually clears a Keystore hiccup.
    runApp(const _VaultErrorApp());
  }
}

Future<void> _start() async {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // With the app lock on, the account key and DB key are sealed under the
  // user's PIN: nothing below may read them until the lock screen succeeds.
  final vault = LockableVault(
    const SecureKeyVault(),
    biometrics: const NativeBiometrics(),
  );
  await vault.init();
  // Every HTTP/WebSocket connection of the app (ndk included) goes through
  // this — installed before anything connects. Tor is on by default and the
  // policy is fail-closed: until Tor is ready, nothing goes out directly.
  final tor = TorService(const SecureKeyVault());
  final torOverrides = TorHttpOverrides(
    () => (wanted: tor.wanted, proxy: tor.proxy),
  );
  HttpOverrides.global = torOverrides;
  await tor.init();
  final identity = IdentityStore(vault);
  final db = Db(vault);
  final relays = RelayService(identity: identity, db: db);
  final messages = MessageStore(identity: identity, db: db, transport: relays);
  final settings = SettingsStore(db);
  // Channel subscriptions on their own connections and Tor circuits.
  final channelPool = ChannelRelayPool(
    relays: () => relays.relays.keys.toList(),
    httpClient: () => torOverrides.isolated(ConnectProxy.channelsUser),
  );
  var relayKeys = '';
  var relaysOnline = false;
  relays.addListener(() {
    // New relay list, or the network / Tor just came back.
    final keys = relays.relays.keys.join(' ');
    final online = relays.connectedCount > 0;
    if (keys != relayKeys || (online && !relaysOnline)) channelPool.refresh();
    relayKeys = keys;
    relaysOnline = online;
  });
  if (!vault.isLocked) {
    // Hydrate before the first frame so the router never flashes onboarding
    // for an existing user, and so "block screenshots everywhere" holds from
    // the first frame.
    await identity.hydrate();
    await settings.hydrate();
    // Warm the DB up now: SQLCipher's key derivation makes the first open
    // slow, better paid during launch than on the first conversation screen.
    if (identity.hasIdentity) unawaited(db.getDoc('meta', 'schema'));
  }
  final groups = GroupStore(
    identity: identity,
    db: db,
    transport: relays,
    messages: messages,
  );
  // Notifications are built without a BuildContext: same language rule as
  // the app (setting, else system, else English).
  AppLocalizations strings() {
    final code =
        settings.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return lookupAppLocalizations(
      AppLocalizations.supportedLocales.any((l) => l.languageCode == code)
          ? Locale(code)
          : const Locale('en'),
    );
  }

  final platform = PlatformBackground(strings);
  final updates = UpdateService(
    settings: settings,
    platform: PlatformUpdater(),
    strings: strings,
    // Only with an open account: the setting lives in the encrypted DB.
    ready: () => !vault.isLocked && identity.hasIdentity,
  );
  unawaited(updates.start());
  runApp(
    WhisperApp(
      vault: vault,
      tor: tor,
      identity: identity,
      db: db,
      relays: relays,
      settings: settings,
      messages: messages,
      profile: ProfileStore(
        identity: identity,
        db: db,
        transport: relays,
        messages: messages,
      ),
      groups: groups,
      channels: ChannelStore(
        identity: identity,
        db: db,
        transport: channelPool,
        giftTransport: relays,
        messages: messages,
      ),
      background: BackgroundDelivery(
        identity: identity,
        settings: settings,
        platform: platform,
        relays: relays,
        notifier: ArrivalNotifier(
          arrivals: [messages.arrivals, groups.arrivals],
          sink: platform,
          enabled: () => settings.background,
        ),
      ),
      networkRestored: Connectivity().onConnectivityChanged
          .map((r) => !r.contains(ConnectivityResult.none))
          .distinct()
          .where((online) => online),
      wiper: AccountWiper(
        vault: vault,
        db: db,
        identity: identity,
        clearClipboard: SecurePlatform.clearClipboard,
        requestVanish: relays.requestVanish,
        clearNetworkState: () async {
          await TorService.clearDiskState();
          await updates.clearDownloads();
        },
      ),
      updates: updates,
    ),
  );
}

/// Where the router may go given lock + identity state (pure, for tests).
String? lockRedirect({
  required String location,
  required bool locked,
  required bool lockEnabled,
  required bool hasIdentity,
}) {
  if (locked) return location == '/locked' ? null : '/locked';
  if (location == '/locked') {
    if (hasIdentity) return '/home';
    // Unlocked but still re-hydrating: stay put instead of flashing welcome.
    // Lock gone entirely (duress / sign-out): fresh app.
    return lockEnabled ? null : '/';
  }
  return null;
}

final _groupId = RegExp(r'^[0-9a-f]{32}$');

bool _isOnboarding(String location) =>
    location == '/' ||
    location.startsWith('/create') ||
    location.startsWith('/restore');

GoRouter buildRouter(IdentityStore identity, LockableVault vault) => GoRouter(
  refreshListenable: Listenable.merge([identity, vault]),
  redirect: (context, state) {
    final lock = lockRedirect(
      location: state.matchedLocation,
      locked: vault.isLocked,
      lockEnabled: vault.isEnabled,
      hasIdentity: identity.hasIdentity,
    );
    if (lock != null || state.matchedLocation == '/locked') return lock;
    final onboarding = _isOnboarding(state.matchedLocation);
    if (!identity.hasIdentity && !onboarding) return '/';
    if (identity.hasIdentity && onboarding) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => const CreateIdentityScreen(),
          routes: [
            GoRoute(
              path: 'verify',
              builder: (context, state) => const VerifySeedScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'restore',
          builder: (context, state) => const RestoreScreen(),
        ),
      ],
    ),
    GoRoute(path: '/locked', builder: (context, state) => const LockScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/new', builder: (context, state) => const NewChatScreen()),
    GoRoute(
      path: '/requests',
      builder: (context, state) => const RequestsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/group/new',
      builder: (context, state) => const NewGroupScreen(),
    ),
    GoRoute(
      path: '/group/:id',
      redirect: (context, state) =>
          _groupId.hasMatch(state.pathParameters['id']!) ? null : '/home',
      builder: (context, state) =>
          GroupChatScreen(groupId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'info',
          builder: (context, state) =>
              GroupInfoScreen(groupId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'add',
          builder: (context, state) =>
              NewGroupScreen(groupId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/channel/new',
      builder: (context, state) => const NewChannelScreen(),
    ),
    GoRoute(
      path: '/channel/join',
      builder: (context, state) => const JoinChannelScreen(),
    ),
    GoRoute(
      path: '/channel/:pk',
      redirect: (context, state) =>
          Channel.isHex64(state.pathParameters['pk']) ? null : '/home',
      builder: (context, state) =>
          ChannelScreen(pk: state.pathParameters['pk']!),
      routes: [
        GoRoute(
          path: 'info',
          builder: (context, state) =>
              ChannelInfoScreen(pk: state.pathParameters['pk']!),
        ),
      ],
    ),
    GoRoute(
      path: '/chat/:peer',
      redirect: (context, state) =>
          parsePubkey(state.pathParameters['peer']!) == null ? '/home' : null,
      builder: (context, state) =>
          ChatScreen(peer: parsePubkey(state.pathParameters['peer']!)!),
    ),
  ],
);

class WhisperApp extends StatefulWidget {
  const WhisperApp({
    super.key,
    required this.vault,
    this.tor,
    required this.identity,
    required this.db,
    required this.relays,
    required this.settings,
    required this.messages,
    required this.profile,
    required this.groups,
    required this.channels,
    required this.wiper,
    this.background,
    this.networkRestored,
    this.updates,
  });

  final LockableVault vault;

  /// Null in widget tests (no native Tor there).
  final TorService? tor;
  final IdentityStore identity;
  final DocStore db;
  final RelayService relays;
  final SettingsStore settings;
  final MessageStore messages;
  final ProfileStore profile;
  final GroupStore groups;
  final ChannelStore channels;
  final AccountWiper wiper;

  /// Null in widget tests (no foreground service there).
  final BackgroundDelivery? background;

  /// Fires when the OS reports a network again. Injected so widget tests don't
  /// need the connectivity plugin.
  final Stream<void>? networkRestored;

  /// Null in widget tests: an inert service (no in-app updates).
  final UpdateService? updates;

  @override
  State<WhisperApp> createState() => _WhisperAppState();
}

class _WhisperAppState extends State<WhisperApp> {
  late final GoRouter _router = buildRouter(widget.identity, widget.vault);
  late final UpdateService _updates =
      widget.updates ??
      UpdateService(
        settings: widget.settings,
        platform: const NoUpdatePlatform(),
        strings: () => lookupAppLocalizations(const Locale('en')),
        ready: () => false,
      );
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: _onHide,
    onShow: _onShow,
    onResume: _onResume,
    // The activity is gone but the engine lives on (foreground service).
    onDetach: _onDetach,
  );

  void _onResume() {
    // Also reached straight from `detached` when a new activity attaches to
    // the cached engine — which skips onShow, so the auto-lock check must
    // run here too (idempotent: _onShow clears _hiddenAt).
    _onShow();
    // Android drops sockets while backgrounded; reconnect right away on
    // return instead of waiting out the backoff timer.
    widget.relays.reconnectNow();
  }

  DateTime? _hiddenAt;

  void _onDetach() {
    widget.background?.setForeground(false);
    // Normally set by onHide already; never leave without a lock timestamp.
    _hiddenAt ??= DateTime.now();
    if (widget.vault.autoLockAfter == Duration.zero) widget.vault.lock();
  }

  void _onHide() {
    widget.background?.setForeground(false);
    if (AutoLock.suspended) return;
    _hiddenAt = DateTime.now();
    if (widget.vault.autoLockAfter == Duration.zero) widget.vault.lock();
  }

  void _onShow() {
    widget.background?.setForeground(true);
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || AutoLock.suspended) return;
    if (AutoLock.shouldLock(
      hiddenAt: hiddenAt,
      now: DateTime.now(),
      after: widget.vault.autoLockAfter,
    )) {
      widget.vault.lock();
    }
  }

  /// Locked: forget the identity (every store drops its memory, relays
  /// disconnect) and close the DB. Unlocked: bring everything back.
  void _onVaultChanged() {
    final vault = widget.vault;
    // Unlocked, lock turned off, or wiped (panic, duress PIN).
    if (!vault.isLocked || !vault.isEnabled) widget.relays.stopWatching();
    if (vault.isLocked && widget.identity.hasIdentity) {
      // The account key leaves memory, but "a message arrived" only needs
      // the public key. Read the setting now: forgetting resets it. Android
      // only: iOS keeps no connection in the background anyway.
      if (widget.settings.background && Platform.isAndroid) {
        widget.relays.watchInbox();
      }
      widget.identity.forget();
      final db = widget.db;
      if (db is Db) unawaited(db.close());
    } else if (!vault.isLocked &&
        vault.isEnabled &&
        !widget.identity.hasIdentity) {
      unawaited(_rehydrate());
    }
  }

  Future<void> _rehydrate() async {
    await widget.identity.hydrate();
    await widget.settings.hydrate();
  }

  StreamSubscription<void>? _network;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    // Without this, a phone leaving a tunnel waits out the backoff (up to a
    // minute) before messages flow again.
    _network = widget.networkRestored?.listen(
      (_) => widget.relays.reconnectNow(),
    );
    widget.relays.addListener(_retryWhenOnline);
    widget.settings.addListener(_applySecureScreens);
    widget.identity.addListener(_resetSettingsOnWipe);
    widget.vault.addListener(_onVaultChanged);
    widget.tor?.addListener(_onTorChanged);
    _applySecureScreens();
  }

  bool _holdingSecure = false;

  /// Paranoia "block screenshots everywhere": one app-wide FLAG_SECURE hold.
  void _applySecureScreens() {
    final want = widget.settings.paranoia.secureAllScreens;
    if (want == _holdingSecure) return;
    _holdingSecure = want;
    want
        ? SecurePlatform.acquireSecureScreen()
        : SecurePlatform.releaseSecureScreen();
  }

  /// Panic wipes the DB; settings fall back to defaults in memory so nothing
  /// hints that paranoia mode was on. A wipe (not a lock) also brings Tor
  /// back to its default: on.
  void _resetSettingsOnWipe() {
    if (widget.identity.hasIdentity) return;
    widget.settings.reset();
    if (!widget.vault.isLocked) widget.tor?.setWanted(true);
  }

  TorState? _torState;

  /// Relays were blocked (fail-closed) while Tor bootstrapped: connect now.
  void _onTorChanged() {
    final state = widget.tor?.state;
    if (state != _torState && state == TorState.ready) {
      widget.relays.reconnectNow();
    }
    _torState = state;
  }

  bool _wasOnline = false;

  /// Messages that failed while offline go out as soon as a relay is back.
  void _retryWhenOnline() {
    final online = widget.relays.health == RelayHealth.online;
    if (online && !_wasOnline) {
      widget.messages.retryFailed();
      widget.profile.retry();
      widget.groups.retryFailed();
      widget.channels.retryFailed();
    }
    _wasOnline = online;
  }

  @override
  void dispose() {
    widget.settings.removeListener(_applySecureScreens);
    widget.identity.removeListener(_resetSettingsOnWipe);
    widget.vault.removeListener(_onVaultChanged);
    widget.tor?.removeListener(_onTorChanged);
    widget.relays.removeListener(_retryWhenOnline);
    _network?.cancel();
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.vault),
        if (widget.tor != null)
          ChangeNotifierProvider.value(value: widget.tor!),
        ChangeNotifierProvider.value(value: widget.identity),
        Provider<DocStore>.value(value: widget.db),
        ChangeNotifierProvider.value(value: widget.relays),
        ChangeNotifierProvider.value(value: widget.messages),
        ChangeNotifierProvider.value(value: widget.profile),
        ChangeNotifierProvider.value(value: widget.groups),
        ChangeNotifierProvider.value(value: widget.channels),
        ChangeNotifierProvider.value(value: widget.settings),
        Provider.value(value: widget.wiper),
        ChangeNotifierProvider.value(value: _updates),
      ],
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) =>
            _app(widget.settings.languageCode, widget.settings.themeMode),
      ),
    );
  }

  Widget _app(String? languageCode, ThemeMode themeMode) {
    return MaterialApp.router(
      locale: languageCode == null ? null : Locale(languageCode),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(AppPalette.light),
      darkTheme: buildTheme(AppPalette.dark),
      themeMode: themeMode,
      themeAnimationCurve: AppMotion.curve,
      // Screens without an app bar still get readable status bar icons.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyleFor(context.c),
        child: child!,
      ),
    );
  }
}

/// Shown when the phone's secure storage can't be read at launch. Data is
/// left untouched; restarting (or rebooting the phone) is the fix.
class _VaultErrorApp extends StatelessWidget {
  const _VaultErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(AppPalette.light),
      darkTheme: buildTheme(AppPalette.dark),
      home: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context);
          final c = context.c;
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: c.warning.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_clock_outlined,
                        color: c.warning,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.vaultErrorTitle,
                      textAlign: TextAlign.center,
                      style: context.text.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.vaultErrorBody,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
