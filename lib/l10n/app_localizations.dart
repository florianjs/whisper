import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Whisper'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Talk freely. No number, no name, no trace.'**
  String get appTagline;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @welcomeCreate.
  ///
  /// In en, this message translates to:
  /// **'Create my identity'**
  String get welcomeCreate;

  /// No description provided for @welcomeRestore.
  ///
  /// In en, this message translates to:
  /// **'I have a recovery phrase'**
  String get welcomeRestore;

  /// No description provided for @welcomeFootnote.
  ///
  /// In en, this message translates to:
  /// **'No phone number. No email. Your keys never leave this phone.'**
  String get welcomeFootnote;

  /// No description provided for @createGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating your keys…'**
  String get createGenerating;

  /// No description provided for @createUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'YOU ARE'**
  String get createUsernameLabel;

  /// No description provided for @createUsernameCaption.
  ///
  /// In en, this message translates to:
  /// **'Derived from your key. Nobody picked it, nobody can link it to you.'**
  String get createUsernameCaption;

  /// No description provided for @seedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase'**
  String get seedTitle;

  /// No description provided for @seedIntro.
  ///
  /// In en, this message translates to:
  /// **'These words are the only way to get your account back. Whisper does not keep them: this is the only time you will see them. Save them in a password manager (Bitwarden, 1Password…) or on paper.'**
  String get seedIntro;

  /// No description provided for @seedRevealHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to reveal. Make sure nobody is watching.'**
  String get seedRevealHint;

  /// No description provided for @seedCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get seedCopy;

  /// No description provided for @seedCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied. The clipboard will be cleared in 60 s.'**
  String get seedCopied;

  /// No description provided for @seedWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone with these words becomes you. Nobody can reset them: lost words means a lost account.'**
  String get seedWarning;

  /// No description provided for @seedSavedCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I saved my words somewhere safe'**
  String get seedSavedCheckbox;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your phrase'**
  String get verifyTitle;

  /// No description provided for @verifyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Which one is word #{number}?'**
  String verifyPrompt(int number);

  /// No description provided for @verifyProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String verifyProgress(int done, int total);

  /// No description provided for @verifyWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Check your saved words.'**
  String get verifyWrong;

  /// No description provided for @verifyShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Show my words again'**
  String get verifyShowAgain;

  /// No description provided for @restoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreTitle;

  /// No description provided for @restoreIntro.
  ///
  /// In en, this message translates to:
  /// **'Type or paste your 12 or 24 recovery words, separated by spaces.'**
  String get restoreIntro;

  /// No description provided for @restoreWordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String restoreWordCount(int count);

  /// No description provided for @restoreUnknownWord.
  ///
  /// In en, this message translates to:
  /// **'Unknown word: {word}'**
  String restoreUnknownWord(String word);

  /// No description provided for @restoreInvalid.
  ///
  /// In en, this message translates to:
  /// **'These words don\'t form a valid phrase. Check the order and spelling.'**
  String get restoreInvalid;

  /// No description provided for @restoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore my account'**
  String get restoreAction;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeYourId.
  ///
  /// In en, this message translates to:
  /// **'YOUR ID'**
  String get homeYourId;

  /// No description provided for @homeComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Conversations are coming soon.'**
  String get homeComingSoon;

  /// No description provided for @panicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Panic button'**
  String get panicTooltip;

  /// No description provided for @panicTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase everything'**
  String get panicTitle;

  /// No description provided for @panicBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes your messages, contacts and keys from this phone, asks relays to delete what they hold for you, and logs you out. To come back you will need your recovery phrase.'**
  String get panicBody;

  /// No description provided for @panicHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to erase'**
  String get panicHold;

  /// No description provided for @panicHolding.
  ///
  /// In en, this message translates to:
  /// **'Keep holding…'**
  String get panicHolding;

  /// No description provided for @relayOnline.
  ///
  /// In en, this message translates to:
  /// **'Connected · {count}/{total}'**
  String relayOnline(int count, int total);

  /// No description provided for @relayConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get relayConnecting;

  /// No description provided for @relayOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline · retrying'**
  String get relayOffline;

  /// No description provided for @relaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Relays'**
  String get relaysTitle;

  /// No description provided for @relaysIntro.
  ///
  /// In en, this message translates to:
  /// **'Your messages travel through these relays. They can\'t read them or see who sent them, but a relay can see your IP address.'**
  String get relaysIntro;

  /// No description provided for @relayUp.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get relayUp;

  /// No description provided for @relayDown.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get relayDown;

  /// No description provided for @relaysRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get relaysRetry;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Share your ID so people can write to you, or paste someone\'s ID to start.'**
  String get homeEmptyBody;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @myId.
  ///
  /// In en, this message translates to:
  /// **'My ID'**
  String get myId;

  /// No description provided for @myIdBody.
  ///
  /// In en, this message translates to:
  /// **'Share it so people can write to you. It reveals nothing about who you are.'**
  String get myIdBody;

  /// No description provided for @copyId.
  ///
  /// In en, this message translates to:
  /// **'Copy ID'**
  String get copyId;

  /// No description provided for @idCopied.
  ///
  /// In en, this message translates to:
  /// **'ID copied'**
  String get idCopied;

  /// No description provided for @newChatHint.
  ///
  /// In en, this message translates to:
  /// **'Paste an ID (npub…)'**
  String get newChatHint;

  /// No description provided for @newChatInvalid.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a valid ID. Check it was copied entirely.'**
  String get newChatInvalid;

  /// No description provided for @newChatSelf.
  ///
  /// In en, this message translates to:
  /// **'That\'s your own ID.'**
  String get newChatSelf;

  /// No description provided for @newChatStart.
  ///
  /// In en, this message translates to:
  /// **'Start chatting'**
  String get newChatStart;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Messages are end-to-end encrypted. Only {name} can read them.'**
  String chatEmpty(String name);

  /// No description provided for @chatEncrypted.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get chatEncrypted;

  /// No description provided for @messageFailed.
  ///
  /// In en, this message translates to:
  /// **'Not sent · tap to retry'**
  String get messageFailed;

  /// No description provided for @youPrefix.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String youPrefix(String text);

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @sectionNetwork.
  ///
  /// In en, this message translates to:
  /// **'NETWORK'**
  String get sectionNetwork;

  /// No description provided for @relaysManage.
  ///
  /// In en, this message translates to:
  /// **'Relays'**
  String get relaysManage;

  /// No description provided for @relayAddHint.
  ///
  /// In en, this message translates to:
  /// **'wss://relay.example'**
  String get relayAddHint;

  /// No description provided for @relayAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get relayAdd;

  /// No description provided for @relayInvalid.
  ///
  /// In en, this message translates to:
  /// **'Only secure wss:// addresses are accepted.'**
  String get relayInvalid;

  /// No description provided for @relayRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get relayRemove;

  /// No description provided for @relayKeepOne.
  ///
  /// In en, this message translates to:
  /// **'Keep at least one relay.'**
  String get relayKeepOne;

  /// No description provided for @sectionParanoia.
  ///
  /// In en, this message translates to:
  /// **'PARANOIA MODE'**
  String get sectionParanoia;

  /// No description provided for @paranoiaMaster.
  ///
  /// In en, this message translates to:
  /// **'Paranoia mode'**
  String get paranoiaMaster;

  /// No description provided for @paranoiaMasterBody.
  ///
  /// In en, this message translates to:
  /// **'Maximum protection against spyware and hostile keyboards. Less convenient.'**
  String get paranoiaMasterBody;

  /// No description provided for @paranoiaKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Whisper keyboard'**
  String get paranoiaKeyboard;

  /// No description provided for @paranoiaKeyboardBody.
  ///
  /// In en, this message translates to:
  /// **'Type with Whisper\'s own keyboard: your phone\'s keyboard never sees what you write.'**
  String get paranoiaKeyboardBody;

  /// No description provided for @paranoiaShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle keys'**
  String get paranoiaShuffle;

  /// No description provided for @paranoiaShuffleBody.
  ///
  /// In en, this message translates to:
  /// **'Letters move each time the keyboard opens, so recorded touches reveal nothing.'**
  String get paranoiaShuffleBody;

  /// No description provided for @paranoiaMask.
  ///
  /// In en, this message translates to:
  /// **'Hide what I type'**
  String get paranoiaMask;

  /// No description provided for @paranoiaMaskBody.
  ///
  /// In en, this message translates to:
  /// **'Shows •••• instead of the text you are writing.'**
  String get paranoiaMaskBody;

  /// No description provided for @paranoiaBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur messages'**
  String get paranoiaBlur;

  /// No description provided for @paranoiaBlurBody.
  ///
  /// In en, this message translates to:
  /// **'Messages stay blurred until you press and hold them.'**
  String get paranoiaBlurBody;

  /// No description provided for @paranoiaA11y.
  ///
  /// In en, this message translates to:
  /// **'Hide from accessibility services'**
  String get paranoiaA11y;

  /// No description provided for @paranoiaA11yBody.
  ///
  /// In en, this message translates to:
  /// **'Spyware often reads screens through accessibility. This also blocks screen readers (TalkBack).'**
  String get paranoiaA11yBody;

  /// No description provided for @paranoiaSecure.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots everywhere'**
  String get paranoiaSecure;

  /// No description provided for @paranoiaSecureBody.
  ///
  /// In en, this message translates to:
  /// **'Screenshots, screen recording and the app preview in recent apps show a black screen.'**
  String get paranoiaSecureBody;

  /// No description provided for @paranoiaLimits.
  ///
  /// In en, this message translates to:
  /// **'No app can protect a fully compromised phone (rooted, or spyware with system access). Paranoia mode stops the common cases.'**
  String get paranoiaLimits;

  /// No description provided for @a11yWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Apps that can read your screen'**
  String get a11yWarningTitle;

  /// No description provided for @a11yWarningBody.
  ///
  /// In en, this message translates to:
  /// **'These apps have accessibility access and could read what is displayed:'**
  String get a11yWarningBody;

  /// No description provided for @a11yWarningAction.
  ///
  /// In en, this message translates to:
  /// **'Review in system settings'**
  String get a11yWarningAction;

  /// No description provided for @sectionDanger.
  ///
  /// In en, this message translates to:
  /// **'DANGER ZONE'**
  String get sectionDanger;

  /// No description provided for @chatHoldToRead.
  ///
  /// In en, this message translates to:
  /// **'Hold to read'**
  String get chatHoldToRead;

  /// No description provided for @keyboardSpace.
  ///
  /// In en, this message translates to:
  /// **'space'**
  String get keyboardSpace;

  /// No description provided for @requestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requestsTitle;

  /// No description provided for @requestsRow.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message request} other{{count} message requests}}'**
  String requestsRow(int count);

  /// No description provided for @requestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending requests.'**
  String get requestsEmpty;

  /// No description provided for @requestBanner.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to chat with you. They see nothing about you, not even your photo, until you accept.'**
  String requestBanner(String name);

  /// No description provided for @requestAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get requestAccept;

  /// No description provided for @requestRefuse.
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get requestRefuse;

  /// No description provided for @requestBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get requestBlock;

  /// No description provided for @requestBlocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked.'**
  String requestBlocked(String name);

  /// No description provided for @sectionProfile.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get sectionProfile;

  /// No description provided for @photoFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get photoFromGallery;

  /// No description provided for @photoFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoFromCamera;

  /// No description provided for @photoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get photoRemove;

  /// No description provided for @photoPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only contacts you accepted get it, end-to-end encrypted. Location and camera details are removed from the photo.'**
  String get photoPrivacy;

  /// No description provided for @photoError.
  ///
  /// In en, this message translates to:
  /// **'This image can\'t be used. Try another one.'**
  String get photoError;

  /// No description provided for @chatMenu.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatMenu;

  /// No description provided for @blockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockConfirmTitle(String name);

  /// No description provided for @blockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This conversation will be deleted from this phone and nothing they send will reach you. They won\'t be notified.'**
  String get blockConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @blockedPeople.
  ///
  /// In en, this message translates to:
  /// **'Blocked people'**
  String get blockedPeople;

  /// No description provided for @blockedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nobody is blocked.'**
  String get blockedEmpty;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Send a photo'**
  String get attach;

  /// No description provided for @imagePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Send this photo?'**
  String get imagePreviewTitle;

  /// No description provided for @imageAnonymized.
  ///
  /// In en, this message translates to:
  /// **'Location, camera details and date have been removed. The photo was resized.'**
  String get imageAnonymized;

  /// No description provided for @imageSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get imageSend;

  /// No description provided for @photoPreview.
  ///
  /// In en, this message translates to:
  /// **'📷 Photo'**
  String get photoPreview;

  /// No description provided for @imagePendingRequest.
  ///
  /// In en, this message translates to:
  /// **'Photo hidden until you accept this request'**
  String get imagePendingRequest;

  /// No description provided for @imageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get imageUnavailable;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Whisper is locked'**
  String get lockTitle;

  /// No description provided for @lockEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get lockEnterPin;

  /// No description provided for @lockWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get lockWrongPin;

  /// No description provided for @lockRetryIn.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} s.'**
  String lockRetryIn(int seconds);

  /// No description provided for @lockBiometric.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint or face'**
  String get lockBiometric;

  /// No description provided for @lockBiometricPrompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock Whisper'**
  String get lockBiometricPrompt;

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// No description provided for @lockChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get lockChecking;

  /// No description provided for @sectionAppLock.
  ///
  /// In en, this message translates to:
  /// **'APP LOCK'**
  String get sectionAppLock;

  /// No description provided for @appLockSetup.
  ///
  /// In en, this message translates to:
  /// **'Protect with a PIN'**
  String get appLockSetup;

  /// No description provided for @appLockSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Your account key is encrypted with your PIN. Without it, nothing opens, even with the phone in hand.'**
  String get appLockSetupBody;

  /// No description provided for @appLockBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint or face'**
  String get appLockBiometrics;

  /// No description provided for @appLockBiometricsBody.
  ///
  /// In en, this message translates to:
  /// **'Uses the phone\'s secure biometrics. Adding a new fingerprint turns it off: your PIN will be asked.'**
  String get appLockBiometricsBody;

  /// No description provided for @appLockChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get appLockChangePin;

  /// No description provided for @appLockAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Lock automatically'**
  String get appLockAutoLock;

  /// No description provided for @autoLockImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get autoLockImmediately;

  /// No description provided for @autoLockMinute.
  ///
  /// In en, this message translates to:
  /// **'After 1 min'**
  String get autoLockMinute;

  /// No description provided for @autoLockFiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'After 5 min'**
  String get autoLockFiveMinutes;

  /// No description provided for @appLockDuress.
  ///
  /// In en, this message translates to:
  /// **'Duress PIN'**
  String get appLockDuress;

  /// No description provided for @appLockDuressBody.
  ///
  /// In en, this message translates to:
  /// **'A second PIN. Typed on the lock screen, it silently erases everything and opens an empty app.'**
  String get appLockDuressBody;

  /// No description provided for @appLockDuressSet.
  ///
  /// In en, this message translates to:
  /// **'Set a duress PIN'**
  String get appLockDuressSet;

  /// No description provided for @appLockDuressRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove duress PIN'**
  String get appLockDuressRemove;

  /// No description provided for @appLockTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off app lock'**
  String get appLockTurnOff;

  /// No description provided for @pinNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN'**
  String get pinNewTitle;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get pinConfirmTitle;

  /// No description provided for @pinCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get pinCurrentTitle;

  /// No description provided for @pinDuressTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a duress PIN'**
  String get pinDuressTitle;

  /// No description provided for @pinRules.
  ///
  /// In en, this message translates to:
  /// **'6 to 12 digits. Avoid 123456 or repeated digits.'**
  String get pinRules;

  /// No description provided for @pinWeak.
  ///
  /// In en, this message translates to:
  /// **'Too easy to guess. Pick another one.'**
  String get pinWeak;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match. Try again.'**
  String get pinMismatch;

  /// No description provided for @pinSameAsReal.
  ///
  /// In en, this message translates to:
  /// **'Must be different from your PIN.'**
  String get pinSameAsReal;

  /// No description provided for @pinEncrypting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting your keys…'**
  String get pinEncrypting;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of this phone?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your messages, contacts and keys will be erased from this phone. To come back you will need your recovery phrase.'**
  String get signOutBody;

  /// No description provided for @biometricCancel.
  ///
  /// In en, this message translates to:
  /// **'Use PIN'**
  String get biometricCancel;

  /// No description provided for @relayTorStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting Tor…'**
  String get relayTorStarting;

  /// No description provided for @relayTorFailed.
  ///
  /// In en, this message translates to:
  /// **'Tor unreachable · retrying'**
  String get relayTorFailed;

  /// No description provided for @relaysIntroTor.
  ///
  /// In en, this message translates to:
  /// **'Your connection goes through Tor: relays can\'t see your IP address, and they can\'t read your messages or see who sent them.'**
  String get relaysIntroTor;

  /// No description provided for @torToggle.
  ///
  /// In en, this message translates to:
  /// **'Route through Tor (recommended)'**
  String get torToggle;

  /// No description provided for @torToggleBody.
  ///
  /// In en, this message translates to:
  /// **'Hides your IP address from relays and helps get through censorship. Connecting takes a few more seconds.'**
  String get torToggleBody;

  /// No description provided for @torOffWarning.
  ///
  /// In en, this message translates to:
  /// **'Without Tor, relays and your network provider can see that you use Whisper and your IP address.'**
  String get torOffWarning;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get scanQr;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a Whisper QR code'**
  String get scanHint;

  /// No description provided for @scanInvalid.
  ///
  /// In en, this message translates to:
  /// **'This QR code is not a Whisper ID.'**
  String get scanInvalid;

  /// No description provided for @myIdQrHint.
  ///
  /// In en, this message translates to:
  /// **'Let a friend scan this code to write to you.'**
  String get myIdQrHint;

  /// No description provided for @safetyNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify safety number'**
  String get safetyNumber;

  /// No description provided for @safetyNumberBody.
  ///
  /// In en, this message translates to:
  /// **'Compare these numbers with {name}, in person or on a call. If they match on both phones, nobody is intercepting your conversation.'**
  String safetyNumberBody(String name);

  /// No description provided for @safetyMarkVerified.
  ///
  /// In en, this message translates to:
  /// **'Mark as verified'**
  String get safetyMarkVerified;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameHint.
  ///
  /// In en, this message translates to:
  /// **'Nickname (only on this phone)'**
  String get renameHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @vaultErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure storage unavailable'**
  String get vaultErrorTitle;

  /// No description provided for @vaultErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s secure storage didn\'t respond. Nothing was deleted. Close Whisper and open it again; if it persists, restart your phone.'**
  String get vaultErrorBody;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupPickMembers.
  ///
  /// In en, this message translates to:
  /// **'Members (up to {max})'**
  String groupPickMembers(int max);

  /// No description provided for @groupNoContacts.
  ///
  /// In en, this message translates to:
  /// **'Add contacts first: only people you\'ve accepted can be invited.'**
  String get groupNoContacts;

  /// No description provided for @groupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get groupCreate;

  /// No description provided for @groupMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String groupMembers(int count);

  /// No description provided for @groupEmpty.
  ///
  /// In en, this message translates to:
  /// **'Messages are end-to-end encrypted, sent separately to each member. No server knows this group exists.'**
  String get groupEmpty;

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get groupInfo;

  /// No description provided for @groupAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get groupAdmin;

  /// No description provided for @groupYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get groupYou;

  /// No description provided for @groupRename.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get groupRename;

  /// No description provided for @groupAddMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get groupAddMembers;

  /// No description provided for @groupRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get groupRemoveMember;

  /// No description provided for @groupLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupLeave;

  /// No description provided for @groupLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave “{name}”? Its messages will be deleted from this phone.'**
  String groupLeaveConfirm(String name);

  /// No description provided for @groupRemoved.
  ///
  /// In en, this message translates to:
  /// **'You\'re no longer a member of this group.'**
  String get groupRemoved;

  /// No description provided for @groupInvite.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to this group. Refusing tells no one.'**
  String groupInvite(String name);

  /// No description provided for @groupInviteRow.
  ///
  /// In en, this message translates to:
  /// **'Group invitation'**
  String get groupInviteRow;

  /// No description provided for @groupNoAdminLeave.
  ///
  /// In en, this message translates to:
  /// **'As admin, you can\'t leave. Remove the members instead.'**
  String get groupNoAdminLeave;

  /// No description provided for @groupNamePrefix.
  ///
  /// In en, this message translates to:
  /// **'{name}: {text}'**
  String groupNamePrefix(String name, String text);

  /// No description provided for @newChannel.
  ///
  /// In en, this message translates to:
  /// **'New channel'**
  String get newChannel;

  /// No description provided for @joinChannel.
  ///
  /// In en, this message translates to:
  /// **'Join a channel'**
  String get joinChannel;

  /// No description provided for @channelName.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get channelName;

  /// No description provided for @channelAbout.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get channelAbout;

  /// No description provided for @channelPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get channelPublic;

  /// No description provided for @channelPublicBody.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the invite link or QR can follow and share it.'**
  String get channelPublicBody;

  /// No description provided for @channelPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get channelPrivate;

  /// No description provided for @channelPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'You invite contacts yourself. Followers get no share button.'**
  String get channelPrivateBody;

  /// No description provided for @channelCreate.
  ///
  /// In en, this message translates to:
  /// **'Create channel'**
  String get channelCreate;

  /// No description provided for @channelEmptyAdmin.
  ///
  /// In en, this message translates to:
  /// **'Only you can post here. Followers can react, anonymously.'**
  String get channelEmptyAdmin;

  /// No description provided for @channelEmptyViewer.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get channelEmptyViewer;

  /// No description provided for @channelBadge.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channelBadge;

  /// No description provided for @channelFollowers.
  ///
  /// In en, this message translates to:
  /// **'Only the admin posts · reactions are anonymous'**
  String get channelFollowers;

  /// No description provided for @channelInfo.
  ///
  /// In en, this message translates to:
  /// **'Channel info'**
  String get channelInfo;

  /// No description provided for @channelInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get channelInvite;

  /// No description provided for @channelInviteBody.
  ///
  /// In en, this message translates to:
  /// **'Scan or share this code to follow the channel. It contains the key to read it: share it only where you want.'**
  String get channelInviteBody;

  /// No description provided for @channelInviteCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite copied'**
  String get channelInviteCopied;

  /// No description provided for @channelCopyInvite.
  ///
  /// In en, this message translates to:
  /// **'Copy invite'**
  String get channelCopyInvite;

  /// No description provided for @channelInviteContacts.
  ///
  /// In en, this message translates to:
  /// **'Invite contacts'**
  String get channelInviteContacts;

  /// No description provided for @channelInvitesSent.
  ///
  /// In en, this message translates to:
  /// **'Invitations sent'**
  String get channelInvitesSent;

  /// No description provided for @channelLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave channel'**
  String get channelLeave;

  /// No description provided for @channelLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave “{name}”? Its posts will be deleted from this phone. The admin won\'t know.'**
  String channelLeaveConfirm(String name);

  /// No description provided for @channelInviteFrom.
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to follow this channel.'**
  String channelInviteFrom(String name);

  /// No description provided for @channelInviteRow.
  ///
  /// In en, this message translates to:
  /// **'Channel invitation'**
  String get channelInviteRow;

  /// No description provided for @channelJoinHint.
  ///
  /// In en, this message translates to:
  /// **'Paste an invite (whisper-channel:…)'**
  String get channelJoinHint;

  /// No description provided for @channelJoinInvalid.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a valid channel invite.'**
  String get channelJoinInvalid;

  /// No description provided for @channelJoin.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get channelJoin;

  /// No description provided for @channelEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit channel'**
  String get channelEdit;

  /// No description provided for @channelReact.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get channelReact;

  /// No description provided for @channelPostHint.
  ///
  /// In en, this message translates to:
  /// **'Post to your followers'**
  String get channelPostHint;

  /// No description provided for @channelAdminNote.
  ///
  /// In en, this message translates to:
  /// **'Your channel\'s key comes from your identity: restoring your recovery phrase gives it back.'**
  String get channelAdminNote;

  /// No description provided for @relayTorDisguising.
  ///
  /// In en, this message translates to:
  /// **'Starting a disguised connection…'**
  String get relayTorDisguising;

  /// No description provided for @connProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected connection'**
  String get connProtected;

  /// No description provided for @connDisguised.
  ///
  /// In en, this message translates to:
  /// **'Disguised connection'**
  String get connDisguised;

  /// No description provided for @connProtectedBody.
  ///
  /// In en, this message translates to:
  /// **'Through Tor: relays can\'t see your IP address.'**
  String get connProtectedBody;

  /// No description provided for @connDisguisedBody.
  ///
  /// In en, this message translates to:
  /// **'Through Tor, disguised as ordinary traffic: your network can\'t tell you use Tor.'**
  String get connDisguisedBody;

  /// No description provided for @torDisguise.
  ///
  /// In en, this message translates to:
  /// **'Disguise my connection'**
  String get torDisguise;

  /// No description provided for @torDisguiseBody.
  ///
  /// In en, this message translates to:
  /// **'For places where using Tor itself is risky. Your traffic looks like random data or a video call. Slower to connect. Whisper switches on its own when Tor is blocked.'**
  String get torDisguiseBody;

  /// No description provided for @bgConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Private connection active'**
  String get bgConnectionTitle;

  /// No description provided for @bgConnectionText.
  ///
  /// In en, this message translates to:
  /// **'Whisper can receive your messages.'**
  String get bgConnectionText;

  /// No description provided for @notifyNew.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{New message} other{{count} new messages}}'**
  String notifyNew(int count);

  /// No description provided for @bgToggle.
  ///
  /// In en, this message translates to:
  /// **'Receive in the background'**
  String get bgToggle;

  /// No description provided for @bgToggleBody.
  ///
  /// In en, this message translates to:
  /// **'Keeps a private connection open when Whisper is closed, with a permanent notification. Alerts never show who wrote or what. Uses more battery. No Google service involved.'**
  String get bgToggleBody;

  /// No description provided for @sectionBackup.
  ///
  /// In en, this message translates to:
  /// **'BACKUP'**
  String get sectionBackup;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export history'**
  String get backupExport;

  /// No description provided for @backupExportBody.
  ///
  /// In en, this message translates to:
  /// **'Saves an encrypted file. Only your recovery phrase can open it, on any phone.'**
  String get backupExportBody;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Import history'**
  String get backupImport;

  /// No description provided for @backupImportBody.
  ///
  /// In en, this message translates to:
  /// **'Adds the conversations of a backup made with this account. Nothing here is overwritten.'**
  String get backupImportBody;

  /// No description provided for @backupWorking.
  ///
  /// In en, this message translates to:
  /// **'Preparing the encrypted backup…'**
  String get backupWorking;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup saved'**
  String get backupSaved;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing new in this backup} =1{1 item restored} other{{count} items restored}}'**
  String backupImported(int count);

  /// No description provided for @backupWrongKey.
  ///
  /// In en, this message translates to:
  /// **'This backup belongs to another account, or is damaged.'**
  String get backupWrongKey;

  /// No description provided for @backupBadFile.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Whisper backup.'**
  String get backupBadFile;

  /// No description provided for @backupNewer.
  ///
  /// In en, this message translates to:
  /// **'This backup was made by a newer version of Whisper.'**
  String get backupNewer;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read or write the file.'**
  String get backupFailed;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchNoResults;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get filterChats;

  /// No description provided for @filterGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get filterGroups;

  /// No description provided for @filterChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get filterChannels;

  /// No description provided for @filterEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get filterEmpty;

  /// No description provided for @newChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write to someone with their ID'**
  String get newChatSubtitle;

  /// No description provided for @newGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Private, end-to-end encrypted'**
  String get newGroupSubtitle;

  /// No description provided for @newChannelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Broadcast to many people'**
  String get newChannelSubtitle;

  /// No description provided for @joinChannelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan or paste an invite'**
  String get joinChannelSubtitle;

  /// No description provided for @startSomething.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startSomething;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @nicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nicknameTitle;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Your nickname'**
  String get nicknameHint;

  /// No description provided for @nicknameBody.
  ///
  /// In en, this message translates to:
  /// **'Only contacts you accepted see it, end-to-end encrypted. Leave empty to go by {username}.'**
  String nicknameBody(String username);

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Whisper {version} is ready to install.'**
  String updateAvailableBody(String version);

  /// No description provided for @updateBanner.
  ///
  /// In en, this message translates to:
  /// **'Whisper {version} is available'**
  String updateBanner(String version);

  /// No description provided for @updateSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Downloaded through Tor from Whisper\'s GitHub releases, then checked before installing: same signing key as this app, and a newer version.'**
  String get updateSheetBody;

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get updateInstall;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get updateDownloading;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get updateInstalling;

  /// No description provided for @updateFailedNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach GitHub. Try again later.'**
  String get updateFailedNetwork;

  /// No description provided for @updateFailedChecksum.
  ///
  /// In en, this message translates to:
  /// **'The download was damaged. It was deleted; try again.'**
  String get updateFailedChecksum;

  /// No description provided for @updateFailedSignature.
  ///
  /// In en, this message translates to:
  /// **'This file isn\'t signed with Whisper\'s key. It was not installed.'**
  String get updateFailedSignature;

  /// No description provided for @updateFailedPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Whisper to install updates, then come back and tap again.'**
  String get updateFailedPermission;

  /// No description provided for @updateFailedInstall.
  ///
  /// In en, this message translates to:
  /// **'Android didn\'t install the update. Try again later.'**
  String get updateFailedInstall;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @updateAutoCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateAutoCheck;

  /// No description provided for @updateAutoCheckBody.
  ///
  /// In en, this message translates to:
  /// **'About once a day, through Tor: GitHub only sees a Tor exit.'**
  String get updateAutoCheckBody;

  /// No description provided for @updateCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get updateCheckNow;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version.'**
  String get updateUpToDate;

  /// No description provided for @updateStoreManaged.
  ///
  /// In en, this message translates to:
  /// **'Updates come from the store you installed Whisper from.'**
  String get updateStoreManaged;

  /// No description provided for @paranoiaSecureIos.
  ///
  /// In en, this message translates to:
  /// **'Hide the screen when recorded'**
  String get paranoiaSecureIos;

  /// No description provided for @paranoiaSecureBodyIos.
  ///
  /// In en, this message translates to:
  /// **'iPhone can\'t block screenshots. Whisper hides its screen while it\'s recorded or mirrored, and in the app switcher.'**
  String get paranoiaSecureBodyIos;

  /// No description provided for @iosBackgroundNote.
  ///
  /// In en, this message translates to:
  /// **'On iPhone, messages arrive while Whisper is open: iOS doesn\'t let apps keep a private connection in the background. Relays keep messages for at least two days.'**
  String get iosBackgroundNote;

  /// No description provided for @updateViaTor.
  ///
  /// In en, this message translates to:
  /// **'Download through Tor'**
  String get updateViaTor;

  /// No description provided for @updateViaTorBody.
  ///
  /// In en, this message translates to:
  /// **'Slower, but nobody can see this phone fetching Whisper.'**
  String get updateViaTorBody;

  /// No description provided for @updateDirectWarning.
  ///
  /// In en, this message translates to:
  /// **'Faster, but your internet provider and GitHub will see this phone downloading Whisper. Avoid it where Whisper or Tor is watched. The file is verified the same way.'**
  String get updateDirectWarning;

  /// No description provided for @channelHistory.
  ///
  /// In en, this message translates to:
  /// **'Past posts'**
  String get channelHistory;

  /// No description provided for @channelHistoryAll.
  ///
  /// In en, this message translates to:
  /// **'Full history'**
  String get channelHistoryAll;

  /// No description provided for @channelHistoryAllBody.
  ///
  /// In en, this message translates to:
  /// **'New followers see every earlier post. Your phone keeps them and sends them to the relays again once a day.'**
  String get channelHistoryAllBody;

  /// No description provided for @channelHistoryJoin.
  ///
  /// In en, this message translates to:
  /// **'From when they follow'**
  String get channelHistoryJoin;

  /// No description provided for @channelHistoryJoinBody.
  ///
  /// In en, this message translates to:
  /// **'New followers only see posts published after they follow. Earlier posts aren\'t sent again and fade from the relays.'**
  String get channelHistoryJoinBody;

  /// No description provided for @channelPostEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get channelPostEdit;

  /// No description provided for @channelPostEditing.
  ///
  /// In en, this message translates to:
  /// **'Editing a post'**
  String get channelPostEditing;

  /// No description provided for @channelPostEdited.
  ///
  /// In en, this message translates to:
  /// **'edited {date}'**
  String channelPostEdited(String date);

  /// No description provided for @groupCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy group link'**
  String get groupCopyLink;

  /// No description provided for @groupLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Group link copied'**
  String get groupLinkCopied;

  /// No description provided for @groupLinkNotMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in this group. Only its admin can add you.'**
  String get groupLinkNotMember;

  /// No description provided for @pinMessage.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pinMessage;

  /// No description provided for @unpinMessage.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinMessage;

  /// No description provided for @pinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get pinnedMessage;

  /// No description provided for @chatJumpLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest messages'**
  String get chatJumpLatest;

  /// No description provided for @chatNewMessages.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get chatNewMessages;

  /// No description provided for @replyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyAction;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(String name);

  /// No description provided for @messageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Message not available'**
  String get messageUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
