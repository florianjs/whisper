// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Whisper';

  @override
  String get appTagline => 'Sprich frei. Ohne Nummer, ohne Namen, ohne Spuren.';

  @override
  String get back => 'Zurück';

  @override
  String get continueLabel => 'Weiter';

  @override
  String get welcomeCreate => 'Identität erstellen';

  @override
  String get welcomeRestore => 'Ich habe eine Wiederherstellungsphrase';

  @override
  String get welcomeFootnote =>
      'Keine Telefonnummer. Keine E-Mail. Deine Schlüssel verlassen nie dieses Handy.';

  @override
  String get createGenerating => 'Deine Schlüssel werden erzeugt…';

  @override
  String get createUsernameLabel => 'DU BIST';

  @override
  String get createUsernameCaption =>
      'Aus deinem Schlüssel abgeleitet. Niemand hat ihn ausgesucht, niemand kann ihn mit dir verbinden.';

  @override
  String get seedTitle => 'Wiederherstellungsphrase';

  @override
  String get seedIntro =>
      'Diese Wörter sind die einzige Möglichkeit, dein Konto zurückzubekommen. Whisper speichert sie nicht: Du siehst sie nur dieses eine Mal. Bewahre sie in einem Passwort-Manager (Bitwarden, 1Password…) oder auf Papier auf.';

  @override
  String get seedRevealHint =>
      'Zum Anzeigen tippen. Achte darauf, dass niemand zusieht.';

  @override
  String get seedCopy => 'Kopieren';

  @override
  String get seedCopied => 'Kopiert. Die Zwischenablage wird in 60 s geleert.';

  @override
  String get seedWarning =>
      'Wer diese Wörter hat, wird zu dir. Niemand kann sie zurücksetzen: Wörter verloren heißt Konto verloren.';

  @override
  String get seedSavedCheckbox => 'Ich habe meine Wörter sicher aufbewahrt';

  @override
  String get verifyTitle => 'Phrase überprüfen';

  @override
  String verifyPrompt(int number) {
    return 'Welches ist Wort Nr. $number?';
  }

  @override
  String verifyProgress(int done, int total) {
    return '$done von $total';
  }

  @override
  String get verifyWrong => 'Nicht ganz. Prüfe deine gespeicherten Wörter.';

  @override
  String get verifyShowAgain => 'Wörter erneut anzeigen';

  @override
  String get restoreTitle => 'Wiederherstellen';

  @override
  String get restoreIntro =>
      'Gib deine 12 oder 24 Wiederherstellungswörter ein oder füge sie ein, getrennt durch Leerzeichen.';

  @override
  String restoreWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wörter',
      one: '1 Wort',
    );
    return '$_temp0';
  }

  @override
  String restoreUnknownWord(String word) {
    return 'Unbekanntes Wort: $word';
  }

  @override
  String get restoreInvalid =>
      'Diese Wörter ergeben keine gültige Phrase. Prüfe Reihenfolge und Schreibweise.';

  @override
  String get restoreAction => 'Konto wiederherstellen';

  @override
  String homeGreeting(String name) {
    return 'Hallo, $name';
  }

  @override
  String get homeYourId => 'DEINE ID';

  @override
  String get homeComingSoon => 'Unterhaltungen kommen bald.';

  @override
  String get panicTooltip => 'Panikknopf';

  @override
  String get panicTitle => 'Alles löschen';

  @override
  String get panicBody =>
      'Löscht deine Nachrichten, Kontakte und Schlüssel von diesem Handy, bittet die Relays, alles zu löschen, was sie für dich speichern, und meldet dich ab. Um zurückzukommen, brauchst du deine Wiederherstellungsphrase.';

  @override
  String get panicHold => 'Zum Löschen halten';

  @override
  String get panicHolding => 'Weiter halten…';

  @override
  String relayOnline(int count, int total) {
    return 'Verbunden · $count/$total';
  }

  @override
  String get relayConnecting => 'Verbinde…';

  @override
  String get relayOffline => 'Offline · neuer Versuch';

  @override
  String get relaysTitle => 'Relays';

  @override
  String get relaysIntro =>
      'Deine Nachrichten laufen über diese Relays. Sie können sie nicht lesen und nicht sehen, wer sie gesendet hat, aber ein Relay kann deine IP-Adresse sehen.';

  @override
  String get relayUp => 'Verbunden';

  @override
  String get relayDown => 'Nicht erreichbar';

  @override
  String get relaysRetry => 'Jetzt erneut versuchen';

  @override
  String get homeEmptyTitle => 'Noch keine Unterhaltungen';

  @override
  String get homeEmptyBody =>
      'Teile deine ID, damit man dir schreiben kann, oder füge die ID einer anderen Person ein, um loszulegen.';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get myId => 'Meine ID';

  @override
  String get myIdBody =>
      'Teile sie, damit man dir schreiben kann. Sie verrät nichts darüber, wer du bist.';

  @override
  String get copyId => 'ID kopieren';

  @override
  String get idCopied => 'ID kopiert';

  @override
  String get newChatHint => 'ID einfügen (npub…)';

  @override
  String get newChatInvalid =>
      'Das ist keine gültige ID. Prüfe, ob sie vollständig kopiert wurde.';

  @override
  String get newChatSelf => 'Das ist deine eigene ID.';

  @override
  String get newChatStart => 'Chat starten';

  @override
  String get chatInputHint => 'Nachricht';

  @override
  String get chatSend => 'Senden';

  @override
  String chatEmpty(String name) {
    return 'Nachrichten sind Ende-zu-Ende-verschlüsselt. Nur $name kann sie lesen.';
  }

  @override
  String get chatEncrypted => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get messageFailed => 'Nicht gesendet · zum Wiederholen tippen';

  @override
  String youPrefix(String text) {
    return 'Du: $text';
  }

  @override
  String get paste => 'Einfügen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get sectionNetwork => 'NETZWERK';

  @override
  String get relaysManage => 'Relays';

  @override
  String get relayAddHint => 'wss://relay.example';

  @override
  String get relayAdd => 'Hinzufügen';

  @override
  String get relayInvalid => 'Nur sichere wss://-Adressen werden akzeptiert.';

  @override
  String get relayRemove => 'Entfernen';

  @override
  String get relayKeepOne => 'Behalte mindestens ein Relay.';

  @override
  String get sectionParanoia => 'PARANOIA-MODUS';

  @override
  String get paranoiaMaster => 'Paranoia-Modus';

  @override
  String get paranoiaMasterBody =>
      'Maximaler Schutz vor Spyware und feindlichen Tastaturen. Weniger bequem.';

  @override
  String get paranoiaKeyboard => 'Whisper-Tastatur';

  @override
  String get paranoiaKeyboardBody =>
      'Tippe mit Whispers eigener Tastatur: Die Tastatur deines Handys sieht nie, was du schreibst.';

  @override
  String get paranoiaShuffle => 'Tasten mischen';

  @override
  String get paranoiaShuffleBody =>
      'Die Buchstaben wechseln bei jedem Öffnen der Tastatur ihren Platz, so verraten aufgezeichnete Berührungen nichts.';

  @override
  String get paranoiaMask => 'Eingabe verbergen';

  @override
  String get paranoiaMaskBody =>
      'Zeigt •••• statt des Textes, den du schreibst.';

  @override
  String get paranoiaBlur => 'Nachrichten verschwommen';

  @override
  String get paranoiaBlurBody =>
      'Nachrichten bleiben verschwommen, bis du sie gedrückt hältst.';

  @override
  String get paranoiaA11y => 'Vor Bedienungshilfen verbergen';

  @override
  String get paranoiaA11yBody =>
      'Spyware liest den Bildschirm oft über Bedienungshilfen aus. Das blockiert auch Screenreader (TalkBack).';

  @override
  String get paranoiaSecure => 'Screenshots überall blockieren';

  @override
  String get paranoiaSecureBody =>
      'Screenshots, Bildschirmaufnahmen und die App-Vorschau unter „Zuletzt verwendet“ zeigen einen schwarzen Bildschirm.';

  @override
  String get paranoiaLimits =>
      'Keine App kann ein vollständig kompromittiertes Handy schützen (gerootet oder Spyware mit Systemzugriff). Der Paranoia-Modus stoppt die häufigen Fälle.';

  @override
  String get a11yWarningTitle => 'Apps, die deinen Bildschirm lesen können';

  @override
  String get a11yWarningBody =>
      'Diese Apps haben Zugriff auf Bedienungshilfen und könnten lesen, was angezeigt wird:';

  @override
  String get a11yWarningAction => 'In den Systemeinstellungen prüfen';

  @override
  String get sectionDanger => 'GEFAHRENZONE';

  @override
  String get chatHoldToRead => 'Zum Lesen halten';

  @override
  String get keyboardSpace => 'Leerzeichen';

  @override
  String get requestsTitle => 'Anfragen';

  @override
  String requestsRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichtenanfragen',
      one: '1 Nachrichtenanfrage',
    );
    return '$_temp0';
  }

  @override
  String get requestsEmpty => 'Keine offenen Anfragen.';

  @override
  String requestBanner(String name) {
    return '$name möchte mit dir chatten. Bis du annimmst, sieht diese Person nichts über dich, nicht einmal dein Foto.';
  }

  @override
  String get requestAccept => 'Annehmen';

  @override
  String get requestRefuse => 'Ablehnen';

  @override
  String get requestBlock => 'Blockieren';

  @override
  String requestBlocked(String name) {
    return '$name ist blockiert.';
  }

  @override
  String get sectionProfile => 'PROFIL';

  @override
  String get photoFromGallery => 'Foto auswählen';

  @override
  String get photoFromCamera => 'Foto aufnehmen';

  @override
  String get photoRemove => 'Entfernen';

  @override
  String get photoPrivacy =>
      'Nur Kontakte, die du angenommen hast, erhalten es, Ende-zu-Ende-verschlüsselt. Standort- und Kameradaten werden aus dem Foto entfernt.';

  @override
  String get photoError =>
      'Dieses Bild kann nicht verwendet werden. Versuch ein anderes.';

  @override
  String get chatMenu => 'Mehr';

  @override
  String blockConfirmTitle(String name) {
    return '$name blockieren?';
  }

  @override
  String get blockConfirmBody =>
      'Diese Unterhaltung wird von diesem Handy gelöscht und nichts, was diese Person sendet, erreicht dich. Sie wird nicht benachrichtigt.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get blockedPeople => 'Blockierte Personen';

  @override
  String get blockedEmpty => 'Niemand ist blockiert.';

  @override
  String get unblock => 'Freigeben';

  @override
  String get attach => 'Foto senden';

  @override
  String get imagePreviewTitle => 'Dieses Foto senden?';

  @override
  String get imageAnonymized =>
      'Standort, Kameradaten und Datum wurden entfernt. Das Foto wurde verkleinert.';

  @override
  String get imageSend => 'Senden';

  @override
  String get photoPreview => '📷 Foto';

  @override
  String get imagePendingRequest =>
      'Foto verborgen, bis du diese Anfrage annimmst';

  @override
  String get imageUnavailable => 'Foto nicht verfügbar';

  @override
  String get lockTitle => 'Whisper ist gesperrt';

  @override
  String get lockEnterPin => 'Gib deine PIN ein';

  @override
  String get lockWrongPin => 'Falsche PIN';

  @override
  String lockRetryIn(int seconds) {
    return 'Zu viele Versuche. Versuch es in $seconds s erneut.';
  }

  @override
  String get lockBiometric => 'Mit Fingerabdruck oder Gesicht entsperren';

  @override
  String get lockBiometricPrompt => 'Whisper entsperren';

  @override
  String get lockNow => 'Jetzt sperren';

  @override
  String get lockChecking => 'Wird geprüft…';

  @override
  String get sectionAppLock => 'APP-SPERRE';

  @override
  String get appLockSetup => 'Mit PIN schützen';

  @override
  String get appLockSetupBody =>
      'Dein Kontoschlüssel wird mit deiner PIN verschlüsselt. Ohne sie öffnet sich nichts, selbst mit dem Handy in der Hand.';

  @override
  String get appLockBiometrics => 'Fingerabdruck oder Gesicht';

  @override
  String get appLockBiometricsBody =>
      'Nutzt die sichere Biometrie des Handys. Wird ein neuer Fingerabdruck hinzugefügt, wird sie deaktiviert: Dann wird deine PIN abgefragt.';

  @override
  String get appLockChangePin => 'PIN ändern';

  @override
  String get appLockAutoLock => 'Automatisch sperren';

  @override
  String get autoLockImmediately => 'Sofort';

  @override
  String get autoLockMinute => 'Nach 1 Min.';

  @override
  String get autoLockFiveMinutes => 'Nach 5 Min.';

  @override
  String get appLockDuress => 'Zwangs-PIN';

  @override
  String get appLockDuressBody =>
      'Eine zweite PIN. Wird sie auf dem Sperrbildschirm eingegeben, löscht sie unbemerkt alles und öffnet eine leere App.';

  @override
  String get appLockDuressSet => 'Zwangs-PIN festlegen';

  @override
  String get appLockDuressRemove => 'Zwangs-PIN entfernen';

  @override
  String get appLockTurnOff => 'App-Sperre deaktivieren';

  @override
  String get pinNewTitle => 'PIN wählen';

  @override
  String get pinConfirmTitle => 'PIN bestätigen';

  @override
  String get pinCurrentTitle => 'Aktuelle PIN';

  @override
  String get pinDuressTitle => 'Zwangs-PIN wählen';

  @override
  String get pinRules =>
      '6 bis 12 Ziffern. Vermeide 123456 oder sich wiederholende Ziffern.';

  @override
  String get pinWeak => 'Zu leicht zu erraten. Wähl eine andere.';

  @override
  String get pinMismatch =>
      'Die PINs stimmen nicht überein. Versuch es noch einmal.';

  @override
  String get pinSameAsReal => 'Muss sich von deiner PIN unterscheiden.';

  @override
  String get pinEncrypting => 'Deine Schlüssel werden verschlüsselt…';

  @override
  String get signOut => 'Abmelden';

  @override
  String get signOutTitle => 'Auf diesem Handy abmelden?';

  @override
  String get signOutBody =>
      'Deine Nachrichten, Kontakte und Schlüssel werden von diesem Handy gelöscht. Um zurückzukommen, brauchst du deine Wiederherstellungsphrase.';

  @override
  String get biometricCancel => 'PIN verwenden';

  @override
  String get relayTorStarting => 'Tor wird gestartet…';

  @override
  String get relayTorFailed => 'Tor nicht erreichbar · neuer Versuch';

  @override
  String get relaysIntroTor =>
      'Deine Verbindung läuft über Tor: Relays können deine IP-Adresse nicht sehen, deine Nachrichten nicht lesen und nicht sehen, wer sie gesendet hat.';

  @override
  String get torToggle => 'Über Tor leiten (empfohlen)';

  @override
  String get torToggleBody =>
      'Verbirgt deine IP-Adresse vor den Relays und hilft, Zensur zu umgehen. Der Verbindungsaufbau dauert ein paar Sekunden länger.';

  @override
  String get torOffWarning =>
      'Ohne Tor können Relays und dein Netzanbieter sehen, dass du Whisper nutzt, und deine IP-Adresse sehen.';

  @override
  String get scanQr => 'QR-Code scannen';

  @override
  String get scanHint => 'Richte die Kamera auf einen Whisper-QR-Code';

  @override
  String get scanInvalid => 'Dieser QR-Code ist keine Whisper-ID.';

  @override
  String get myIdQrHint =>
      'Lass Freunde diesen Code scannen, damit sie dir schreiben können.';

  @override
  String get safetyNumber => 'Sicherheitsnummer prüfen';

  @override
  String safetyNumberBody(String name) {
    return 'Vergleiche diese Nummern mit $name, persönlich oder bei einem Anruf. Stimmen sie auf beiden Handys überein, hört niemand eure Unterhaltung mit.';
  }

  @override
  String get safetyMarkVerified => 'Als verifiziert markieren';

  @override
  String get verified => 'Verifiziert';

  @override
  String get rename => 'Umbenennen';

  @override
  String get renameHint => 'Spitzname (nur auf diesem Handy)';

  @override
  String get save => 'Speichern';

  @override
  String get vaultErrorTitle => 'Sicherer Speicher nicht verfügbar';

  @override
  String get vaultErrorBody =>
      'Der sichere Speicher deines Handys hat nicht reagiert. Es wurde nichts gelöscht. Schließe Whisper und öffne es erneut; wenn das Problem bleibt, starte dein Handy neu.';

  @override
  String get newGroup => 'Neue Gruppe';

  @override
  String get groupName => 'Gruppenname';

  @override
  String groupPickMembers(int max) {
    return 'Mitglieder (bis zu $max)';
  }

  @override
  String get groupNoContacts =>
      'Füge zuerst Kontakte hinzu: Nur Personen, die du angenommen hast, können eingeladen werden.';

  @override
  String get groupCreate => 'Erstellen';

  @override
  String groupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get groupEmpty =>
      'Nachrichten sind Ende-zu-Ende-verschlüsselt und werden einzeln an jedes Mitglied gesendet. Kein Server weiß, dass diese Gruppe existiert.';

  @override
  String get groupInfo => 'Gruppeninfo';

  @override
  String get groupAdmin => 'Admin';

  @override
  String get groupYou => 'Du';

  @override
  String get groupRename => 'Gruppe umbenennen';

  @override
  String get groupAddMembers => 'Mitglieder hinzufügen';

  @override
  String get groupRemoveMember => 'Aus Gruppe entfernen';

  @override
  String get groupLeave => 'Gruppe verlassen';

  @override
  String groupLeaveConfirm(String name) {
    return '„$name“ verlassen? Die Nachrichten werden von diesem Handy gelöscht.';
  }

  @override
  String get groupRemoved => 'Du bist kein Mitglied dieser Gruppe mehr.';

  @override
  String groupInvite(String name) {
    return '$name hat dich in diese Gruppe eingeladen. Wenn du ablehnst, erfährt es niemand.';
  }

  @override
  String get groupInviteRow => 'Gruppeneinladung';

  @override
  String get groupNoAdminLeave =>
      'Als Admin kannst du nicht austreten. Entferne stattdessen die Mitglieder.';

  @override
  String groupNamePrefix(String name, String text) {
    return '$name: $text';
  }

  @override
  String get newChannel => 'Neuer Kanal';

  @override
  String get joinChannel => 'Kanal beitreten';

  @override
  String get channelName => 'Kanalname';

  @override
  String get channelAbout => 'Beschreibung (optional)';

  @override
  String get channelPublic => 'Öffentlich';

  @override
  String get channelPublicBody =>
      'Alle mit dem Einladungslink oder QR-Code können ihm folgen und ihn teilen.';

  @override
  String get channelPrivate => 'Privat';

  @override
  String get channelPrivateBody =>
      'Du lädst Kontakte selbst ein. Follower haben keinen Teilen-Knopf.';

  @override
  String get channelCreate => 'Kanal erstellen';

  @override
  String get channelEmptyAdmin =>
      'Nur du kannst hier posten. Follower können anonym reagieren.';

  @override
  String get channelEmptyViewer => 'Noch keine Beiträge.';

  @override
  String get channelBadge => 'Kanal';

  @override
  String get channelFollowers =>
      'Nur der Admin postet · Reaktionen sind anonym';

  @override
  String get channelInfo => 'Kanalinfo';

  @override
  String get channelInvite => 'Einladen';

  @override
  String get channelInviteBody =>
      'Scanne oder teile diesen Code, um dem Kanal zu folgen. Er enthält den Schlüssel zum Lesen: Teile ihn nur dort, wo du willst.';

  @override
  String get channelInviteCopied => 'Einladung kopiert';

  @override
  String get channelCopyInvite => 'Einladung kopieren';

  @override
  String get channelInviteContacts => 'Kontakte einladen';

  @override
  String get channelInvitesSent => 'Einladungen gesendet';

  @override
  String get channelLeave => 'Kanal verlassen';

  @override
  String channelLeaveConfirm(String name) {
    return '„$name“ verlassen? Die Beiträge werden von diesem Handy gelöscht. Der Admin erfährt es nicht.';
  }

  @override
  String channelInviteFrom(String name) {
    return '$name hat dich eingeladen, diesem Kanal zu folgen.';
  }

  @override
  String get channelInviteRow => 'Kanaleinladung';

  @override
  String get channelJoinHint => 'Einladung einfügen (whisper-channel:…)';

  @override
  String get channelJoinInvalid => 'Das ist keine gültige Kanaleinladung.';

  @override
  String get channelJoin => 'Folgen';

  @override
  String get channelEdit => 'Kanal bearbeiten';

  @override
  String get channelReact => 'Reagieren';

  @override
  String get channelPostHint => 'An deine Follower posten';

  @override
  String get channelAdminNote =>
      'Der Schlüssel deines Kanals stammt aus deiner Identität: Mit deiner Wiederherstellungsphrase bekommst du ihn zurück.';

  @override
  String get relayTorDisguising => 'Getarnte Verbindung wird gestartet…';

  @override
  String get connProtected => 'Geschützte Verbindung';

  @override
  String get connDisguised => 'Getarnte Verbindung';

  @override
  String get connProtectedBody =>
      'Über Tor: Relays können deine IP-Adresse nicht sehen.';

  @override
  String get connDisguisedBody =>
      'Über Tor, getarnt als normaler Datenverkehr: Dein Netzwerk erkennt nicht, dass du Tor nutzt.';

  @override
  String get torDisguise => 'Verbindung tarnen';

  @override
  String get torDisguiseBody =>
      'Für Orte, an denen schon die Nutzung von Tor riskant ist. Dein Datenverkehr sieht aus wie Zufallsdaten oder ein Videoanruf. Langsamerer Verbindungsaufbau. Whisper schaltet automatisch um, wenn Tor blockiert ist.';

  @override
  String get bgConnectionTitle => 'Private Verbindung aktiv';

  @override
  String get bgConnectionText => 'Whisper kann deine Nachrichten empfangen.';

  @override
  String notifyNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Nachrichten',
      one: 'Neue Nachricht',
    );
    return '$_temp0';
  }

  @override
  String get bgToggle => 'Im Hintergrund empfangen';

  @override
  String get bgToggleBody =>
      'Hält eine private Verbindung offen, wenn Whisper geschlossen ist, mit einer dauerhaften Benachrichtigung. Benachrichtigungen zeigen nie, wer was geschrieben hat. Verbraucht mehr Akku. Keine Google-Dienste beteiligt.';

  @override
  String get sectionBackup => 'BACKUP';

  @override
  String get backupExport => 'Verlauf exportieren';

  @override
  String get backupExportBody =>
      'Speichert eine verschlüsselte Datei. Nur deine Wiederherstellungsphrase kann sie öffnen, auf jedem Handy.';

  @override
  String get backupImport => 'Verlauf importieren';

  @override
  String get backupImportBody =>
      'Fügt die Unterhaltungen eines Backups dieses Kontos hinzu. Hier wird nichts überschrieben.';

  @override
  String get backupWorking => 'Verschlüsseltes Backup wird vorbereitet…';

  @override
  String get backupSaved => 'Verschlüsseltes Backup gespeichert';

  @override
  String backupImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente wiederhergestellt',
      one: '1 Element wiederhergestellt',
      zero: 'Nichts Neues in diesem Backup',
    );
    return '$_temp0';
  }

  @override
  String get backupWrongKey =>
      'Dieses Backup gehört zu einem anderen Konto oder ist beschädigt.';

  @override
  String get backupBadFile => 'Das ist kein Whisper-Backup.';

  @override
  String get backupNewer =>
      'Dieses Backup wurde mit einer neueren Version von Whisper erstellt.';

  @override
  String get backupFailed =>
      'Die Datei konnte nicht gelesen oder geschrieben werden.';

  @override
  String get searchHint => 'Suchen';

  @override
  String get searchNoResults => 'Keine Ergebnisse';

  @override
  String get filterAll => 'Alle';

  @override
  String get filterChats => 'Chats';

  @override
  String get filterGroups => 'Gruppen';

  @override
  String get filterChannels => 'Kanäle';

  @override
  String get filterEmpty => 'Hier ist noch nichts';

  @override
  String get newChatSubtitle => 'Schreib jemandem über seine ID';

  @override
  String get newGroupSubtitle => 'Privat, Ende-zu-Ende-verschlüsselt';

  @override
  String get newChannelSubtitle => 'An viele Menschen senden';

  @override
  String get joinChannelSubtitle => 'Einladung scannen oder einfügen';

  @override
  String get startSomething => 'Starten';

  @override
  String get appearanceTitle => 'Darstellung';

  @override
  String get themeTitle => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Hell';

  @override
  String get nicknameTitle => 'Spitzname';

  @override
  String get nicknameHint => 'Dein Spitzname';

  @override
  String nicknameBody(String username) {
    return 'Nur Kontakte, die du angenommen hast, sehen ihn, Ende-zu-Ende-verschlüsselt. Leer lassen, um als $username zu erscheinen.';
  }

  @override
  String get updateAvailableTitle => 'Update verfügbar';

  @override
  String updateAvailableBody(String version) {
    return 'Whisper $version ist bereit zur Installation.';
  }

  @override
  String updateBanner(String version) {
    return 'Whisper $version ist verfügbar';
  }

  @override
  String get updateSheetBody =>
      'Wird über Tor von den GitHub-Releases von Whisper geladen und vor der Installation geprüft: gleicher Signaturschlüssel wie diese App und eine neuere Version.';

  @override
  String get updateInstall => 'Laden und installieren';

  @override
  String get updateDownloading => 'Wird geladen…';

  @override
  String get updateInstalling => 'Wird installiert…';

  @override
  String get updateFailedNetwork =>
      'GitHub ist nicht erreichbar. Versuch es später erneut.';

  @override
  String get updateFailedChecksum =>
      'Der Download war beschädigt und wurde gelöscht. Versuch es erneut.';

  @override
  String get updateFailedSignature =>
      'Diese Datei ist nicht mit dem Schlüssel von Whisper signiert. Sie wurde nicht installiert.';

  @override
  String get updateFailedPermission =>
      'Erlaube Whisper, Updates zu installieren, komm dann zurück und tippe erneut.';

  @override
  String get updateFailedInstall =>
      'Android hat das Update nicht installiert. Versuch es später erneut.';

  @override
  String get sectionAbout => 'Über';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get updateAutoCheck => 'Nach Updates suchen';

  @override
  String get updateAutoCheckBody =>
      'Etwa einmal am Tag, über Tor: GitHub sieht nur einen Tor-Ausgang.';

  @override
  String get updateCheckNow => 'Jetzt prüfen';

  @override
  String get updateUpToDate => 'Du hast die neueste Version.';

  @override
  String get updateStoreManaged =>
      'Updates kommen aus dem Store, über den du Whisper installiert hast.';

  @override
  String get paranoiaSecureIos => 'Bildschirm bei Aufnahme verbergen';

  @override
  String get paranoiaSecureBodyIos =>
      'Das iPhone kann Screenshots nicht blockieren. Whisper verbirgt seinen Bildschirm, während er aufgenommen oder gespiegelt wird, und in der App-Übersicht.';

  @override
  String get iosBackgroundNote =>
      'Auf dem iPhone kommen Nachrichten an, solange Whisper geöffnet ist: iOS lässt Apps keine private Verbindung im Hintergrund halten. Relays speichern Nachrichten mindestens zwei Tage.';

  @override
  String get updateViaTor => 'Über Tor laden';

  @override
  String get updateViaTorBody =>
      'Langsamer, aber niemand sieht, dass dieses Telefon Whisper lädt.';

  @override
  String get updateDirectWarning =>
      'Schneller, aber dein Internetanbieter und GitHub sehen, dass dieses Telefon Whisper lädt. Vermeide das, wo Whisper oder Tor überwacht werden. Die Datei wird genauso geprüft.';

  @override
  String get channelHistory => 'Frühere Beiträge';

  @override
  String get channelHistoryAll => 'Ganzer Verlauf';

  @override
  String get channelHistoryAllBody =>
      'Neue Follower sehen alle früheren Beiträge. Dein Handy behält sie und sendet sie einmal am Tag erneut an die Relays.';

  @override
  String get channelHistoryJoin => 'Ab dem Folgen';

  @override
  String get channelHistoryJoinBody =>
      'Neue Follower sehen nur Beiträge, die nach ihrem Beitritt erscheinen. Frühere werden nicht erneut gesendet und verschwinden nach und nach von den Relays.';

  @override
  String get channelPostEdit => 'Bearbeiten';

  @override
  String get channelPostEditing => 'Beitrag bearbeiten';

  @override
  String channelPostEdited(String date) {
    return 'bearbeitet am $date';
  }

  @override
  String get groupCopyLink => 'Gruppenlink kopieren';

  @override
  String get groupLinkCopied => 'Gruppenlink kopiert';

  @override
  String get groupLinkNotMember =>
      'Du bist nicht in dieser Gruppe. Nur ihr Admin kann dich hinzufügen.';

  @override
  String get pinMessage => 'Anheften';

  @override
  String get unpinMessage => 'Loslösen';

  @override
  String get pinnedMessage => 'Angeheftete Nachricht';

  @override
  String get chatJumpLatest => 'Neueste Nachrichten';

  @override
  String get chatNewMessages => 'Neue Nachrichten';

  @override
  String get replyAction => 'Antworten';

  @override
  String replyingTo(String name) {
    return 'Antwort an $name';
  }

  @override
  String get messageUnavailable => 'Nachricht nicht verfügbar';
}
