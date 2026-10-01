// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Whisper';

  @override
  String get appTagline =>
      'Habla con libertad. Sin número, sin nombre, sin rastro.';

  @override
  String get back => 'Atrás';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get welcomeCreate => 'Crear mi identidad';

  @override
  String get welcomeRestore => 'Tengo una frase de recuperación';

  @override
  String get welcomeFootnote =>
      'Sin número de teléfono. Sin correo. Tus claves nunca salen de este teléfono.';

  @override
  String get createGenerating => 'Generando tus claves…';

  @override
  String get createUsernameLabel => 'ERES';

  @override
  String get createUsernameCaption =>
      'Se deriva de tu clave. Nadie lo eligió, nadie puede vincularlo contigo.';

  @override
  String get seedTitle => 'Frase de recuperación';

  @override
  String get seedIntro =>
      'Estas palabras son la única forma de recuperar tu cuenta. Whisper no las guarda: es la única vez que las verás. Guárdalas en un gestor de contraseñas (Bitwarden, 1Password…) o en papel.';

  @override
  String get seedRevealHint =>
      'Toca para mostrarlas. Asegúrate de que nadie esté mirando.';

  @override
  String get seedCopy => 'Copiar';

  @override
  String get seedCopied => 'Copiado. El portapapeles se borrará en 60 s.';

  @override
  String get seedWarning =>
      'Cualquiera que tenga estas palabras se convierte en ti. Nadie puede restablecerlas: si pierdes las palabras, pierdes la cuenta.';

  @override
  String get seedSavedCheckbox => 'Guardé mis palabras en un lugar seguro';

  @override
  String get verifyTitle => 'Comprueba tu frase';

  @override
  String verifyPrompt(int number) {
    return '¿Cuál es la palabra n.º $number?';
  }

  @override
  String verifyProgress(int done, int total) {
    return '$done de $total';
  }

  @override
  String get verifyWrong =>
      'No es correcta. Revisa las palabras que guardaste.';

  @override
  String get verifyShowAgain => 'Ver mis palabras otra vez';

  @override
  String get restoreTitle => 'Restaurar';

  @override
  String get restoreIntro =>
      'Escribe o pega tus 12 o 24 palabras de recuperación, separadas por espacios.';

  @override
  String restoreWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras',
      one: '1 palabra',
    );
    return '$_temp0';
  }

  @override
  String restoreUnknownWord(String word) {
    return 'Palabra desconocida: $word';
  }

  @override
  String get restoreInvalid =>
      'Estas palabras no forman una frase válida. Revisa el orden y la ortografía.';

  @override
  String get restoreAction => 'Restaurar mi cuenta';

  @override
  String homeGreeting(String name) {
    return 'Hola, $name';
  }

  @override
  String get homeYourId => 'TU ID';

  @override
  String get homeComingSoon => 'Las conversaciones llegarán pronto.';

  @override
  String get panicTooltip => 'Botón de pánico';

  @override
  String get panicTitle => 'Borrarlo todo';

  @override
  String get panicBody =>
      'Elimina tus mensajes, contactos y claves de este teléfono, pide a los relays que borren lo que guardan para ti y cierra tu sesión. Para volver necesitarás tu frase de recuperación.';

  @override
  String get panicHold => 'Mantén pulsado para borrar';

  @override
  String get panicHolding => 'Sigue pulsando…';

  @override
  String relayOnline(int count, int total) {
    return 'Conectado · $count/$total';
  }

  @override
  String get relayConnecting => 'Conectando…';

  @override
  String get relayOffline => 'Sin conexión · reintentando';

  @override
  String get relaysTitle => 'Relays';

  @override
  String get relaysIntro =>
      'Tus mensajes pasan por estos relays. No pueden leerlos ni ver quién los envió, pero un relay puede ver tu dirección IP.';

  @override
  String get relayUp => 'Conectado';

  @override
  String get relayDown => 'Inaccesible';

  @override
  String get relaysRetry => 'Reintentar ahora';

  @override
  String get homeEmptyTitle => 'Aún no hay conversaciones';

  @override
  String get homeEmptyBody =>
      'Comparte tu ID para que puedan escribirte, o pega el ID de alguien para empezar.';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get myId => 'Mi ID';

  @override
  String get myIdBody =>
      'Compártelo para que puedan escribirte. No revela nada sobre quién eres.';

  @override
  String get copyId => 'Copiar ID';

  @override
  String get idCopied => 'ID copiado';

  @override
  String get newChatHint => 'Pega un ID (npub…)';

  @override
  String get newChatInvalid =>
      'Este ID no es válido. Comprueba que se copió completo.';

  @override
  String get newChatSelf => 'Ese es tu propio ID.';

  @override
  String get newChatStart => 'Empezar a chatear';

  @override
  String get chatInputHint => 'Mensaje';

  @override
  String get chatSend => 'Enviar';

  @override
  String chatEmpty(String name) {
    return 'Los mensajes están cifrados de extremo a extremo. Solo $name puede leerlos.';
  }

  @override
  String get chatEncrypted => 'Cifrado de extremo a extremo';

  @override
  String get messageFailed => 'No enviado · toca para reintentar';

  @override
  String youPrefix(String text) {
    return 'Tú: $text';
  }

  @override
  String get paste => 'Pegar';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get sectionNetwork => 'RED';

  @override
  String get relaysManage => 'Relays';

  @override
  String get relayAddHint => 'wss://relay.example';

  @override
  String get relayAdd => 'Añadir';

  @override
  String get relayInvalid => 'Solo se aceptan direcciones seguras wss://.';

  @override
  String get relayRemove => 'Quitar';

  @override
  String get relayKeepOne => 'Mantén al menos un relay.';

  @override
  String get sectionParanoia => 'MODO PARANOIA';

  @override
  String get paranoiaMaster => 'Modo paranoia';

  @override
  String get paranoiaMasterBody =>
      'Máxima protección contra spyware y teclados hostiles. Menos cómodo.';

  @override
  String get paranoiaKeyboard => 'Teclado de Whisper';

  @override
  String get paranoiaKeyboardBody =>
      'Escribe con el teclado propio de Whisper: el teclado de tu teléfono nunca ve lo que escribes.';

  @override
  String get paranoiaShuffle => 'Mezclar teclas';

  @override
  String get paranoiaShuffleBody =>
      'Las letras cambian de sitio cada vez que se abre el teclado, así los toques grabados no revelan nada.';

  @override
  String get paranoiaMask => 'Ocultar lo que escribo';

  @override
  String get paranoiaMaskBody =>
      'Muestra •••• en lugar del texto que escribes.';

  @override
  String get paranoiaBlur => 'Difuminar mensajes';

  @override
  String get paranoiaBlurBody =>
      'Los mensajes siguen difuminados hasta que los mantienes pulsados.';

  @override
  String get paranoiaA11y => 'Ocultar a los servicios de accesibilidad';

  @override
  String get paranoiaA11yBody =>
      'El spyware suele leer la pantalla a través de la accesibilidad. Esto también bloquea los lectores de pantalla (TalkBack).';

  @override
  String get paranoiaSecure => 'Bloquear capturas en todas partes';

  @override
  String get paranoiaSecureBody =>
      'Las capturas de pantalla, la grabación de pantalla y la vista previa en apps recientes muestran una pantalla negra.';

  @override
  String get paranoiaLimits =>
      'Ninguna app puede proteger un teléfono totalmente comprometido (rooteado, o con spyware con acceso al sistema). El modo paranoia frena los casos habituales.';

  @override
  String get a11yWarningTitle => 'Apps que pueden leer tu pantalla';

  @override
  String get a11yWarningBody =>
      'Estas apps tienen acceso de accesibilidad y podrían leer lo que se muestra:';

  @override
  String get a11yWarningAction => 'Revisar en los ajustes del sistema';

  @override
  String get sectionDanger => 'ZONA DE PELIGRO';

  @override
  String get chatHoldToRead => 'Mantén pulsado para leer';

  @override
  String get keyboardSpace => 'espacio';

  @override
  String get requestsTitle => 'Solicitudes';

  @override
  String requestsRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solicitudes de mensaje',
      one: '1 solicitud de mensaje',
    );
    return '$_temp0';
  }

  @override
  String get requestsEmpty => 'No hay solicitudes pendientes.';

  @override
  String requestBanner(String name) {
    return '$name quiere chatear contigo. No ve nada sobre ti, ni siquiera tu foto, hasta que aceptes.';
  }

  @override
  String get requestAccept => 'Aceptar';

  @override
  String get requestRefuse => 'Rechazar';

  @override
  String get requestBlock => 'Bloquear';

  @override
  String requestBlocked(String name) {
    return 'Has bloqueado a $name.';
  }

  @override
  String get sectionProfile => 'PERFIL';

  @override
  String get photoFromGallery => 'Elegir foto';

  @override
  String get photoFromCamera => 'Hacer foto';

  @override
  String get photoRemove => 'Quitar';

  @override
  String get photoPrivacy =>
      'Solo la reciben los contactos que aceptaste, cifrada de extremo a extremo. Se eliminan de la foto la ubicación y los datos de la cámara.';

  @override
  String get photoError => 'No se puede usar esta imagen. Prueba con otra.';

  @override
  String get chatMenu => 'Más';

  @override
  String blockConfirmTitle(String name) {
    return '¿Bloquear a $name?';
  }

  @override
  String get blockConfirmBody =>
      'Esta conversación se eliminará de este teléfono y nada de lo que envíe te llegará. No recibirá ningún aviso.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get blockedPeople => 'Personas bloqueadas';

  @override
  String get blockedEmpty => 'No hay nadie bloqueado.';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get attach => 'Enviar una foto';

  @override
  String get imagePreviewTitle => '¿Enviar esta foto?';

  @override
  String get imageAnonymized =>
      'Se eliminaron la ubicación, los datos de la cámara y la fecha. La foto se redimensionó.';

  @override
  String get imageSend => 'Enviar';

  @override
  String get photoPreview => '📷 Foto';

  @override
  String get imagePendingRequest =>
      'Foto oculta hasta que aceptes esta solicitud';

  @override
  String get imageUnavailable => 'Foto no disponible';

  @override
  String get lockTitle => 'Whisper está bloqueado';

  @override
  String get lockEnterPin => 'Introduce tu PIN';

  @override
  String get lockWrongPin => 'PIN incorrecto';

  @override
  String lockRetryIn(int seconds) {
    return 'Demasiados intentos. Vuelve a intentarlo en $seconds s.';
  }

  @override
  String get lockBiometric => 'Desbloquear con huella o rostro';

  @override
  String get lockBiometricPrompt => 'Desbloquear Whisper';

  @override
  String get lockNow => 'Bloquear ahora';

  @override
  String get lockChecking => 'Comprobando…';

  @override
  String get sectionAppLock => 'BLOQUEO DE LA APP';

  @override
  String get appLockSetup => 'Proteger con un PIN';

  @override
  String get appLockSetupBody =>
      'La clave de tu cuenta se cifra con tu PIN. Sin él, nada se abre, aunque tengan el teléfono en la mano.';

  @override
  String get appLockBiometrics => 'Huella o rostro';

  @override
  String get appLockBiometricsBody =>
      'Usa la biometría segura del teléfono. Si añades una huella nueva, se desactiva: se te pedirá el PIN.';

  @override
  String get appLockChangePin => 'Cambiar PIN';

  @override
  String get appLockAutoLock => 'Bloquear automáticamente';

  @override
  String get autoLockImmediately => 'Inmediatamente';

  @override
  String get autoLockMinute => 'Tras 1 min';

  @override
  String get autoLockFiveMinutes => 'Tras 5 min';

  @override
  String get appLockDuress => 'PIN de coacción';

  @override
  String get appLockDuressBody =>
      'Un segundo PIN. Si lo introduces en la pantalla de bloqueo, borra todo en silencio y abre una app vacía.';

  @override
  String get appLockDuressSet => 'Configurar un PIN de coacción';

  @override
  String get appLockDuressRemove => 'Quitar el PIN de coacción';

  @override
  String get appLockTurnOff => 'Desactivar el bloqueo de la app';

  @override
  String get pinNewTitle => 'Elige un PIN';

  @override
  String get pinConfirmTitle => 'Confirma tu PIN';

  @override
  String get pinCurrentTitle => 'PIN actual';

  @override
  String get pinDuressTitle => 'Elige un PIN de coacción';

  @override
  String get pinRules => 'De 6 a 12 dígitos. Evita 123456 o dígitos repetidos.';

  @override
  String get pinWeak => 'Demasiado fácil de adivinar. Elige otro.';

  @override
  String get pinMismatch => 'Los PIN no coinciden. Inténtalo de nuevo.';

  @override
  String get pinSameAsReal => 'Debe ser distinto de tu PIN.';

  @override
  String get pinEncrypting => 'Cifrando tus claves…';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signOutTitle => '¿Cerrar sesión en este teléfono?';

  @override
  String get signOutBody =>
      'Tus mensajes, contactos y claves se borrarán de este teléfono. Para volver necesitarás tu frase de recuperación.';

  @override
  String get biometricCancel => 'Usar PIN';

  @override
  String get relayTorStarting => 'Iniciando Tor…';

  @override
  String get relayTorFailed => 'Tor inaccesible · reintentando';

  @override
  String get relaysIntroTor =>
      'Tu conexión pasa por Tor: los relays no pueden ver tu dirección IP, ni leer tus mensajes ni ver quién los envió.';

  @override
  String get torToggle => 'Conectar a través de Tor (recomendado)';

  @override
  String get torToggleBody =>
      'Oculta tu dirección IP a los relays y ayuda a sortear la censura. Conectarse tarda unos segundos más.';

  @override
  String get torOffWarning =>
      'Sin Tor, los relays y tu proveedor de red pueden ver que usas Whisper y tu dirección IP.';

  @override
  String get scanQr => 'Escanear un código QR';

  @override
  String get scanHint => 'Apunta la cámara a un código QR de Whisper';

  @override
  String get scanInvalid => 'Este código QR no es un ID de Whisper.';

  @override
  String get myIdQrHint =>
      'Deja que un amigo escanee este código para escribirte.';

  @override
  String get safetyNumber => 'Verificar número de seguridad';

  @override
  String safetyNumberBody(String name) {
    return 'Compara estos números con $name, en persona o en una llamada. Si coinciden en ambos teléfonos, nadie está interceptando tu conversación.';
  }

  @override
  String get safetyMarkVerified => 'Marcar como verificado';

  @override
  String get verified => 'Verificado';

  @override
  String get rename => 'Renombrar';

  @override
  String get renameHint => 'Apodo (solo en este teléfono)';

  @override
  String get save => 'Guardar';

  @override
  String get vaultErrorTitle => 'Almacenamiento seguro no disponible';

  @override
  String get vaultErrorBody =>
      'El almacenamiento seguro de tu teléfono no respondió. No se borró nada. Cierra Whisper y vuelve a abrirlo; si continúa, reinicia tu teléfono.';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String groupPickMembers(int max) {
    return 'Miembros (hasta $max)';
  }

  @override
  String get groupNoContacts =>
      'Primero añade contactos: solo puedes invitar a personas que hayas aceptado.';

  @override
  String get groupCreate => 'Crear';

  @override
  String groupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String get groupEmpty =>
      'Los mensajes están cifrados de extremo a extremo y se envían por separado a cada miembro. Ningún servidor sabe que este grupo existe.';

  @override
  String get groupInfo => 'Info del grupo';

  @override
  String get groupAdmin => 'Admin';

  @override
  String get groupYou => 'Tú';

  @override
  String get groupRename => 'Renombrar grupo';

  @override
  String get groupAddMembers => 'Añadir miembros';

  @override
  String get groupRemoveMember => 'Quitar del grupo';

  @override
  String get groupLeave => 'Salir del grupo';

  @override
  String groupLeaveConfirm(String name) {
    return '¿Salir de “$name”? Sus mensajes se eliminarán de este teléfono.';
  }

  @override
  String get groupRemoved => 'Ya no eres miembro de este grupo.';

  @override
  String groupInvite(String name) {
    return '$name te invitó a este grupo. Si lo rechazas, nadie se entera.';
  }

  @override
  String get groupInviteRow => 'Invitación a un grupo';

  @override
  String get groupNoAdminLeave =>
      'Como admin, no puedes salir. Quita a los miembros en su lugar.';

  @override
  String groupNamePrefix(String name, String text) {
    return '$name: $text';
  }

  @override
  String get newChannel => 'Nuevo canal';

  @override
  String get joinChannel => 'Unirse a un canal';

  @override
  String get channelName => 'Nombre del canal';

  @override
  String get channelAbout => 'Descripción (opcional)';

  @override
  String get channelPublic => 'Público';

  @override
  String get channelPublicBody =>
      'Cualquiera con el enlace de invitación o el QR puede seguirlo y compartirlo.';

  @override
  String get channelPrivate => 'Privado';

  @override
  String get channelPrivateBody =>
      'Tú invitas a los contactos. Los seguidores no tienen botón para compartir.';

  @override
  String get channelCreate => 'Crear canal';

  @override
  String get channelEmptyAdmin =>
      'Solo tú puedes publicar aquí. Los seguidores pueden reaccionar, de forma anónima.';

  @override
  String get channelEmptyViewer => 'Aún no hay publicaciones.';

  @override
  String get channelBadge => 'Canal';

  @override
  String get channelFollowers =>
      'Solo publica el admin · las reacciones son anónimas';

  @override
  String get channelInfo => 'Info del canal';

  @override
  String get channelInvite => 'Invitar';

  @override
  String get channelInviteBody =>
      'Escanea o comparte este código para seguir el canal. Contiene la clave para leerlo: compártelo solo donde quieras.';

  @override
  String get channelInviteCopied => 'Invitación copiada';

  @override
  String get channelCopyInvite => 'Copiar invitación';

  @override
  String get channelInviteContacts => 'Invitar contactos';

  @override
  String get channelInvitesSent => 'Invitaciones enviadas';

  @override
  String get channelLeave => 'Salir del canal';

  @override
  String channelLeaveConfirm(String name) {
    return '¿Salir de “$name”? Sus publicaciones se eliminarán de este teléfono. El admin no se enterará.';
  }

  @override
  String channelInviteFrom(String name) {
    return '$name te invitó a seguir este canal.';
  }

  @override
  String get channelInviteRow => 'Invitación a un canal';

  @override
  String get channelJoinHint => 'Pega una invitación (whisper-channel:…)';

  @override
  String get channelJoinInvalid => 'Esta invitación de canal no es válida.';

  @override
  String get channelJoin => 'Seguir';

  @override
  String get channelEdit => 'Editar canal';

  @override
  String get channelReact => 'Reaccionar';

  @override
  String get channelPostHint => 'Publica para tus seguidores';

  @override
  String get channelAdminNote =>
      'La clave de tu canal viene de tu identidad: restaurar tu frase de recuperación la devuelve.';

  @override
  String get relayTorDisguising => 'Iniciando una conexión camuflada…';

  @override
  String get connProtected => 'Conexión protegida';

  @override
  String get connDisguised => 'Conexión camuflada';

  @override
  String get connProtectedBody =>
      'A través de Tor: los relays no pueden ver tu dirección IP.';

  @override
  String get connDisguisedBody =>
      'A través de Tor, camuflada como tráfico normal: tu red no puede saber que usas Tor.';

  @override
  String get torDisguise => 'Camuflar mi conexión';

  @override
  String get torDisguiseBody =>
      'Para lugares donde usar Tor ya es un riesgo. Tu tráfico parece datos aleatorios o una videollamada. Tarda más en conectarse. Whisper lo activa por sí solo cuando Tor está bloqueado.';

  @override
  String get bgConnectionTitle => 'Conexión privada activa';

  @override
  String get bgConnectionText => 'Whisper puede recibir tus mensajes.';

  @override
  String notifyNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes nuevos',
      one: 'Mensaje nuevo',
    );
    return '$_temp0';
  }

  @override
  String get bgToggle => 'Recibir en segundo plano';

  @override
  String get bgToggleBody =>
      'Mantiene una conexión privada abierta cuando Whisper está cerrado, con una notificación permanente. Los avisos nunca muestran quién escribió ni qué. Usa más batería. Sin servicios de Google.';

  @override
  String get sectionBackup => 'COPIA DE SEGURIDAD';

  @override
  String get backupExport => 'Exportar historial';

  @override
  String get backupExportBody =>
      'Guarda un archivo cifrado. Solo tu frase de recuperación puede abrirlo, en cualquier teléfono.';

  @override
  String get backupImport => 'Importar historial';

  @override
  String get backupImportBody =>
      'Añade las conversaciones de una copia hecha con esta cuenta. No se sobrescribe nada de lo que hay aquí.';

  @override
  String get backupWorking => 'Preparando la copia cifrada…';

  @override
  String get backupSaved => 'Copia cifrada guardada';

  @override
  String backupImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos restaurados',
      one: '1 elemento restaurado',
      zero: 'Nada nuevo en esta copia',
    );
    return '$_temp0';
  }

  @override
  String get backupWrongKey =>
      'Esta copia pertenece a otra cuenta o está dañada.';

  @override
  String get backupBadFile => 'Esto no es una copia de seguridad de Whisper.';

  @override
  String get backupNewer =>
      'Esta copia se hizo con una versión más reciente de Whisper.';

  @override
  String get backupFailed => 'No se pudo leer ni escribir el archivo.';

  @override
  String get searchHint => 'Buscar';

  @override
  String get searchNoResults => 'Sin resultados';

  @override
  String get filterAll => 'Todo';

  @override
  String get filterChats => 'Chats';

  @override
  String get filterGroups => 'Grupos';

  @override
  String get filterChannels => 'Canales';

  @override
  String get filterEmpty => 'Aún no hay nada aquí';

  @override
  String get newChatSubtitle => 'Escribe a alguien con su ID';

  @override
  String get newGroupSubtitle => 'Privado, cifrado de extremo a extremo';

  @override
  String get newChannelSubtitle => 'Difunde a muchas personas';

  @override
  String get joinChannelSubtitle => 'Escanea o pega una invitación';

  @override
  String get startSomething => 'Empezar';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get nicknameTitle => 'Apodo';

  @override
  String get nicknameHint => 'Tu apodo';

  @override
  String nicknameBody(String username) {
    return 'Solo lo ven los contactos que aceptaste, cifrado de extremo a extremo. Déjalo vacío para usar $username.';
  }

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String updateAvailableBody(String version) {
    return 'Whisper $version está listo para instalar.';
  }

  @override
  String updateBanner(String version) {
    return 'Whisper $version está disponible';
  }

  @override
  String get updateSheetBody =>
      'Se descarga a través de Tor desde las versiones de Whisper en GitHub y se verifica antes de instalar: misma clave de firma que esta app y una versión más reciente.';

  @override
  String get updateInstall => 'Descargar e instalar';

  @override
  String get updateDownloading => 'Descargando…';

  @override
  String get updateInstalling => 'Instalando…';

  @override
  String get updateFailedNetwork =>
      'No se pudo conectar con GitHub. Inténtalo más tarde.';

  @override
  String get updateFailedChecksum =>
      'La descarga estaba dañada. Se eliminó; inténtalo de nuevo.';

  @override
  String get updateFailedSignature =>
      'Este archivo no está firmado con la clave de Whisper. No se instaló.';

  @override
  String get updateFailedPermission =>
      'Permite que Whisper instale actualizaciones, luego vuelve y toca de nuevo.';

  @override
  String get updateFailedInstall =>
      'Android no instaló la actualización. Inténtalo más tarde.';

  @override
  String get sectionAbout => 'Acerca de';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get updateAutoCheck => 'Buscar actualizaciones';

  @override
  String get updateAutoCheckBody =>
      'Más o menos una vez al día, a través de Tor: GitHub solo ve una salida de Tor.';

  @override
  String get updateCheckNow => 'Comprobar ahora';

  @override
  String get updateUpToDate => 'Tienes la última versión.';

  @override
  String get updateStoreManaged =>
      'Las actualizaciones llegan desde la tienda donde instalaste Whisper.';

  @override
  String get paranoiaSecureIos => 'Ocultar la pantalla al grabar';

  @override
  String get paranoiaSecureBodyIos =>
      'El iPhone no permite bloquear las capturas de pantalla. Whisper oculta su pantalla mientras se graba o se duplica, y en el selector de apps.';

  @override
  String get iosBackgroundNote =>
      'En iPhone, los mensajes llegan cuando Whisper está abierto: iOS no deja que las apps mantengan una conexión privada en segundo plano. Los relays guardan los mensajes al menos dos días.';

  @override
  String get updateViaTor => 'Descargar a través de Tor';

  @override
  String get updateViaTorBody =>
      'Más lento, pero nadie puede ver que este teléfono descarga Whisper.';

  @override
  String get updateDirectWarning =>
      'Más rápido, pero tu proveedor de internet y GitHub verán que este teléfono descarga Whisper. Evítalo donde Whisper o Tor estén vigilados. El archivo se verifica igual.';
}
