// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Whisper';

  @override
  String get appTagline => 'Talk freely. No number, no name, no trace.';

  @override
  String get back => 'Back';

  @override
  String get continueLabel => 'Continue';

  @override
  String get welcomeCreate => 'Create my identity';

  @override
  String get welcomeRestore => 'I have a recovery phrase';

  @override
  String get welcomeFootnote =>
      'No phone number. No email. Your keys never leave this phone.';

  @override
  String get createGenerating => 'Generating your keys…';

  @override
  String get createUsernameLabel => 'YOU ARE';

  @override
  String get createUsernameCaption =>
      'Derived from your key. Nobody picked it, nobody can link it to you.';

  @override
  String get seedTitle => 'Recovery phrase';

  @override
  String get seedIntro =>
      'These words are the only way to get your account back. Whisper does not keep them: this is the only time you will see them. Save them in a password manager (Bitwarden, 1Password…) or on paper.';

  @override
  String get seedRevealHint => 'Tap to reveal. Make sure nobody is watching.';

  @override
  String get seedCopy => 'Copy';

  @override
  String get seedCopied => 'Copied. The clipboard will be cleared in 60 s.';

  @override
  String get seedWarning =>
      'Anyone with these words becomes you. Nobody can reset them: lost words means a lost account.';

  @override
  String get seedSavedCheckbox => 'I saved my words somewhere safe';

  @override
  String get verifyTitle => 'Check your phrase';

  @override
  String verifyPrompt(int number) {
    return 'Which one is word #$number?';
  }

  @override
  String verifyProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get verifyWrong => 'Not quite. Check your saved words.';

  @override
  String get verifyShowAgain => 'Show my words again';

  @override
  String get restoreTitle => 'Restore';

  @override
  String get restoreIntro =>
      'Type or paste your 12 or 24 recovery words, separated by spaces.';

  @override
  String restoreWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String restoreUnknownWord(String word) {
    return 'Unknown word: $word';
  }

  @override
  String get restoreInvalid =>
      'These words don\'t form a valid phrase. Check the order and spelling.';

  @override
  String get restoreAction => 'Restore my account';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name';
  }

  @override
  String get homeYourId => 'YOUR ID';

  @override
  String get homeComingSoon => 'Conversations are coming soon.';

  @override
  String get panicTooltip => 'Panic button';

  @override
  String get panicTitle => 'Erase everything';

  @override
  String get panicBody =>
      'Deletes your messages, contacts and keys from this phone, asks relays to delete what they hold for you, and logs you out. To come back you will need your recovery phrase.';

  @override
  String get panicHold => 'Hold to erase';

  @override
  String get panicHolding => 'Keep holding…';

  @override
  String relayOnline(int count, int total) {
    return 'Connected · $count/$total';
  }

  @override
  String get relayConnecting => 'Connecting…';

  @override
  String get relayOffline => 'Offline · retrying';

  @override
  String get relaysTitle => 'Relays';

  @override
  String get relaysIntro =>
      'Your messages travel through these relays. They can\'t read them or see who sent them, but a relay can see your IP address.';

  @override
  String get relayUp => 'Connected';

  @override
  String get relayDown => 'Unreachable';

  @override
  String get relaysRetry => 'Retry now';

  @override
  String get homeEmptyTitle => 'No conversations yet';

  @override
  String get homeEmptyBody =>
      'Share your ID so people can write to you, or paste someone\'s ID to start.';

  @override
  String get newChat => 'New chat';

  @override
  String get myId => 'My ID';

  @override
  String get myIdBody =>
      'Share it so people can write to you. It reveals nothing about who you are.';

  @override
  String get copyId => 'Copy ID';

  @override
  String get idCopied => 'ID copied';

  @override
  String get newChatHint => 'Paste an ID (npub…)';

  @override
  String get newChatInvalid =>
      'This isn\'t a valid ID. Check it was copied entirely.';

  @override
  String get newChatSelf => 'That\'s your own ID.';

  @override
  String get newChatStart => 'Start chatting';

  @override
  String get chatInputHint => 'Message';

  @override
  String get chatSend => 'Send';

  @override
  String chatEmpty(String name) {
    return 'Messages are end-to-end encrypted. Only $name can read them.';
  }

  @override
  String get chatEncrypted => 'End-to-end encrypted';

  @override
  String get messageFailed => 'Not sent · tap to retry';

  @override
  String youPrefix(String text) {
    return 'You: $text';
  }

  @override
  String get paste => 'Paste';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get sectionNetwork => 'NETWORK';

  @override
  String get relaysManage => 'Relays';

  @override
  String get relayAddHint => 'wss://relay.example';

  @override
  String get relayAdd => 'Add';

  @override
  String get relayInvalid => 'Only secure wss:// addresses are accepted.';

  @override
  String get relayRemove => 'Remove';

  @override
  String get relayKeepOne => 'Keep at least one relay.';

  @override
  String get sectionParanoia => 'PARANOIA MODE';

  @override
  String get paranoiaMaster => 'Paranoia mode';

  @override
  String get paranoiaMasterBody =>
      'Maximum protection against spyware and hostile keyboards. Less convenient.';

  @override
  String get paranoiaKeyboard => 'Whisper keyboard';

  @override
  String get paranoiaKeyboardBody =>
      'Type with Whisper\'s own keyboard: your phone\'s keyboard never sees what you write.';

  @override
  String get paranoiaShuffle => 'Shuffle keys';

  @override
  String get paranoiaShuffleBody =>
      'Letters move each time the keyboard opens, so recorded touches reveal nothing.';

  @override
  String get paranoiaMask => 'Hide what I type';

  @override
  String get paranoiaMaskBody =>
      'Shows •••• instead of the text you are writing.';

  @override
  String get paranoiaBlur => 'Blur messages';

  @override
  String get paranoiaBlurBody =>
      'Messages stay blurred until you press and hold them.';

  @override
  String get paranoiaA11y => 'Hide from accessibility services';

  @override
  String get paranoiaA11yBody =>
      'Spyware often reads screens through accessibility. This also blocks screen readers (TalkBack).';

  @override
  String get paranoiaSecure => 'Block screenshots everywhere';

  @override
  String get paranoiaSecureBody =>
      'Screenshots, screen recording and the app preview in recent apps show a black screen.';

  @override
  String get paranoiaLimits =>
      'No app can protect a fully compromised phone (rooted, or spyware with system access). Paranoia mode stops the common cases.';

  @override
  String get a11yWarningTitle => 'Apps that can read your screen';

  @override
  String get a11yWarningBody =>
      'These apps have accessibility access and could read what is displayed:';

  @override
  String get a11yWarningAction => 'Review in system settings';

  @override
  String get sectionDanger => 'DANGER ZONE';

  @override
  String get chatHoldToRead => 'Hold to read';

  @override
  String get keyboardSpace => 'space';

  @override
  String get requestsTitle => 'Requests';

  @override
  String requestsRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count message requests',
      one: '1 message request',
    );
    return '$_temp0';
  }

  @override
  String get requestsEmpty => 'No pending requests.';

  @override
  String requestBanner(String name) {
    return '$name wants to chat with you. They see nothing about you, not even your photo, until you accept.';
  }

  @override
  String get requestAccept => 'Accept';

  @override
  String get requestRefuse => 'Refuse';

  @override
  String get requestBlock => 'Block';

  @override
  String requestBlocked(String name) {
    return '$name is blocked.';
  }

  @override
  String get sectionProfile => 'PROFILE';

  @override
  String get photoFromGallery => 'Choose photo';

  @override
  String get photoFromCamera => 'Take photo';

  @override
  String get photoRemove => 'Remove';

  @override
  String get photoPrivacy =>
      'Only contacts you accepted get it, end-to-end encrypted. Location and camera details are removed from the photo.';

  @override
  String get photoError => 'This image can\'t be used. Try another one.';

  @override
  String get chatMenu => 'More';

  @override
  String blockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockConfirmBody =>
      'This conversation will be deleted from this phone and nothing they send will reach you. They won\'t be notified.';

  @override
  String get cancel => 'Cancel';

  @override
  String get blockedPeople => 'Blocked people';

  @override
  String get blockedEmpty => 'Nobody is blocked.';

  @override
  String get unblock => 'Unblock';

  @override
  String get attach => 'Send a photo';

  @override
  String get imagePreviewTitle => 'Send this photo?';

  @override
  String get imageAnonymized =>
      'Location, camera details and date have been removed. The photo was resized.';

  @override
  String get imageSend => 'Send';

  @override
  String get photoPreview => '📷 Photo';

  @override
  String get imagePendingRequest =>
      'Photo hidden until you accept this request';

  @override
  String get imageUnavailable => 'Photo unavailable';

  @override
  String get lockTitle => 'Whisper is locked';

  @override
  String get lockEnterPin => 'Enter your PIN';

  @override
  String get lockWrongPin => 'Wrong PIN';

  @override
  String lockRetryIn(int seconds) {
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  String get lockBiometric => 'Unlock with fingerprint or face';

  @override
  String get lockBiometricPrompt => 'Unlock Whisper';

  @override
  String get lockNow => 'Lock now';

  @override
  String get lockChecking => 'Checking…';

  @override
  String get sectionAppLock => 'APP LOCK';

  @override
  String get appLockSetup => 'Protect with a PIN';

  @override
  String get appLockSetupBody =>
      'Your account key is encrypted with your PIN. Without it, nothing opens, even with the phone in hand.';

  @override
  String get appLockBiometrics => 'Fingerprint or face';

  @override
  String get appLockBiometricsBody =>
      'Uses the phone\'s secure biometrics. Adding a new fingerprint turns it off: your PIN will be asked.';

  @override
  String get appLockChangePin => 'Change PIN';

  @override
  String get appLockAutoLock => 'Lock automatically';

  @override
  String get autoLockImmediately => 'Immediately';

  @override
  String get autoLockMinute => 'After 1 min';

  @override
  String get autoLockFiveMinutes => 'After 5 min';

  @override
  String get appLockDuress => 'Duress PIN';

  @override
  String get appLockDuressBody =>
      'A second PIN. Typed on the lock screen, it silently erases everything and opens an empty app.';

  @override
  String get appLockDuressSet => 'Set a duress PIN';

  @override
  String get appLockDuressRemove => 'Remove duress PIN';

  @override
  String get appLockTurnOff => 'Turn off app lock';

  @override
  String get pinNewTitle => 'Choose a PIN';

  @override
  String get pinConfirmTitle => 'Confirm your PIN';

  @override
  String get pinCurrentTitle => 'Current PIN';

  @override
  String get pinDuressTitle => 'Choose a duress PIN';

  @override
  String get pinRules => '6 to 12 digits. Avoid 123456 or repeated digits.';

  @override
  String get pinWeak => 'Too easy to guess. Pick another one.';

  @override
  String get pinMismatch => 'PINs don\'t match. Try again.';

  @override
  String get pinSameAsReal => 'Must be different from your PIN.';

  @override
  String get pinEncrypting => 'Encrypting your keys…';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out of this phone?';

  @override
  String get signOutBody =>
      'Your messages, contacts and keys will be erased from this phone. To come back you will need your recovery phrase.';

  @override
  String get biometricCancel => 'Use PIN';

  @override
  String get relayTorStarting => 'Starting Tor…';

  @override
  String get relayTorFailed => 'Tor unreachable · retrying';

  @override
  String get relaysIntroTor =>
      'Your connection goes through Tor: relays can\'t see your IP address, and they can\'t read your messages or see who sent them.';

  @override
  String get torToggle => 'Route through Tor (recommended)';

  @override
  String get torToggleBody =>
      'Hides your IP address from relays and helps get through censorship. Connecting takes a few more seconds.';

  @override
  String get torOffWarning =>
      'Without Tor, relays and your network provider can see that you use Whisper and your IP address.';

  @override
  String get scanQr => 'Scan a QR code';

  @override
  String get scanHint => 'Point the camera at a Whisper QR code';

  @override
  String get scanInvalid => 'This QR code is not a Whisper ID.';

  @override
  String get myIdQrHint => 'Let a friend scan this code to write to you.';

  @override
  String get safetyNumber => 'Verify safety number';

  @override
  String safetyNumberBody(String name) {
    return 'Compare these numbers with $name, in person or on a call. If they match on both phones, nobody is intercepting your conversation.';
  }

  @override
  String get safetyMarkVerified => 'Mark as verified';

  @override
  String get verified => 'Verified';

  @override
  String get rename => 'Rename';

  @override
  String get renameHint => 'Nickname (only on this phone)';

  @override
  String get save => 'Save';

  @override
  String get vaultErrorTitle => 'Secure storage unavailable';

  @override
  String get vaultErrorBody =>
      'Your phone\'s secure storage didn\'t respond. Nothing was deleted. Close Whisper and open it again; if it persists, restart your phone.';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String groupPickMembers(int max) {
    return 'Members (up to $max)';
  }

  @override
  String get groupNoContacts =>
      'Add contacts first: only people you\'ve accepted can be invited.';

  @override
  String get groupCreate => 'Create';

  @override
  String groupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get groupEmpty =>
      'Messages are end-to-end encrypted, sent separately to each member. No server knows this group exists.';

  @override
  String get groupInfo => 'Group info';

  @override
  String get groupAdmin => 'Admin';

  @override
  String get groupYou => 'You';

  @override
  String get groupRename => 'Rename group';

  @override
  String get groupAddMembers => 'Add members';

  @override
  String get groupRemoveMember => 'Remove from group';

  @override
  String get groupLeave => 'Leave group';

  @override
  String groupLeaveConfirm(String name) {
    return 'Leave “$name”? Its messages will be deleted from this phone.';
  }

  @override
  String get groupRemoved => 'You\'re no longer a member of this group.';

  @override
  String groupInvite(String name) {
    return '$name invited you to this group. Refusing tells no one.';
  }

  @override
  String get groupInviteRow => 'Group invitation';

  @override
  String get groupNoAdminLeave =>
      'As admin, you can\'t leave. Remove the members instead.';

  @override
  String groupNamePrefix(String name, String text) {
    return '$name: $text';
  }

  @override
  String get newChannel => 'New channel';

  @override
  String get joinChannel => 'Join a channel';

  @override
  String get channelName => 'Channel name';

  @override
  String get channelAbout => 'Description (optional)';

  @override
  String get channelPublic => 'Public';

  @override
  String get channelPublicBody =>
      'Anyone with the invite link or QR can follow and share it.';

  @override
  String get channelPrivate => 'Private';

  @override
  String get channelPrivateBody =>
      'You invite contacts yourself. Followers get no share button.';

  @override
  String get channelCreate => 'Create channel';

  @override
  String get channelEmptyAdmin =>
      'Only you can post here. Followers can react, anonymously.';

  @override
  String get channelEmptyViewer => 'No posts yet.';

  @override
  String get channelBadge => 'Channel';

  @override
  String get channelFollowers =>
      'Only the admin posts · reactions are anonymous';

  @override
  String get channelInfo => 'Channel info';

  @override
  String get channelInvite => 'Invite';

  @override
  String get channelInviteBody =>
      'Scan or share this code to follow the channel. It contains the key to read it: share it only where you want.';

  @override
  String get channelInviteCopied => 'Invite copied';

  @override
  String get channelCopyInvite => 'Copy invite';

  @override
  String get channelInviteContacts => 'Invite contacts';

  @override
  String get channelInvitesSent => 'Invitations sent';

  @override
  String get channelLeave => 'Leave channel';

  @override
  String channelLeaveConfirm(String name) {
    return 'Leave “$name”? Its posts will be deleted from this phone. The admin won\'t know.';
  }

  @override
  String channelInviteFrom(String name) {
    return '$name invited you to follow this channel.';
  }

  @override
  String get channelInviteRow => 'Channel invitation';

  @override
  String get channelJoinHint => 'Paste an invite (whisper-channel:…)';

  @override
  String get channelJoinInvalid => 'This isn\'t a valid channel invite.';

  @override
  String get channelJoin => 'Follow';

  @override
  String get channelEdit => 'Edit channel';

  @override
  String get channelReact => 'React';

  @override
  String get channelPostHint => 'Post to your followers';

  @override
  String get channelAdminNote =>
      'Your channel\'s key comes from your identity: restoring your recovery phrase gives it back.';

  @override
  String get relayTorDisguising => 'Starting a disguised connection…';

  @override
  String get connProtected => 'Protected connection';

  @override
  String get connDisguised => 'Disguised connection';

  @override
  String get connProtectedBody =>
      'Through Tor: relays can\'t see your IP address.';

  @override
  String get connDisguisedBody =>
      'Through Tor, disguised as ordinary traffic: your network can\'t tell you use Tor.';

  @override
  String get torDisguise => 'Disguise my connection';

  @override
  String get torDisguiseBody =>
      'For places where using Tor itself is risky. Your traffic looks like random data or a video call. Slower to connect. Whisper switches on its own when Tor is blocked.';

  @override
  String get bgConnectionTitle => 'Private connection active';

  @override
  String get bgConnectionText => 'Whisper can receive your messages.';

  @override
  String notifyNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: 'New message',
    );
    return '$_temp0';
  }

  @override
  String get bgToggle => 'Receive in the background';

  @override
  String get bgToggleBody =>
      'Keeps a private connection open when Whisper is closed, with a permanent notification. Alerts never show who wrote or what. Uses more battery. No Google service involved.';

  @override
  String get sectionBackup => 'BACKUP';

  @override
  String get backupExport => 'Export history';

  @override
  String get backupExportBody =>
      'Saves an encrypted file. Only your recovery phrase can open it, on any phone.';

  @override
  String get backupImport => 'Import history';

  @override
  String get backupImportBody =>
      'Adds the conversations of a backup made with this account. Nothing here is overwritten.';

  @override
  String get backupWorking => 'Preparing the encrypted backup…';

  @override
  String get backupSaved => 'Encrypted backup saved';

  @override
  String backupImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items restored',
      one: '1 item restored',
      zero: 'Nothing new in this backup',
    );
    return '$_temp0';
  }

  @override
  String get backupWrongKey =>
      'This backup belongs to another account, or is damaged.';

  @override
  String get backupBadFile => 'This isn\'t a Whisper backup.';

  @override
  String get backupNewer =>
      'This backup was made by a newer version of Whisper.';

  @override
  String get backupFailed => 'Couldn\'t read or write the file.';

  @override
  String get searchHint => 'Search';

  @override
  String get searchNoResults => 'No results';

  @override
  String get filterAll => 'All';

  @override
  String get filterChats => 'Chats';

  @override
  String get filterGroups => 'Groups';

  @override
  String get filterChannels => 'Channels';

  @override
  String get filterEmpty => 'Nothing here yet';

  @override
  String get newChatSubtitle => 'Write to someone with their ID';

  @override
  String get newGroupSubtitle => 'Private, end-to-end encrypted';

  @override
  String get newChannelSubtitle => 'Broadcast to many people';

  @override
  String get joinChannelSubtitle => 'Scan or paste an invite';

  @override
  String get startSomething => 'Start';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get nicknameTitle => 'Nickname';

  @override
  String get nicknameHint => 'Your nickname';

  @override
  String nicknameBody(String username) {
    return 'Only contacts you accepted see it, end-to-end encrypted. Leave empty to go by $username.';
  }

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableBody(String version) {
    return 'Whisper $version is ready to install.';
  }

  @override
  String updateBanner(String version) {
    return 'Whisper $version is available';
  }

  @override
  String get updateSheetBody =>
      'Downloaded through Tor from Whisper\'s GitHub releases, then checked before installing: same signing key as this app, and a newer version.';

  @override
  String get updateInstall => 'Download and install';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateInstalling => 'Installing…';

  @override
  String get updateFailedNetwork => 'Couldn\'t reach GitHub. Try again later.';

  @override
  String get updateFailedChecksum =>
      'The download was damaged. It was deleted; try again.';

  @override
  String get updateFailedSignature =>
      'This file isn\'t signed with Whisper\'s key. It was not installed.';

  @override
  String get updateFailedPermission =>
      'Allow Whisper to install updates, then come back and tap again.';

  @override
  String get updateFailedInstall =>
      'Android didn\'t install the update. Try again later.';

  @override
  String get sectionAbout => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get updateAutoCheck => 'Check for updates';

  @override
  String get updateAutoCheckBody =>
      'About once a day, through Tor: GitHub only sees a Tor exit.';

  @override
  String get updateCheckNow => 'Check now';

  @override
  String get updateUpToDate => 'You have the latest version.';

  @override
  String get updateStoreManaged =>
      'Updates come from the store you installed Whisper from.';

  @override
  String get paranoiaSecureIos => 'Hide the screen when recorded';

  @override
  String get paranoiaSecureBodyIos =>
      'iPhone can\'t block screenshots. Whisper hides its screen while it\'s recorded or mirrored, and in the app switcher.';

  @override
  String get iosBackgroundNote =>
      'On iPhone, messages arrive while Whisper is open: iOS doesn\'t let apps keep a private connection in the background. Relays keep messages for at least two days.';

  @override
  String get updateViaTor => 'Download through Tor';

  @override
  String get updateViaTorBody =>
      'Slower, but nobody can see this phone fetching Whisper.';

  @override
  String get updateDirectWarning =>
      'Faster, but your internet provider and GitHub will see this phone downloading Whisper. Avoid it where Whisper or Tor is watched. The file is verified the same way.';
}
