// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Whisper';

  @override
  String get appTagline =>
      'Parlez librement. Sans numéro, sans nom, sans trace.';

  @override
  String get back => 'Retour';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get welcomeCreate => 'Créer mon identité';

  @override
  String get welcomeRestore => 'J\'ai une phrase de récupération';

  @override
  String get welcomeFootnote =>
      'Pas de numéro. Pas d\'e-mail. Vos clés ne quittent jamais ce téléphone.';

  @override
  String get createGenerating => 'Génération de vos clés…';

  @override
  String get createUsernameLabel => 'VOUS ÊTES';

  @override
  String get createUsernameCaption =>
      'Dérivé de votre clé. Personne ne l\'a choisi, personne ne peut le relier à vous.';

  @override
  String get seedTitle => 'Phrase de récupération';

  @override
  String get seedIntro =>
      'Ces mots sont le seul moyen de récupérer votre compte. Whisper ne les conserve pas : c\'est la seule fois où vous les verrez. Enregistrez-les dans un gestionnaire de mots de passe (Bitwarden, 1Password…) ou sur papier.';

  @override
  String get seedRevealHint =>
      'Touchez pour afficher. Assurez-vous que personne ne regarde.';

  @override
  String get seedCopy => 'Copier';

  @override
  String get seedCopied => 'Copié. Le presse-papiers sera vidé dans 60 s.';

  @override
  String get seedWarning =>
      'Quiconque possède ces mots devient vous. Personne ne peut les réinitialiser : mots perdus, compte perdu.';

  @override
  String get seedSavedCheckbox => 'J\'ai enregistré mes mots en lieu sûr';

  @override
  String get verifyTitle => 'Vérifiez votre phrase';

  @override
  String verifyPrompt(int number) {
    return 'Quel est le mot n° $number ?';
  }

  @override
  String verifyProgress(int done, int total) {
    return '$done sur $total';
  }

  @override
  String get verifyWrong => 'Pas tout à fait. Vérifiez vos mots enregistrés.';

  @override
  String get verifyShowAgain => 'Revoir mes mots';

  @override
  String get restoreTitle => 'Restaurer';

  @override
  String get restoreIntro =>
      'Saisissez ou collez vos 12 ou 24 mots de récupération, séparés par des espaces.';

  @override
  String restoreWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots',
      one: '1 mot',
    );
    return '$_temp0';
  }

  @override
  String restoreUnknownWord(String word) {
    return 'Mot inconnu : $word';
  }

  @override
  String get restoreInvalid =>
      'Ces mots ne forment pas une phrase valide. Vérifiez l\'ordre et l\'orthographe.';

  @override
  String get restoreAction => 'Restaurer mon compte';

  @override
  String homeGreeting(String name) {
    return 'Salut, $name';
  }

  @override
  String get homeYourId => 'VOTRE IDENTIFIANT';

  @override
  String get homeComingSoon => 'Les conversations arrivent bientôt.';

  @override
  String get panicTooltip => 'Bouton panique';

  @override
  String get panicTitle => 'Tout effacer';

  @override
  String get panicBody =>
      'Supprime vos messages, contacts et clés de ce téléphone, demande aux relais d\'effacer ce qu\'ils gardent pour vous, et vous déconnecte. Pour revenir, il vous faudra votre phrase de récupération.';

  @override
  String get panicHold => 'Maintenir pour effacer';

  @override
  String get panicHolding => 'Continuez d\'appuyer…';

  @override
  String relayOnline(int count, int total) {
    return 'Connecté · $count/$total';
  }

  @override
  String get relayConnecting => 'Connexion…';

  @override
  String get relayOffline => 'Hors ligne · nouvel essai';

  @override
  String get relaysTitle => 'Relais';

  @override
  String get relaysIntro =>
      'Vos messages transitent par ces relais. Ils ne peuvent ni les lire ni voir qui les envoie, mais un relais peut voir votre adresse IP.';

  @override
  String get relayUp => 'Connecté';

  @override
  String get relayDown => 'Injoignable';

  @override
  String get relaysRetry => 'Réessayer';

  @override
  String get homeEmptyTitle => 'Aucune conversation';

  @override
  String get homeEmptyBody =>
      'Partagez votre identifiant pour qu\'on puisse vous écrire, ou collez celui de quelqu\'un pour commencer.';

  @override
  String get newChat => 'Nouvelle discussion';

  @override
  String get myId => 'Mon identifiant';

  @override
  String get myIdBody =>
      'Partagez-le pour qu\'on puisse vous écrire. Il ne révèle rien sur vous.';

  @override
  String get copyId => 'Copier l\'identifiant';

  @override
  String get idCopied => 'Identifiant copié';

  @override
  String get newChatHint => 'Collez un identifiant (npub…)';

  @override
  String get newChatInvalid =>
      'Identifiant invalide. Vérifiez qu\'il a été copié en entier.';

  @override
  String get newChatSelf => 'C\'est votre propre identifiant.';

  @override
  String get newChatStart => 'Commencer';

  @override
  String get chatInputHint => 'Message';

  @override
  String get chatSend => 'Envoyer';

  @override
  String chatEmpty(String name) {
    return 'Les messages sont chiffrés de bout en bout. Seul·e $name peut les lire.';
  }

  @override
  String get chatEncrypted => 'Chiffré de bout en bout';

  @override
  String get messageFailed => 'Non envoyé · touchez pour réessayer';

  @override
  String youPrefix(String text) {
    return 'Vous : $text';
  }

  @override
  String get paste => 'Coller';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageSystem => 'Système';

  @override
  String get sectionNetwork => 'RÉSEAU';

  @override
  String get relaysManage => 'Relais';

  @override
  String get relayAddHint => 'wss://relais.exemple';

  @override
  String get relayAdd => 'Ajouter';

  @override
  String get relayInvalid =>
      'Seules les adresses sécurisées wss:// sont acceptées.';

  @override
  String get relayRemove => 'Retirer';

  @override
  String get relayKeepOne => 'Gardez au moins un relais.';

  @override
  String get sectionParanoia => 'MODE PARANOÏA';

  @override
  String get paranoiaMaster => 'Mode paranoïa';

  @override
  String get paranoiaMasterBody =>
      'Protection maximale contre les logiciels espions et les claviers malveillants. Moins pratique.';

  @override
  String get paranoiaKeyboard => 'Clavier Whisper';

  @override
  String get paranoiaKeyboardBody =>
      'Tapez avec le clavier de Whisper : le clavier de votre téléphone ne voit jamais ce que vous écrivez.';

  @override
  String get paranoiaShuffle => 'Mélanger les touches';

  @override
  String get paranoiaShuffleBody =>
      'Les lettres changent de place à chaque ouverture : un enregistrement des appuis ne révèle rien.';

  @override
  String get paranoiaMask => 'Masquer ce que je tape';

  @override
  String get paranoiaMaskBody =>
      'Affiche •••• au lieu du texte en cours d\'écriture.';

  @override
  String get paranoiaBlur => 'Flouter les messages';

  @override
  String get paranoiaBlurBody =>
      'Les messages restent floutés tant que vous n\'appuyez pas longuement dessus.';

  @override
  String get paranoiaA11y => 'Masquer aux services d\'accessibilité';

  @override
  String get paranoiaA11yBody =>
      'Les logiciels espions lisent souvent l\'écran via l\'accessibilité. Bloque aussi les lecteurs d\'écran (TalkBack).';

  @override
  String get paranoiaSecure => 'Bloquer les captures partout';

  @override
  String get paranoiaSecureBody =>
      'Captures, enregistrement d\'écran et aperçu dans les apps récentes affichent un écran noir.';

  @override
  String get paranoiaLimits =>
      'Aucune app ne peut protéger un téléphone entièrement compromis (rooté, ou espion avec accès système). Le mode paranoïa bloque les cas courants.';

  @override
  String get a11yWarningTitle => 'Apps qui peuvent lire votre écran';

  @override
  String get a11yWarningBody =>
      'Ces apps ont l\'accès accessibilité et pourraient lire ce qui est affiché :';

  @override
  String get a11yWarningAction => 'Vérifier dans les réglages système';

  @override
  String get sectionDanger => 'ZONE DANGEREUSE';

  @override
  String get chatHoldToRead => 'Maintenir pour lire';

  @override
  String get keyboardSpace => 'espace';

  @override
  String get requestsTitle => 'Demandes';

  @override
  String requestsRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes de discussion',
      one: '1 demande de discussion',
    );
    return '$_temp0';
  }

  @override
  String get requestsEmpty => 'Aucune demande en attente.';

  @override
  String requestBanner(String name) {
    return '$name veut discuter avec vous. Cette personne ne voit rien de vous, pas même votre photo, tant que vous n\'acceptez pas.';
  }

  @override
  String get requestAccept => 'Accepter';

  @override
  String get requestRefuse => 'Refuser';

  @override
  String get requestBlock => 'Bloquer';

  @override
  String requestBlocked(String name) {
    return '$name est bloqué·e.';
  }

  @override
  String get sectionProfile => 'PROFIL';

  @override
  String get photoFromGallery => 'Choisir une photo';

  @override
  String get photoFromCamera => 'Prendre une photo';

  @override
  String get photoRemove => 'Retirer';

  @override
  String get photoPrivacy =>
      'Seuls les contacts que vous avez acceptés la reçoivent, chiffrée de bout en bout. La position et les infos de l\'appareil sont retirées de la photo.';

  @override
  String get photoError =>
      'Cette image ne peut pas être utilisée. Essayez-en une autre.';

  @override
  String get chatMenu => 'Plus';

  @override
  String blockConfirmTitle(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get blockConfirmBody =>
      'Cette conversation sera supprimée de ce téléphone et rien de ce que cette personne envoie ne vous parviendra. Elle ne sera pas prévenue.';

  @override
  String get cancel => 'Annuler';

  @override
  String get blockedPeople => 'Personnes bloquées';

  @override
  String get blockedEmpty => 'Personne n\'est bloqué.';

  @override
  String get unblock => 'Débloquer';

  @override
  String get attach => 'Envoyer une photo';

  @override
  String get imagePreviewTitle => 'Envoyer cette photo ?';

  @override
  String get imageAnonymized =>
      'La position, les infos de l\'appareil et la date ont été retirées. La photo a été redimensionnée.';

  @override
  String get imageSend => 'Envoyer';

  @override
  String get photoPreview => '📷 Photo';

  @override
  String get imagePendingRequest =>
      'Photo masquée tant que vous n\'acceptez pas cette demande';

  @override
  String get imageUnavailable => 'Photo indisponible';

  @override
  String get lockTitle => 'Whisper est verrouillé';

  @override
  String get lockEnterPin => 'Saisissez votre code';

  @override
  String get lockWrongPin => 'Code incorrect';

  @override
  String lockRetryIn(int seconds) {
    return 'Trop d\'essais. Réessayez dans $seconds s.';
  }

  @override
  String get lockBiometric => 'Déverrouiller avec l\'empreinte ou le visage';

  @override
  String get lockBiometricPrompt => 'Déverrouiller Whisper';

  @override
  String get lockNow => 'Verrouiller';

  @override
  String get lockChecking => 'Vérification…';

  @override
  String get sectionAppLock => 'VERROUILLAGE';

  @override
  String get appLockSetup => 'Protéger par un code';

  @override
  String get appLockSetupBody =>
      'La clé de votre compte est chiffrée avec votre code. Sans lui, rien ne s\'ouvre, même avec le téléphone en main.';

  @override
  String get appLockBiometrics => 'Empreinte ou visage';

  @override
  String get appLockBiometricsBody =>
      'Utilise la biométrie sécurisée du téléphone. Ajouter une nouvelle empreinte la désactive : votre code sera demandé.';

  @override
  String get appLockChangePin => 'Changer le code';

  @override
  String get appLockAutoLock => 'Verrouiller automatiquement';

  @override
  String get autoLockImmediately => 'Immédiatement';

  @override
  String get autoLockMinute => 'Après 1 min';

  @override
  String get autoLockFiveMinutes => 'Après 5 min';

  @override
  String get appLockDuress => 'Code de contrainte';

  @override
  String get appLockDuressBody =>
      'Un second code. Saisi sur l\'écran de verrouillage, il efface tout en silence et ouvre une app vide.';

  @override
  String get appLockDuressSet => 'Définir un code de contrainte';

  @override
  String get appLockDuressRemove => 'Retirer le code de contrainte';

  @override
  String get appLockTurnOff => 'Désactiver le verrouillage';

  @override
  String get pinNewTitle => 'Choisissez un code';

  @override
  String get pinConfirmTitle => 'Confirmez votre code';

  @override
  String get pinCurrentTitle => 'Code actuel';

  @override
  String get pinDuressTitle => 'Choisissez un code de contrainte';

  @override
  String get pinRules =>
      '6 à 12 chiffres. Évitez 123456 ou les chiffres répétés.';

  @override
  String get pinWeak => 'Trop facile à deviner. Choisissez-en un autre.';

  @override
  String get pinMismatch => 'Les codes ne correspondent pas. Réessayez.';

  @override
  String get pinSameAsReal => 'Doit être différent de votre code.';

  @override
  String get pinEncrypting => 'Chiffrement de vos clés…';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signOutTitle => 'Se déconnecter de ce téléphone ?';

  @override
  String get signOutBody =>
      'Vos messages, contacts et clés seront effacés de ce téléphone. Pour revenir, il vous faudra votre phrase de récupération.';

  @override
  String get biometricCancel => 'Utiliser le code';

  @override
  String get relayTorStarting => 'Démarrage de Tor…';

  @override
  String get relayTorFailed => 'Tor injoignable · nouvel essai';

  @override
  String get relaysIntroTor =>
      'Votre connexion passe par Tor : les relais ne voient pas votre adresse IP, et ne peuvent ni lire vos messages ni voir qui les envoie.';

  @override
  String get torToggle => 'Passer par Tor (recommandé)';

  @override
  String get torToggleBody =>
      'Masque votre adresse IP aux relais et aide à contourner la censure. La connexion prend quelques secondes de plus.';

  @override
  String get torOffWarning =>
      'Sans Tor, les relais et votre fournisseur d\'accès peuvent voir que vous utilisez Whisper, ainsi que votre adresse IP.';

  @override
  String get scanQr => 'Scanner un QR code';

  @override
  String get scanHint => 'Visez un QR code Whisper avec l\'appareil photo';

  @override
  String get scanInvalid => 'Ce QR code n\'est pas un identifiant Whisper.';

  @override
  String get myIdQrHint =>
      'Faites scanner ce code à un ami pour qu\'il puisse vous écrire.';

  @override
  String get safetyNumber => 'Vérifier le numéro de sécurité';

  @override
  String safetyNumberBody(String name) {
    return 'Comparez ces chiffres avec $name, en personne ou par téléphone. S\'ils sont identiques sur les deux téléphones, personne n\'intercepte votre conversation.';
  }

  @override
  String get safetyMarkVerified => 'Marquer comme vérifié';

  @override
  String get verified => 'Vérifié';

  @override
  String get rename => 'Renommer';

  @override
  String get renameHint => 'Surnom (seulement sur ce téléphone)';

  @override
  String get save => 'Enregistrer';

  @override
  String get vaultErrorTitle => 'Stockage sécurisé indisponible';

  @override
  String get vaultErrorBody =>
      'Le stockage sécurisé de votre téléphone n\'a pas répondu. Rien n\'a été effacé. Fermez Whisper et rouvrez-le ; si ça persiste, redémarrez votre téléphone.';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String groupPickMembers(int max) {
    return 'Membres ($max max.)';
  }

  @override
  String get groupNoContacts =>
      'Ajoute d\'abord des contacts : seules les personnes acceptées peuvent être invitées.';

  @override
  String get groupCreate => 'Créer';

  @override
  String groupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String get groupEmpty =>
      'Les messages sont chiffrés de bout en bout, envoyés séparément à chaque membre. Aucun serveur ne sait que ce groupe existe.';

  @override
  String get groupInfo => 'Infos du groupe';

  @override
  String get groupAdmin => 'Admin';

  @override
  String get groupYou => 'Toi';

  @override
  String get groupRename => 'Renommer le groupe';

  @override
  String get groupAddMembers => 'Ajouter des membres';

  @override
  String get groupRemoveMember => 'Retirer du groupe';

  @override
  String get groupLeave => 'Quitter le groupe';

  @override
  String groupLeaveConfirm(String name) {
    return 'Quitter « $name » ? Ses messages seront supprimés de ce téléphone.';
  }

  @override
  String get groupRemoved => 'Tu ne fais plus partie de ce groupe.';

  @override
  String groupInvite(String name) {
    return '$name t\'a invité·e dans ce groupe. Refuser ne prévient personne.';
  }

  @override
  String get groupInviteRow => 'Invitation de groupe';

  @override
  String get groupNoAdminLeave =>
      'En tant qu\'admin, tu ne peux pas quitter. Retire plutôt les membres.';

  @override
  String groupNamePrefix(String name, String text) {
    return '$name : $text';
  }

  @override
  String get newChannel => 'Nouveau canal';

  @override
  String get joinChannel => 'Rejoindre un canal';

  @override
  String get channelName => 'Nom du canal';

  @override
  String get channelAbout => 'Description (facultatif)';

  @override
  String get channelPublic => 'Public';

  @override
  String get channelPublicBody =>
      'Toute personne ayant le lien ou le QR d\'invitation peut le suivre et le partager.';

  @override
  String get channelPrivate => 'Privé';

  @override
  String get channelPrivateBody =>
      'Tu invites toi-même des contacts. Les abonnés n\'ont pas de bouton de partage.';

  @override
  String get channelCreate => 'Créer le canal';

  @override
  String get channelEmptyAdmin =>
      'Toi seul·e peux publier ici. Les abonnés peuvent réagir, anonymement.';

  @override
  String get channelEmptyViewer => 'Aucune publication pour l\'instant.';

  @override
  String get channelBadge => 'Canal';

  @override
  String get channelFollowers => 'Seul l\'admin publie · réactions anonymes';

  @override
  String get channelInfo => 'Infos du canal';

  @override
  String get channelInvite => 'Inviter';

  @override
  String get channelInviteBody =>
      'Scanne ou partage ce code pour suivre le canal. Il contient la clé pour le lire : ne le partage que là où tu le souhaites.';

  @override
  String get channelInviteCopied => 'Invitation copiée';

  @override
  String get channelCopyInvite => 'Copier l\'invitation';

  @override
  String get channelInviteContacts => 'Inviter des contacts';

  @override
  String get channelInvitesSent => 'Invitations envoyées';

  @override
  String get channelLeave => 'Quitter le canal';

  @override
  String channelLeaveConfirm(String name) {
    return 'Quitter « $name » ? Ses publications seront supprimées de ce téléphone. L\'admin ne le saura pas.';
  }

  @override
  String channelInviteFrom(String name) {
    return '$name t\'invite à suivre ce canal.';
  }

  @override
  String get channelInviteRow => 'Invitation à un canal';

  @override
  String get channelJoinHint => 'Colle une invitation (whisper-channel:…)';

  @override
  String get channelJoinInvalid =>
      'Ce n\'est pas une invitation de canal valide.';

  @override
  String get channelJoin => 'Suivre';

  @override
  String get channelEdit => 'Modifier le canal';

  @override
  String get channelReact => 'Réagir';

  @override
  String get channelPostHint => 'Publier pour tes abonnés';

  @override
  String get channelAdminNote =>
      'La clé de ton canal découle de ton identité : restaurer ta phrase de récupération te le rend.';

  @override
  String get relayTorDisguising => 'Connexion déguisée en cours…';

  @override
  String get connProtected => 'Connexion protégée';

  @override
  String get connDisguised => 'Connexion déguisée';

  @override
  String get connProtectedBody =>
      'Via Tor : les relais ne voient pas votre adresse IP.';

  @override
  String get connDisguisedBody =>
      'Via Tor, déguisée en trafic ordinaire : votre réseau ne voit pas que vous utilisez Tor.';

  @override
  String get torDisguise => 'Déguiser ma connexion';

  @override
  String get torDisguiseBody =>
      'Pour les pays où utiliser Tor est risqué en soi. Votre trafic ressemble à des données aléatoires ou à un appel vidéo. Connexion plus lente. Whisper bascule tout seul si Tor est bloqué.';

  @override
  String get bgConnectionTitle => 'Connexion privée active';

  @override
  String get bgConnectionText => 'Whisper peut recevoir vos messages.';

  @override
  String notifyNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux messages',
      one: 'Nouveau message',
    );
    return '$_temp0';
  }

  @override
  String get bgToggle => 'Recevoir en arrière-plan';

  @override
  String get bgToggleBody =>
      'Garde une connexion privée ouverte quand Whisper est fermé, avec une notification permanente. Les alertes n\'indiquent jamais qui a écrit ni quoi. Consomme plus de batterie. Aucun service Google.';

  @override
  String get sectionBackup => 'SAUVEGARDE';

  @override
  String get backupExport => 'Exporter l\'historique';

  @override
  String get backupExportBody =>
      'Enregistre un fichier chiffré. Seule votre phrase de récupération peut l\'ouvrir, sur n\'importe quel téléphone.';

  @override
  String get backupImport => 'Importer un historique';

  @override
  String get backupImportBody =>
      'Ajoute les conversations d\'une sauvegarde faite avec ce compte. Rien n\'est écrasé ici.';

  @override
  String get backupWorking => 'Préparation de la sauvegarde chiffrée…';

  @override
  String get backupSaved => 'Sauvegarde chiffrée enregistrée';

  @override
  String backupImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments restaurés',
      one: '1 élément restauré',
      zero: 'Rien de nouveau dans cette sauvegarde',
    );
    return '$_temp0';
  }

  @override
  String get backupWrongKey =>
      'Cette sauvegarde appartient à un autre compte, ou est endommagée.';

  @override
  String get backupBadFile => 'Ce n\'est pas une sauvegarde Whisper.';

  @override
  String get backupNewer =>
      'Cette sauvegarde vient d\'une version plus récente de Whisper.';

  @override
  String get backupFailed => 'Impossible de lire ou d\'écrire le fichier.';

  @override
  String get searchHint => 'Rechercher';

  @override
  String get searchNoResults => 'Aucun résultat';

  @override
  String get filterAll => 'Tous';

  @override
  String get filterChats => 'Discussions';

  @override
  String get filterGroups => 'Groupes';

  @override
  String get filterChannels => 'Canaux';

  @override
  String get filterEmpty => 'Rien ici pour l\'instant';

  @override
  String get newChatSubtitle => 'Écrire à quelqu\'un avec son identifiant';

  @override
  String get newGroupSubtitle => 'Privé, chiffré de bout en bout';

  @override
  String get newChannelSubtitle => 'Diffuser à de nombreuses personnes';

  @override
  String get joinChannelSubtitle => 'Scanner ou coller une invitation';

  @override
  String get startSomething => 'Démarrer';

  @override
  String get appearanceTitle => 'Apparence';

  @override
  String get themeTitle => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get nicknameTitle => 'Pseudo';

  @override
  String get nicknameHint => 'Votre pseudo';

  @override
  String nicknameBody(String username) {
    return 'Seuls les contacts que vous avez acceptés le voient, chiffré de bout en bout. Laissez vide pour garder $username.';
  }

  @override
  String get updateAvailableTitle => 'Mise à jour disponible';

  @override
  String updateAvailableBody(String version) {
    return 'Whisper $version est prêt à être installé.';
  }

  @override
  String updateBanner(String version) {
    return 'Whisper $version est disponible';
  }

  @override
  String get updateSheetBody =>
      'Téléchargé via Tor depuis les releases GitHub de Whisper, puis vérifié avant l\'installation : même clé de signature que cette app, et version plus récente.';

  @override
  String get updateInstall => 'Télécharger et installer';

  @override
  String get updateDownloading => 'Téléchargement…';

  @override
  String get updateInstalling => 'Installation…';

  @override
  String get updateFailedNetwork =>
      'Impossible de joindre GitHub. Réessayez plus tard.';

  @override
  String get updateFailedChecksum =>
      'Le téléchargement était endommagé. Il a été supprimé ; réessayez.';

  @override
  String get updateFailedSignature =>
      'Ce fichier n\'est pas signé avec la clé de Whisper. Il n\'a pas été installé.';

  @override
  String get updateFailedPermission =>
      'Autorisez Whisper à installer des mises à jour, puis revenez et touchez à nouveau.';

  @override
  String get updateFailedInstall =>
      'Android n\'a pas installé la mise à jour. Réessayez plus tard.';

  @override
  String get sectionAbout => 'À propos';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get updateAutoCheck => 'Rechercher les mises à jour';

  @override
  String get updateAutoCheckBody =>
      'Environ une fois par jour, via Tor : GitHub ne voit qu\'une sortie Tor.';

  @override
  String get updateCheckNow => 'Vérifier maintenant';

  @override
  String get updateUpToDate => 'Vous avez la dernière version.';

  @override
  String get updateStoreManaged =>
      'Les mises à jour viennent du store depuis lequel vous avez installé Whisper.';
}
