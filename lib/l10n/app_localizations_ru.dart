// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Whisper';

  @override
  String get appTagline =>
      'Говори свободно. Без номера, без имени, без следов.';

  @override
  String get back => 'Назад';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get welcomeCreate => 'Создать личность';

  @override
  String get welcomeRestore => 'У меня есть фраза восстановления';

  @override
  String get welcomeFootnote =>
      'Без номера телефона. Без email. Твои ключи никогда не покидают этот телефон.';

  @override
  String get createGenerating => 'Создаём твои ключи…';

  @override
  String get createUsernameLabel => 'ТЫ —';

  @override
  String get createUsernameCaption =>
      'Получено из твоего ключа. Его никто не выбирал, и никто не сможет связать его с тобой.';

  @override
  String get seedTitle => 'Фраза восстановления';

  @override
  String get seedIntro =>
      'Эти слова — единственный способ вернуть аккаунт. Whisper их не хранит: ты видишь их в первый и последний раз. Сохрани их в менеджере паролей (Bitwarden, 1Password…) или на бумаге.';

  @override
  String get seedRevealHint =>
      'Нажми, чтобы показать. Убедись, что никто не смотрит.';

  @override
  String get seedCopy => 'Копировать';

  @override
  String get seedCopied => 'Скопировано. Буфер обмена очистится через 60 с.';

  @override
  String get seedWarning =>
      'Любой, у кого есть эти слова, становится тобой. Сбросить их нельзя: потерянные слова — потерянный аккаунт.';

  @override
  String get seedSavedCheckbox => 'Мои слова сохранены в надёжном месте';

  @override
  String get verifyTitle => 'Проверь фразу';

  @override
  String verifyPrompt(int number) {
    return 'Какое слово под номером $number?';
  }

  @override
  String verifyProgress(int done, int total) {
    return '$done из $total';
  }

  @override
  String get verifyWrong => 'Не совсем. Сверься с сохранёнными словами.';

  @override
  String get verifyShowAgain => 'Показать слова ещё раз';

  @override
  String get restoreTitle => 'Восстановление';

  @override
  String get restoreIntro =>
      'Введи или вставь 12 или 24 слова восстановления через пробел.';

  @override
  String restoreWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count слова',
      many: '$count слов',
      few: '$count слова',
      one: '$count слово',
    );
    return '$_temp0';
  }

  @override
  String restoreUnknownWord(String word) {
    return 'Неизвестное слово: $word';
  }

  @override
  String get restoreInvalid =>
      'Эти слова не образуют правильную фразу. Проверь порядок и написание.';

  @override
  String get restoreAction => 'Восстановить аккаунт';

  @override
  String homeGreeting(String name) {
    return 'Привет, $name';
  }

  @override
  String get homeYourId => 'ТВОЙ ID';

  @override
  String get homeComingSoon => 'Переписки скоро появятся.';

  @override
  String get panicTooltip => 'Тревожная кнопка';

  @override
  String get panicTitle => 'Стереть всё';

  @override
  String get panicBody =>
      'Удаляет с этого телефона твои сообщения, контакты и ключи, просит ретрансляторы удалить то, что они хранят для тебя, и выполняет выход. Чтобы вернуться, понадобится фраза восстановления.';

  @override
  String get panicHold => 'Удерживай, чтобы стереть';

  @override
  String get panicHolding => 'Продолжай удерживать…';

  @override
  String relayOnline(int count, int total) {
    return 'Подключено · $count/$total';
  }

  @override
  String get relayConnecting => 'Подключение…';

  @override
  String get relayOffline => 'Нет сети · повторяем';

  @override
  String get relaysTitle => 'Ретрансляторы';

  @override
  String get relaysIntro =>
      'Твои сообщения проходят через эти ретрансляторы. Они не могут их прочитать или узнать отправителя, но ретранслятор видит твой IP-адрес.';

  @override
  String get relayUp => 'Подключён';

  @override
  String get relayDown => 'Недоступен';

  @override
  String get relaysRetry => 'Повторить';

  @override
  String get homeEmptyTitle => 'Пока нет переписок';

  @override
  String get homeEmptyBody =>
      'Поделись своим ID, чтобы тебе могли написать, или вставь чужой ID, чтобы начать.';

  @override
  String get newChat => 'Новый чат';

  @override
  String get myId => 'Мой ID';

  @override
  String get myIdBody =>
      'Поделись им, чтобы тебе могли написать. Он ничего не говорит о том, кто ты.';

  @override
  String get copyId => 'Копировать ID';

  @override
  String get idCopied => 'ID скопирован';

  @override
  String get newChatHint => 'Вставь ID (npub…)';

  @override
  String get newChatInvalid =>
      'Это неверный ID. Проверь, что он скопирован целиком.';

  @override
  String get newChatSelf => 'Это твой собственный ID.';

  @override
  String get newChatStart => 'Начать чат';

  @override
  String get chatInputHint => 'Сообщение';

  @override
  String get chatSend => 'Отправить';

  @override
  String chatEmpty(String name) {
    return 'Сообщения защищены сквозным шифрованием. Прочитать их может только $name.';
  }

  @override
  String get chatEncrypted => 'Сквозное шифрование';

  @override
  String get messageFailed => 'Не отправлено · нажми, чтобы повторить';

  @override
  String youPrefix(String text) {
    return 'Ты: $text';
  }

  @override
  String get paste => 'Вставить';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get sectionNetwork => 'СЕТЬ';

  @override
  String get relaysManage => 'Ретрансляторы';

  @override
  String get relayAddHint => 'wss://relay.example';

  @override
  String get relayAdd => 'Добавить';

  @override
  String get relayInvalid => 'Принимаются только защищённые адреса wss://.';

  @override
  String get relayRemove => 'Удалить';

  @override
  String get relayKeepOne => 'Оставь хотя бы один ретранслятор.';

  @override
  String get sectionParanoia => 'РЕЖИМ ПАРАНОЙИ';

  @override
  String get paranoiaMaster => 'Режим паранойи';

  @override
  String get paranoiaMasterBody =>
      'Максимальная защита от шпионских программ и враждебных клавиатур. Менее удобно.';

  @override
  String get paranoiaKeyboard => 'Клавиатура Whisper';

  @override
  String get paranoiaKeyboardBody =>
      'Печатай на собственной клавиатуре Whisper: клавиатура телефона никогда не увидит, что ты пишешь.';

  @override
  String get paranoiaShuffle => 'Перемешивать клавиши';

  @override
  String get paranoiaShuffleBody =>
      'Буквы меняются местами при каждом открытии клавиатуры, поэтому записанные касания ничего не выдают.';

  @override
  String get paranoiaMask => 'Скрывать вводимый текст';

  @override
  String get paranoiaMaskBody =>
      'Показывает •••• вместо текста, который ты пишешь.';

  @override
  String get paranoiaBlur => 'Размывать сообщения';

  @override
  String get paranoiaBlurBody =>
      'Сообщения остаются размытыми, пока ты не нажмёшь и не удержишь их.';

  @override
  String get paranoiaA11y => 'Скрыть от спецвозможностей';

  @override
  String get paranoiaA11yBody =>
      'Шпионские программы часто читают экран через специальные возможности. Это также блокирует программы чтения с экрана (TalkBack).';

  @override
  String get paranoiaSecure => 'Запретить скриншоты везде';

  @override
  String get paranoiaSecureBody =>
      'Скриншоты, запись экрана и превью приложения в списке недавних показывают чёрный экран.';

  @override
  String get paranoiaLimits =>
      'Ни одно приложение не защитит полностью взломанный телефон (с root-доступом или со шпионской программой с системными правами). Режим паранойи защищает от типичных случаев.';

  @override
  String get a11yWarningTitle => 'Приложения, которые могут читать экран';

  @override
  String get a11yWarningBody =>
      'У этих приложений есть доступ к специальным возможностям, и они могут читать то, что на экране:';

  @override
  String get a11yWarningAction => 'Проверить в настройках системы';

  @override
  String get sectionDanger => 'ОПАСНАЯ ЗОНА';

  @override
  String get chatHoldToRead => 'Удерживай, чтобы прочитать';

  @override
  String get keyboardSpace => 'пробел';

  @override
  String get requestsTitle => 'Запросы';

  @override
  String requestsRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count запроса на переписку',
      many: '$count запросов на переписку',
      few: '$count запроса на переписку',
      one: '$count запрос на переписку',
    );
    return '$_temp0';
  }

  @override
  String get requestsEmpty => 'Нет ожидающих запросов.';

  @override
  String requestBanner(String name) {
    return '$name хочет начать с тобой переписку. Пока ты не примешь запрос, этот человек ничего о тебе не видит, даже фото.';
  }

  @override
  String get requestAccept => 'Принять';

  @override
  String get requestRefuse => 'Отклонить';

  @override
  String get requestBlock => 'Заблокировать';

  @override
  String requestBlocked(String name) {
    return '$name в списке заблокированных.';
  }

  @override
  String get sectionProfile => 'ПРОФИЛЬ';

  @override
  String get photoFromGallery => 'Выбрать фото';

  @override
  String get photoFromCamera => 'Сделать фото';

  @override
  String get photoRemove => 'Удалить';

  @override
  String get photoPrivacy =>
      'Его получат только принятые тобой контакты, со сквозным шифрованием. Геоданные и сведения о камере удаляются из фото.';

  @override
  String get photoError =>
      'Это изображение нельзя использовать. Попробуй другое.';

  @override
  String get chatMenu => 'Ещё';

  @override
  String blockConfirmTitle(String name) {
    return 'Заблокировать $name?';
  }

  @override
  String get blockConfirmBody =>
      'Этот чат будет удалён с этого телефона, и сообщения от этого человека больше не будут до тебя доходить. Уведомления об этом не будет.';

  @override
  String get cancel => 'Отмена';

  @override
  String get blockedPeople => 'Заблокированные';

  @override
  String get blockedEmpty => 'Никто не заблокирован.';

  @override
  String get unblock => 'Разблокировать';

  @override
  String get attach => 'Отправить фото';

  @override
  String get imagePreviewTitle => 'Отправить это фото?';

  @override
  String get imageAnonymized =>
      'Геоданные, сведения о камере и дата удалены. Размер фото уменьшен.';

  @override
  String get imageSend => 'Отправить';

  @override
  String get photoPreview => '📷 Фото';

  @override
  String get imagePendingRequest =>
      'Фото скрыто, пока ты не примешь этот запрос';

  @override
  String get imageUnavailable => 'Фото недоступно';

  @override
  String get lockTitle => 'Whisper заблокирован';

  @override
  String get lockEnterPin => 'Введи PIN';

  @override
  String get lockWrongPin => 'Неверный PIN';

  @override
  String lockRetryIn(int seconds) {
    return 'Слишком много попыток. Повтори через $seconds с.';
  }

  @override
  String get lockBiometric => 'Разблокировать отпечатком или лицом';

  @override
  String get lockBiometricPrompt => 'Разблокировать Whisper';

  @override
  String get lockNow => 'Заблокировать сейчас';

  @override
  String get lockChecking => 'Проверка…';

  @override
  String get sectionAppLock => 'БЛОКИРОВКА ПРИЛОЖЕНИЯ';

  @override
  String get appLockSetup => 'Защитить PIN-кодом';

  @override
  String get appLockSetupBody =>
      'Ключ твоего аккаунта зашифрован твоим PIN. Без него ничего не откроется, даже если телефон в чужих руках.';

  @override
  String get appLockBiometrics => 'Отпечаток или лицо';

  @override
  String get appLockBiometricsBody =>
      'Использует защищённую биометрию телефона. Если добавить новый отпечаток, она отключится и будет запрошен PIN.';

  @override
  String get appLockChangePin => 'Сменить PIN';

  @override
  String get appLockAutoLock => 'Автоблокировка';

  @override
  String get autoLockImmediately => 'Сразу';

  @override
  String get autoLockMinute => 'Через 1 мин';

  @override
  String get autoLockFiveMinutes => 'Через 5 мин';

  @override
  String get appLockDuress => 'PIN под принуждением';

  @override
  String get appLockDuressBody =>
      'Второй PIN. Если ввести его на экране блокировки, он незаметно сотрёт всё и откроет пустое приложение.';

  @override
  String get appLockDuressSet => 'Задать PIN под принуждением';

  @override
  String get appLockDuressRemove => 'Удалить PIN под принуждением';

  @override
  String get appLockTurnOff => 'Отключить блокировку';

  @override
  String get pinNewTitle => 'Придумай PIN';

  @override
  String get pinConfirmTitle => 'Повтори PIN';

  @override
  String get pinCurrentTitle => 'Текущий PIN';

  @override
  String get pinDuressTitle => 'Задай PIN под принуждением';

  @override
  String get pinRules =>
      'От 6 до 12 цифр. Избегай 123456 и повторяющихся цифр.';

  @override
  String get pinWeak => 'Слишком легко угадать. Выбери другой.';

  @override
  String get pinMismatch => 'PIN не совпадают. Попробуй ещё раз.';

  @override
  String get pinSameAsReal => 'Должен отличаться от твоего PIN.';

  @override
  String get pinEncrypting => 'Шифруем твои ключи…';

  @override
  String get signOut => 'Выйти';

  @override
  String get signOutTitle => 'Выйти на этом телефоне?';

  @override
  String get signOutBody =>
      'Твои сообщения, контакты и ключи будут стёрты с этого телефона. Чтобы вернуться, понадобится фраза восстановления.';

  @override
  String get biometricCancel => 'Ввести PIN';

  @override
  String get relayTorStarting => 'Запуск Tor…';

  @override
  String get relayTorFailed => 'Tor недоступен · повторяем';

  @override
  String get relaysIntroTor =>
      'Твоё соединение идёт через Tor: ретрансляторы не видят твой IP-адрес, не могут прочитать сообщения и не знают, кто их отправил.';

  @override
  String get torToggle => 'Через Tor (рекомендуется)';

  @override
  String get torToggleBody =>
      'Скрывает твой IP-адрес от ретрансляторов и помогает обходить цензуру. Подключение занимает на несколько секунд дольше.';

  @override
  String get torOffWarning =>
      'Без Tor ретрансляторы и твой интернет-провайдер видят, что ты используешь Whisper, и знают твой IP-адрес.';

  @override
  String get scanQr => 'Сканировать QR-код';

  @override
  String get scanHint => 'Наведи камеру на QR-код Whisper';

  @override
  String get scanInvalid => 'Этот QR-код — не ID Whisper.';

  @override
  String get myIdQrHint =>
      'Дай другу отсканировать этот код, чтобы тебе можно было написать.';

  @override
  String get safetyNumber => 'Проверить код безопасности';

  @override
  String safetyNumberBody(String name) {
    return 'Сверь эти цифры с собеседником ($name) — лично или по звонку. Если на обоих телефонах они совпадают, вашу переписку никто не перехватывает.';
  }

  @override
  String get safetyMarkVerified => 'Отметить как проверенный';

  @override
  String get verified => 'Проверено';

  @override
  String get rename => 'Переименовать';

  @override
  String get renameHint => 'Имя (только на этом телефоне)';

  @override
  String get save => 'Сохранить';

  @override
  String get vaultErrorTitle => 'Защищённое хранилище недоступно';

  @override
  String get vaultErrorBody =>
      'Защищённое хранилище телефона не ответило. Ничего не удалено. Закрой Whisper и открой снова; если не поможет, перезагрузи телефон.';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get groupName => 'Название группы';

  @override
  String groupPickMembers(int max) {
    return 'Участники (до $max)';
  }

  @override
  String get groupNoContacts =>
      'Сначала добавь контакты: пригласить можно только принятые тобой контакты.';

  @override
  String get groupCreate => 'Создать';

  @override
  String groupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get groupEmpty =>
      'Сообщения защищены сквозным шифрованием и отправляются каждому участнику отдельно. Ни один сервер не знает о существовании этой группы.';

  @override
  String get groupInfo => 'О группе';

  @override
  String get groupAdmin => 'Админ';

  @override
  String get groupYou => 'Ты';

  @override
  String get groupRename => 'Переименовать группу';

  @override
  String get groupAddMembers => 'Добавить участников';

  @override
  String get groupRemoveMember => 'Удалить из группы';

  @override
  String get groupLeave => 'Выйти из группы';

  @override
  String groupLeaveConfirm(String name) {
    return 'Выйти из группы «$name»? Её сообщения будут удалены с этого телефона.';
  }

  @override
  String get groupRemoved => 'Ты больше не участник этой группы.';

  @override
  String groupInvite(String name) {
    return '$name приглашает тебя в эту группу. Если откажешься, никто не узнает.';
  }

  @override
  String get groupInviteRow => 'Приглашение в группу';

  @override
  String get groupNoAdminLeave =>
      'Админ не может выйти из группы. Вместо этого удали участников.';

  @override
  String groupNamePrefix(String name, String text) {
    return '$name: $text';
  }

  @override
  String get newChannel => 'Новый канал';

  @override
  String get joinChannel => 'Подписаться на канал';

  @override
  String get channelName => 'Название канала';

  @override
  String get channelAbout => 'Описание (необязательно)';

  @override
  String get channelPublic => 'Публичный';

  @override
  String get channelPublicBody =>
      'Любой, у кого есть ссылка-приглашение или QR-код, может подписаться и поделиться им.';

  @override
  String get channelPrivate => 'Частный';

  @override
  String get channelPrivateBody =>
      'Контакты приглашаешь только ты. У подписчиков нет кнопки «Поделиться».';

  @override
  String get channelCreate => 'Создать канал';

  @override
  String get channelEmptyAdmin =>
      'Публиковать здесь можешь только ты. Подписчики могут анонимно ставить реакции.';

  @override
  String get channelEmptyViewer => 'Пока нет публикаций.';

  @override
  String get channelBadge => 'Канал';

  @override
  String get channelFollowers => 'Публикует только админ · реакции анонимны';

  @override
  String get channelInfo => 'О канале';

  @override
  String get channelInvite => 'Пригласить';

  @override
  String get channelInviteBody =>
      'Отсканируй или отправь этот код, чтобы подписаться на канал. В нём ключ для чтения: делись им только там, где считаешь нужным.';

  @override
  String get channelInviteCopied => 'Приглашение скопировано';

  @override
  String get channelCopyInvite => 'Копировать приглашение';

  @override
  String get channelInviteContacts => 'Пригласить контакты';

  @override
  String get channelInvitesSent => 'Приглашения отправлены';

  @override
  String get channelLeave => 'Отписаться от канала';

  @override
  String channelLeaveConfirm(String name) {
    return 'Отписаться от канала «$name»? Его публикации будут удалены с этого телефона. Админ не узнает.';
  }

  @override
  String channelInviteFrom(String name) {
    return '$name приглашает тебя подписаться на этот канал.';
  }

  @override
  String get channelInviteRow => 'Приглашение в канал';

  @override
  String get channelJoinHint => 'Вставь приглашение (whisper-channel:…)';

  @override
  String get channelJoinInvalid => 'Это неверное приглашение в канал.';

  @override
  String get channelJoin => 'Подписаться';

  @override
  String get channelEdit => 'Изменить канал';

  @override
  String get channelReact => 'Реакция';

  @override
  String get channelPostHint => 'Публикация для подписчиков';

  @override
  String get channelAdminNote =>
      'Ключ твоего канала получен из твоей личности: при восстановлении по фразе он вернётся.';

  @override
  String get relayTorDisguising => 'Запуск замаскированного соединения…';

  @override
  String get connProtected => 'Защищённое соединение';

  @override
  String get connDisguised => 'Замаскированное соединение';

  @override
  String get connProtectedBody =>
      'Через Tor: ретрансляторы не видят твой IP-адрес.';

  @override
  String get connDisguisedBody =>
      'Через Tor под видом обычного трафика: твоя сеть не может определить, что ты используешь Tor.';

  @override
  String get torDisguise => 'Маскировать соединение';

  @override
  String get torDisguiseBody =>
      'Для мест, где опасно само использование Tor. Твой трафик выглядит как случайные данные или видеозвонок. Подключение медленнее. Whisper включает маскировку сам, если Tor заблокирован.';

  @override
  String get bgConnectionTitle => 'Приватное соединение активно';

  @override
  String get bgConnectionText => 'Whisper может получать твои сообщения.';

  @override
  String notifyNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count новых сообщения',
      many: '$count новых сообщений',
      few: '$count новых сообщения',
      one: '$count новое сообщение',
    );
    return '$_temp0';
  }

  @override
  String get bgToggle => 'Получать в фоне';

  @override
  String get bgToggleBody =>
      'Держит приватное соединение открытым, когда Whisper закрыт, с постоянным уведомлением. Оповещения никогда не показывают, кто написал и что. Расходует больше заряда. Сервисы Google не используются.';

  @override
  String get sectionBackup => 'РЕЗЕРВНАЯ КОПИЯ';

  @override
  String get backupExport => 'Экспорт истории';

  @override
  String get backupExportBody =>
      'Сохраняет зашифрованный файл. Открыть его можно только твоей фразой восстановления, на любом телефоне.';

  @override
  String get backupImport => 'Импорт истории';

  @override
  String get backupImportBody =>
      'Добавляет переписки из резервной копии этого аккаунта. Ничего из имеющегося не перезаписывается.';

  @override
  String get backupWorking => 'Готовим зашифрованную копию…';

  @override
  String get backupSaved => 'Зашифрованная копия сохранена';

  @override
  String backupImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Восстановлено $count элемента',
      many: 'Восстановлено $count элементов',
      few: 'Восстановлено $count элемента',
      one: 'Восстановлен $count элемент',
      zero: 'В этой копии нет ничего нового',
    );
    return '$_temp0';
  }

  @override
  String get backupWrongKey =>
      'Эта копия принадлежит другому аккаунту или повреждена.';

  @override
  String get backupBadFile => 'Это не резервная копия Whisper.';

  @override
  String get backupNewer => 'Эта копия создана более новой версией Whisper.';

  @override
  String get backupFailed => 'Не удалось прочитать или записать файл.';

  @override
  String get searchHint => 'Поиск';

  @override
  String get searchNoResults => 'Ничего не найдено';

  @override
  String get filterAll => 'Все';

  @override
  String get filterChats => 'Чаты';

  @override
  String get filterGroups => 'Группы';

  @override
  String get filterChannels => 'Каналы';

  @override
  String get filterEmpty => 'Здесь пока пусто';

  @override
  String get newChatSubtitle => 'Написать кому-то по ID';

  @override
  String get newGroupSubtitle => 'Приватная, со сквозным шифрованием';

  @override
  String get newChannelSubtitle => 'Вещание для многих';

  @override
  String get joinChannelSubtitle => 'Отсканируй или вставь приглашение';

  @override
  String get startSomething => 'Начать';

  @override
  String get appearanceTitle => 'Оформление';

  @override
  String get themeTitle => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get nicknameTitle => 'Псевдоним';

  @override
  String get nicknameHint => 'Твой псевдоним';

  @override
  String nicknameBody(String username) {
    return 'Его видят только принятые тобой контакты, со сквозным шифрованием. Оставь пустым, чтобы тебя видели как $username.';
  }

  @override
  String get updateAvailableTitle => 'Доступно обновление';

  @override
  String updateAvailableBody(String version) {
    return 'Whisper $version готов к установке.';
  }

  @override
  String updateBanner(String version) {
    return 'Доступен Whisper $version';
  }

  @override
  String get updateSheetBody =>
      'Загружается через Tor из релизов Whisper на GitHub и проверяется перед установкой: тот же ключ подписи, что у этого приложения, и более новая версия.';

  @override
  String get updateInstall => 'Загрузить и установить';

  @override
  String get updateDownloading => 'Загрузка…';

  @override
  String get updateInstalling => 'Установка…';

  @override
  String get updateFailedNetwork =>
      'Не удалось связаться с GitHub. Попробуй позже.';

  @override
  String get updateFailedChecksum =>
      'Загруженный файл повреждён и удалён. Попробуй ещё раз.';

  @override
  String get updateFailedSignature =>
      'Этот файл не подписан ключом Whisper. Он не установлен.';

  @override
  String get updateFailedPermission =>
      'Разреши Whisper устанавливать обновления, затем вернись и нажми ещё раз.';

  @override
  String get updateFailedInstall =>
      'Android не установил обновление. Попробуй позже.';

  @override
  String get sectionAbout => 'О приложении';

  @override
  String aboutVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get updateAutoCheck => 'Проверять обновления';

  @override
  String get updateAutoCheckBody =>
      'Примерно раз в день, через Tor: GitHub видит только выходной узел Tor.';

  @override
  String get updateCheckNow => 'Проверить сейчас';

  @override
  String get updateUpToDate => 'У тебя последняя версия.';

  @override
  String get updateStoreManaged =>
      'Обновления приходят из магазина, из которого установлен Whisper.';

  @override
  String get paranoiaSecureIos => 'Скрывать экран при записи';

  @override
  String get paranoiaSecureBodyIos =>
      'iPhone не позволяет запрещать скриншоты. Whisper скрывает свой экран во время записи или трансляции экрана и в переключателе приложений.';

  @override
  String get iosBackgroundNote =>
      'На iPhone сообщения приходят, пока Whisper открыт: iOS не позволяет приложениям держать приватное соединение в фоне. Ретрансляторы хранят сообщения не меньше двух дней.';
}
