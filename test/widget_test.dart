import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ndk/ndk.dart' show Bip340EventVerifier, Nip01Event;
import 'package:whisper/data/account_wiper.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/channel_store.dart';
import 'package:whisper/data/group_store.dart';
import 'package:whisper/widgets/app_button.dart';
import 'package:whisper/widgets/chat_parts.dart';

import 'support/fake_network.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/data/lockable_vault.dart';
import 'package:whisper/logic/pin_crypto.dart';
import 'package:whisper/data/message_store.dart';
import 'package:whisper/data/profile_store.dart';
import 'package:whisper/data/relay_service.dart';
import 'package:whisper/data/settings_store.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/nip17.dart';
import 'package:whisper/logic/relays.dart';
import 'package:whisper/models/message.dart';
import 'package:whisper/main.dart';
import 'package:whisper/screens/chat_screen.dart';

const vector12 =
    'leader monkey parrot ring guide accident before fence cannon height naive bean';

/// Reports every relay connected as soon as it's listened to.
OnlineBackend? lastBackend;

class OnlineBackend implements RelayBackend {
  OnlineBackend(this.urls) {
    lastBackend = this;
  }
  final List<String> urls;

  @override
  Stream<Map<String, bool>> get connectivity =>
      Stream.value({for (final u in urls) u: true});

  @override
  Future<void> reconnect() async {}

  @override
  Future<void> publish({
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) async {}

  @override
  Future<void> publishSigned(Nip01Event event, {List<String>? relays}) async {}

  /// Test hook: push gift wraps as if relays delivered them.
  final wraps = StreamController<Nip01Event>.broadcast();

  @override
  Stream<Nip01Event> giftWraps({required String pubkey, required int since}) =>
      wraps.stream;

  @override
  Future<List<String>> inboxRelaysOf(String pubkey) async => const [];

  @override
  Future<void> dispose() async {}
}

IdentityStore makeStore([KeyVault? vault]) => IdentityStore(
  vault ?? MemoryKeyVault(),
  derive: (m) async => deriveIdentity(m),
);

/// Cheap Argon2 so lock tests stay fast; production uses OWASP costs.
LockableVault testLockVault(KeyVault inner) => LockableVault(
  inner,
  derive: (pin, p) async => deriveKek((pin, p)),
  newParams: () => KdfParams.fresh(memoryKiB: 64, iterations: 1),
);

Future<MemoryDocStore> pumpApp(
  WidgetTester tester,
  IdentityStore store, {
  KeyVault? vault,
  LockableVault? lockVault,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = MemoryDocStore();
  final relays = RelayService(
    identity: store,
    db: db,
    backendFactory: (_, urls) => OnlineBackend(urls),
    // Zero: runs during pumps instead of outliving the test.
    resubscribeDebounce: Duration.zero,
  );
  addTearDown(relays.dispose);
  final messages = MessageStore(identity: store, db: db, transport: relays);
  final settings = SettingsStore(db);
  await settings.hydrate();
  final profile = ProfileStore(
    identity: store,
    db: db,
    transport: relays,
    messages: messages,
    processPhoto: (raw) async => raw,
  );
  addTearDown(profile.dispose);
  final groups = GroupStore(
    identity: store,
    db: db,
    transport: relays,
    messages: messages,
  );
  addTearDown(groups.dispose);
  final channels = ChannelStore(
    identity: store,
    db: db,
    transport: FakeNetwork().channelTransport(),
    giftTransport: relays,
    messages: messages,
  );
  addTearDown(channels.dispose);
  addTearDown(messages.dispose);
  final lock = lockVault ?? testLockVault(vault ?? MemoryKeyVault());
  await lock.init();
  await tester.pumpWidget(
    WhisperApp(
      vault: lock,
      identity: store,
      db: db,
      relays: relays,
      settings: settings,
      messages: messages,
      profile: profile,
      groups: groups,
      channels: channels,
      wiper: AccountWiper(
        vault: lockVault ?? vault ?? MemoryKeyVault(),
        db: db,
        identity: store,
        clearClipboard: () async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  setUpAll(() => Nip17.verifier = Bip340EventVerifier(useIsolate: false));

  testWidgets('new user lands on welcome', (tester) async {
    await pumpApp(tester, makeStore());
    expect(find.text('Whisper'), findsOneWidget);
    expect(find.text('Create my identity'), findsOneWidget);
  });

  testWidgets('existing user skips onboarding', (tester) async {
    final vault = MemoryKeyVault();
    await makeStore(vault).restore(vector12);
    final store = makeStore(vault);
    await store.hydrate();
    await pumpApp(tester, store);
    expect(find.text(store.identity!.username), findsOneWidget);
    expect(
      find.text('Connected · ${defaultRelays.length}/${defaultRelays.length}'),
      findsOneWidget,
    );
  });

  testWidgets('French locale', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpApp(tester, makeStore());
    expect(find.text('Créer mon identité'), findsOneWidget);
  });

  testWidgets('restore flow', (tester) async {
    final store = makeStore();
    await pumpApp(tester, store);
    await tester.tap(find.text('I have a recovery phrase'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'leader monkey xyzzy ');
    await tester.pump();
    expect(find.text('Unknown word: xyzzy'), findsOneWidget);

    await tester.enterText(find.byType(TextField), vector12);
    await tester.pump();
    expect(find.text('12 words'), findsOneWidget);

    await tester.tap(find.text('Restore my account'));
    await tester.pumpAndSettle();
    expect(store.hasIdentity, isTrue);
    expect(find.text(store.identity!.username), findsOneWidget);
  });

  testWidgets('create flow requires reveal, saved box and verification', (
    tester,
  ) async {
    final store = makeStore();
    await pumpApp(tester, store);
    await tester.tap(find.text('Create my identity'));
    await tester.pumpAndSettle();

    final username = store.draftIdentity!.username;
    expect(find.text(username), findsOneWidget);

    // Hidden words must not leak through the semantics tree.
    final semantics = tester.ensureSemantics();
    final firstWord = store.draftMnemonic!.split(' ').first;
    expect(find.bySemanticsLabel(RegExp('\\b$firstWord\\b')), findsNothing);
    semantics.dispose();

    // Checkbox is inert until the words are revealed.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: list,
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    final hint = find.text('Tap to reveal. Make sure nobody is watching.');
    await tester.scrollUntilVisible(hint, -200, scrollable: list);
    await tester.ensureVisible(hint);
    await tester.pumpAndSettle();
    await tester.tap(hint);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: list,
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final words = store.draftMnemonic!.split(' ');
    for (var i = 0; i < 3; i++) {
      final prompt = find.textContaining('Which one is word #');
      final n = int.parse(
        RegExp(r'#(\d+)').firstMatch(tester.widget<Text>(prompt).data!)![1]!,
      );
      await tester.tap(find.text(words[n - 1]).last);
      await tester.pumpAndSettle();
    }

    expect(store.hasIdentity, isTrue);
    expect(find.text(username), findsOneWidget);
  });

  testWidgets('panic button: short press does nothing, hold wipes', (
    tester,
  ) async {
    final vault = MemoryKeyVault();
    final store = makeStore(vault);
    await store.restore(vector12);
    final db = await pumpApp(tester, store, vault: vault);
    await db.putDoc('messages', {'id': 'm1', 'text': 'secret'});

    await tester.tap(find.byTooltip('Panic button'));
    await tester.pumpAndSettle();
    expect(find.text('Erase everything'), findsOneWidget);

    // Released after 1s: rewinds, nothing erased.
    final button = find.text('Hold to erase');
    Future<void> hold(int ms) async {
      final gesture = await tester.startGesture(tester.getCenter(button));
      // Frame by frame: tap-down lands after the gesture arena delay and the
      // ring only advances on frames.
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
    }

    await hold(1000);
    await tester.pumpAndSettle();
    expect(store.hasIdentity, isTrue);
    expect(await db.listDocs('messages'), isNotEmpty);

    // Full hold: wiped and back on welcome.
    await hold(1800);
    await tester.pumpAndSettle();
    expect(store.hasIdentity, isFalse);
    expect(vault.values, isEmpty);
    expect(await db.listDocs('messages'), isEmpty);
    expect(find.text('Create my identity'), findsOneWidget);
  });

  testWidgets('new chat → send → bubble shows as sent', (tester) async {
    final store = makeStore();
    await store.restore(vector12);
    await pumpApp(tester, store);
    expect(find.text('No conversations yet'), findsOneWidget);

    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    // The button offers chat or group.
    await tester.tap(find.text('New chat').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-an-id');
    await tester.pump();
    expect(
      find.text("This isn't a valid ID. Check it was copied entirely."),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), store.identity!.npub);
    await tester.pump();
    expect(find.text("That's your own ID."), findsOneWidget);

    const bobNpub =
        'npub16sdj9zv4f8sl85e45vgq9n7nsgt5qphpvmf7vk8r5hhvmdjxx4es8rq74h';
    await tester.enterText(find.byType(TextField), bobNpub);
    await tester.pump();
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    expect(find.textContaining('end-to-end encrypted'), findsWidgets);
    expect(find.byTooltip('Send a photo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'premier message');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Send'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(find.text('premier message'), findsOneWidget);
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);

    // Long-press → Reply: the bar shows, then the quote in the new bubble.
    await tester.longPress(find.text('premier message'));
    await tester.pumpAndSettle();
    expect(find.text('Pin'), findsOneWidget);
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.text('Replying to You'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'suite');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Send'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Replying to You'), findsNothing);
    expect(find.text('suite'), findsOneWidget);
    expect(find.byType(QuoteBlock), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(QuoteBlock),
        matching: find.text('premier message'),
      ),
      findsOneWidget,
    );

    // Back on the list: the conversation is there with a "You:" preview.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('You: suite'), findsOneWidget);

    // Group with that contact.
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();
    final create = find.widgetWithText(AppButton, 'Create');
    await tester.enterText(find.byType(TextField), 'Famille');
    await tester.pump();
    expect(
      tester.widget<AppButton>(create).onPressed,
      isNull,
      reason: 'no member picked yet',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(create);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Famille'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'à tous');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Send'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('à tous'), findsOneWidget);
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    expect(find.byTooltip('Send a photo'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Famille'), findsOneWidget);
    expect(find.text('You: à tous'), findsOneWidget);
  });

  testWidgets('channel: create, post, react, invite code', (tester) async {
    final store = makeStore();
    await store.restore(vector12);
    await pumpApp(tester, store);

    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New channel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Annonces');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Create channel'));
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pumpAndSettle();
    expect(find.text('Annonces'), findsOneWidget);
    expect(find.byTooltip('Send a photo'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Première annonce');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Send'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Première annonce'), findsOneWidget);

    await tester.tap(find.byTooltip('React'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('❤️'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('❤️ 1'), findsOneWidget);

    // Edit in the composer; cancel first, then for real.
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Editing a post'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Editing a post'), findsNothing);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Première annonce, corrigée',
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Send'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Première annonce, corrigée'), findsOneWidget);
    expect(find.textContaining('· edited'), findsOneWidget);
    expect(find.text('Editing a post'), findsNothing);
    expect(find.text('❤️ 1'), findsOneWidget, reason: 'same post');

    // Pin it: the banner shows it; × unpins.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Pin'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Pinned message'), findsOneWidget);
    expect(find.text('Première annonce, corrigée'), findsNWidgets(2));
    await tester.tap(find.text('Pinned message'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Unpin').first);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.text('Pinned message'), findsNothing);

    await tester.tap(find.text('Annonces'));
    await tester.pumpAndSettle();
    expect(find.text('Channel info'), findsOneWidget);
    expect(find.text('Past posts'), findsOneWidget);
    expect(find.text('Full history'), findsOneWidget);
    expect(find.text('Copy invite'), findsOneWidget);
    expect(find.text('Invite contacts'), findsOneWidget);
    expect(find.text('Leave channel'), findsNothing, reason: 'admin');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Annonces'), findsOneWidget);
    expect(find.text('Première annonce, corrigée'), findsOneWidget);

    // A contact named in a post opens their chat.
    await tester.tap(find.text('Annonces'));
    await tester.pumpAndSettle();
    final bob = deriveIdentity(bobWords);
    await tester.enterText(find.byType(TextField), 'Écrivez à ${bob.npub} !');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Send'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    await tester.tapOnText(find.textRange.ofSubstring(bob.npub));
    await tester.pumpAndSettle();
    expect(find.text(usernameFor(bob.publicKey)), findsWidgets);
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  const bobHex =
      'd41b22899549e1f3d335a31002cfd382174006e166d3e658e3a5eecdb6463573';

  SettingsStore settingsOf(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first).read<SettingsStore>();

  testWidgets('language switch applies immediately', (tester) async {
    final store = makeStore();
    await store.restore(vector12);
    await pumpApp(tester, store);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsOneWidget);
    expect(settingsOf(tester).languageCode, 'fr');
  });

  for (final lang in ['es', 'de', 'ru', 'zh']) {
    testWidgets('$lang: home, start sheet and settings lay out', (
      tester,
    ) async {
      final store = makeStore();
      await store.restore(vector12);
      await pumpApp(tester, store);
      await settingsOf(tester).setLanguage(lang);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // close the sheet
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -20000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nickname: set in settings, shown on home', (tester) async {
    final store = makeStore();
    await store.restore(vector12);
    await pumpApp(tester, store);
    final username = store.identity!.username;

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nickname'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '  Léa  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Settings header: nickname, with the key-derived name under it.
    expect(find.text('Léa'), findsOneWidget);
    expect(find.text(username), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Léa'), findsOneWidget);
  });

  testWidgets('paranoia keyboard: masked, sends, never talks to the IME', (
    tester,
  ) async {
    final store = makeStore();
    await store.restore(vector12);
    await pumpApp(tester, store);
    await settingsOf(
      tester,
    ).setParanoia(const ParanoiaSettings(inAppKeyboard: true, maskInput: true));

    final imeCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        imeCalls.add(call.method);
        return null;
      },
    );

    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).push('/chat/$bobHex');
    // The caret blinks forever, so no pumpAndSettle: step the transition.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text('Message'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final k in ['s', 'a', 'l', 'u', 't']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(find.text('•••••'), findsOneWidget);
    expect(find.text('salut'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Send'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('salut'), findsOneWidget); // the sent bubble
    expect(
      imeCalls.where((m) => m == 'TextInput.setClient'),
      isEmpty,
      reason: 'system keyboard must never be attached',
    );
  });

  testWidgets('accessibility lockdown hides message text', (tester) async {
    // Before the first frame, or the tree is never built for this app.
    final semantics = tester.ensureSemantics();
    final store = makeStore();
    await store.restore(vector12);
    await pumpApp(tester, store);
    final ctx = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(
      () => ctx.read<MessageStore>().send(bobHex, 'texte secret'),
    );
    await settingsOf(
      tester,
    ).setParanoia(const ParanoiaSettings(hideFromAccessibility: true));
    GoRouter.of(ctx).push('/chat/$bobHex');
    await tester.pumpAndSettle();

    expect(find.text('texte secret'), findsOneWidget); // on screen
    expect(find.bySemanticsLabel(RegExp('texte secret')), findsNothing);
    semantics.dispose();
  });

  group('message requests UI', () {
    const bobWords =
        'what bleak badge arrange retreat wolf trade produce cricket blur '
        'garlic valid proud rude strong choose busy staff weather area '
        'salt hollow arm fade';

    Future<(IdentityStore, String)> strangerWrites(WidgetTester tester) async {
      final store = makeStore();
      await store.restore(vector12);
      await pumpApp(tester, store);
      final bob = deriveIdentity(bobWords);
      await tester.runAsync(() async {
        final wrap = await Nip17.wrap(
          sender: bob,
          recipientPubkey: store.identity!.publicKey,
          rumor: Nip17.chatRumor(
            senderPubkey: bob.publicKey,
            recipientPubkey: store.identity!.publicKey,
            text: 'coucou, tu me connais ?',
          ),
        );
        lastBackend!.wraps.add(wrap);
      });
      // Unwrapping verifies signatures in an isolate: its replies arrive in
      // real time, the follow-up runs in the test's fake zone — alternate.
      final ms = tester
          .element(find.byType(Scaffold).first)
          .read<MessageStore>();
      for (var i = 0; i < 50 && ms.requests.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      return (store, bob.publicKey);
    }

    testWidgets('stranger lands in requests; accept unlocks the composer', (
      tester,
    ) async {
      final (_, bob) = await strangerWrites(tester);
      expect(find.text('No conversations yet'), findsOneWidget);
      expect(find.text('1 message request'), findsOneWidget);

      await tester.tap(find.text('1 message request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(usernameFor(bob)));
      await tester.pumpAndSettle();

      expect(find.text('coucou, tu me connais ?'), findsOneWidget);
      expect(find.textContaining('wants to chat with you'), findsOneWidget);
      expect(find.text('Message'), findsNothing, reason: 'no composer yet');

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Message'), findsOneWidget);
      expect(find.textContaining('wants to chat'), findsNothing);
    });

    testWidgets('block removes the request', (tester) async {
      final (_, bob) = await strangerWrites(tester);
      await tester.tap(find.text('1 message request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(usernameFor(bob)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(ctx.read<MessageStore>().stateOf(bob), ContactState.blocked);
      expect(ctx.read<MessageStore>().requests, isEmpty);
    });
  });

  group('app lock', () {
    Future<void> typePin(WidgetTester tester, String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump();
      }
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('enable, lock, wrong PIN, right PIN brings it all back', (
      tester,
    ) async {
      final inner = MemoryKeyVault();
      final lock = testLockVault(inner);
      await lock.init();
      final store = makeStore(lock);
      await store.restore(vector12);
      await pumpApp(tester, store, lockVault: lock);
      final name = store.identity!.username;
      expect(find.text(name), findsOneWidget);

      await tester.runAsync(() => lock.enable('482913'));
      expect(inner.values.containsKey('identity'), isFalse);

      lock.lock();
      await tester.pumpAndSettle();
      expect(find.text('Whisper is locked'), findsOneWidget);
      expect(store.hasIdentity, isFalse, reason: 'nothing kept in memory');
      expect(find.text(name), findsNothing);

      await typePin(tester, '111222');
      expect(find.text('Wrong PIN'), findsOneWidget);
      expect(find.text('Whisper is locked'), findsOneWidget);

      await typePin(tester, '482913');
      for (var i = 0; i < 20 && !store.hasIdentity; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text(name), findsOneWidget);
    });

    testWidgets('auto-lock holds when the activity was destroyed '
        '(engine kept alive, back via detached → resumed)', (tester) async {
      final inner = MemoryKeyVault();
      final lock = testLockVault(inner);
      await lock.init();
      final store = makeStore(lock);
      await store.restore(vector12);
      await pumpApp(tester, store, lockVault: lock);
      await tester.runAsync(() async {
        await lock.enable('482913');
        await lock.setAutoLockAfter(const Duration(milliseconds: 1));
      });

      final binding = tester.binding;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      expect(lock.isLocked, isFalse, reason: 'delay not reached at leave time');
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(lock.isLocked, isTrue);
      expect(find.text('Whisper is locked'), findsOneWidget);
    });

    testWidgets('duress PIN silently erases everything', (tester) async {
      final inner = MemoryKeyVault();
      final lock = testLockVault(inner);
      await lock.init();
      final store = makeStore(lock);
      await store.restore(vector12);
      await pumpApp(tester, store, lockVault: lock);
      await tester.runAsync(() async {
        await lock.enable('482913');
        await lock.setDuressPin('739104');
      });
      lock.lock();
      await tester.pumpAndSettle();

      await typePin(tester, '739104');
      await tester.pumpAndSettle();
      expect(inner.values, isEmpty);
      expect(store.hasIdentity, isFalse);
      expect(find.text('Create my identity'), findsOneWidget);
    });
  });

  test('lock redirect rules', () {
    String? r(
      String loc, {
      bool locked = false,
      bool enabled = false,
      bool id = false,
    }) => lockRedirect(
      location: loc,
      locked: locked,
      lockEnabled: enabled,
      hasIdentity: id,
    );
    expect(r('/home', locked: true, enabled: true), '/locked');
    expect(r('/chat/x', locked: true, enabled: true), '/locked');
    expect(r('/locked', locked: true, enabled: true), isNull);
    expect(r('/locked', enabled: true, id: true), '/home');
    expect(r('/locked', enabled: true), isNull, reason: 'still re-hydrating');
    expect(r('/locked'), '/', reason: 'duress wiped the lock');
    expect(r('/home', id: true), isNull);
  });
}
