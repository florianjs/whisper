// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Whisper';

  @override
  String get appTagline => '自由交谈。无需号码，无需姓名，不留痕迹。';

  @override
  String get back => '返回';

  @override
  String get continueLabel => '继续';

  @override
  String get welcomeCreate => '创建我的身份';

  @override
  String get welcomeRestore => '我有恢复短语';

  @override
  String get welcomeFootnote => '无需手机号，无需邮箱。你的密钥永远不会离开这部手机。';

  @override
  String get createGenerating => '正在生成你的密钥…';

  @override
  String get createUsernameLabel => '你的名字';

  @override
  String get createUsernameCaption => '由你的密钥生成。没有人挑选它，也没有人能把它和你联系起来。';

  @override
  String get seedTitle => '恢复短语';

  @override
  String get seedIntro =>
      '这些单词是找回账户的唯一方式。Whisper 不会保存它们：这是你唯一一次看到它们。请把它们保存在密码管理器（Bitwarden、1Password…）中或写在纸上。';

  @override
  String get seedRevealHint => '点击显示。请确保没有人在看。';

  @override
  String get seedCopy => '复制';

  @override
  String get seedCopied => '已复制。剪贴板将在 60 秒后清空。';

  @override
  String get seedWarning => '任何拿到这些单词的人都能成为你。它们无法被重置：丢失单词就等于丢失账户。';

  @override
  String get seedSavedCheckbox => '我已将单词保存在安全的地方';

  @override
  String get verifyTitle => '核对你的短语';

  @override
  String verifyPrompt(int number) {
    return '第 $number 个单词是哪一个？';
  }

  @override
  String verifyProgress(int done, int total) {
    return '$done / $total';
  }

  @override
  String get verifyWrong => '不对。请检查你保存的单词。';

  @override
  String get verifyShowAgain => '再次显示我的单词';

  @override
  String get restoreTitle => '恢复';

  @override
  String get restoreIntro => '输入或粘贴你的 12 或 24 个恢复单词，用空格分隔。';

  @override
  String restoreWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个单词',
      one: '1 个单词',
    );
    return '$_temp0';
  }

  @override
  String restoreUnknownWord(String word) {
    return '未知单词：$word';
  }

  @override
  String get restoreInvalid => '这些单词无法组成有效的短语。请检查顺序和拼写。';

  @override
  String get restoreAction => '恢复我的账户';

  @override
  String homeGreeting(String name) {
    return '你好，$name';
  }

  @override
  String get homeYourId => '你的 ID';

  @override
  String get homeComingSoon => '对话功能即将推出。';

  @override
  String get panicTooltip => '紧急按钮';

  @override
  String get panicTitle => '清除一切';

  @override
  String get panicBody =>
      '从这部手机删除你的消息、联系人和密钥，请求中继删除它们为你保存的内容，并退出登录。之后要回来，你需要恢复短语。';

  @override
  String get panicHold => '按住以清除';

  @override
  String get panicHolding => '继续按住…';

  @override
  String relayOnline(int count, int total) {
    return '已连接 · $count/$total';
  }

  @override
  String get relayConnecting => '正在连接…';

  @override
  String get relayOffline => '离线 · 正在重试';

  @override
  String get relaysTitle => '中继';

  @override
  String get relaysIntro => '你的消息经由这些中继传递。它们无法读取消息，也看不到发送者，但中继可以看到你的 IP 地址。';

  @override
  String get relayUp => '已连接';

  @override
  String get relayDown => '无法连接';

  @override
  String get relaysRetry => '立即重试';

  @override
  String get homeEmptyTitle => '还没有对话';

  @override
  String get homeEmptyBody => '分享你的 ID，别人就能给你发消息；或粘贴别人的 ID 开始聊天。';

  @override
  String get newChat => '新聊天';

  @override
  String get myId => '我的 ID';

  @override
  String get myIdBody => '分享它，别人就能给你发消息。它不会透露你是谁。';

  @override
  String get copyId => '复制 ID';

  @override
  String get idCopied => 'ID 已复制';

  @override
  String get newChatHint => '粘贴 ID（npub…）';

  @override
  String get newChatInvalid => '这不是有效的 ID。请确认已完整复制。';

  @override
  String get newChatSelf => '这是你自己的 ID。';

  @override
  String get newChatStart => '开始聊天';

  @override
  String get chatInputHint => '消息';

  @override
  String get chatSend => '发送';

  @override
  String chatEmpty(String name) {
    return '消息经过端到端加密。只有 $name 能读取。';
  }

  @override
  String get chatEncrypted => '端到端加密';

  @override
  String get messageFailed => '未发送 · 点击重试';

  @override
  String youPrefix(String text) {
    return '你：$text';
  }

  @override
  String get paste => '粘贴';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get sectionNetwork => '网络';

  @override
  String get relaysManage => '中继';

  @override
  String get relayAddHint => 'wss://relay.example';

  @override
  String get relayAdd => '添加';

  @override
  String get relayInvalid => '只接受安全的 wss:// 地址。';

  @override
  String get relayRemove => '移除';

  @override
  String get relayKeepOne => '至少保留一个中继。';

  @override
  String get sectionParanoia => '偏执模式';

  @override
  String get paranoiaMaster => '偏执模式';

  @override
  String get paranoiaMasterBody => '最大程度防范间谍软件和恶意键盘。使用上不太方便。';

  @override
  String get paranoiaKeyboard => 'Whisper 键盘';

  @override
  String get paranoiaKeyboardBody => '使用 Whisper 自带的键盘输入：手机的输入法永远看不到你写的内容。';

  @override
  String get paranoiaShuffle => '打乱按键';

  @override
  String get paranoiaShuffleBody => '每次打开键盘时字母位置都会改变，即使触摸被记录也无法泄露内容。';

  @override
  String get paranoiaMask => '隐藏我输入的内容';

  @override
  String get paranoiaMaskBody => '显示 •••• 而不是你正在输入的文字。';

  @override
  String get paranoiaBlur => '模糊消息';

  @override
  String get paranoiaBlurBody => '消息保持模糊，直到你长按它们。';

  @override
  String get paranoiaA11y => '对无障碍服务隐藏';

  @override
  String get paranoiaA11yBody => '间谍软件常通过无障碍服务读取屏幕。这也会阻止屏幕阅读器（TalkBack）。';

  @override
  String get paranoiaSecure => '全局禁止截屏';

  @override
  String get paranoiaSecureBody => '截屏、录屏以及最近任务中的应用预览都将显示为黑屏。';

  @override
  String get paranoiaLimits =>
      '没有任何应用能保护已被完全攻破的手机（已 root，或间谍软件拥有系统权限）。偏执模式能防范常见情况。';

  @override
  String get a11yWarningTitle => '能读取你屏幕的应用';

  @override
  String get a11yWarningBody => '这些应用拥有无障碍权限，可能读取屏幕上显示的内容：';

  @override
  String get a11yWarningAction => '在系统设置中检查';

  @override
  String get sectionDanger => '危险区域';

  @override
  String get chatHoldToRead => '按住阅读';

  @override
  String get keyboardSpace => '空格';

  @override
  String get requestsTitle => '请求';

  @override
  String requestsRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条消息请求',
      one: '1 条消息请求',
    );
    return '$_temp0';
  }

  @override
  String get requestsEmpty => '没有待处理的请求。';

  @override
  String requestBanner(String name) {
    return '$name 想和你聊天。在你接受之前，对方看不到你的任何信息，连头像也看不到。';
  }

  @override
  String get requestAccept => '接受';

  @override
  String get requestRefuse => '拒绝';

  @override
  String get requestBlock => '屏蔽';

  @override
  String requestBlocked(String name) {
    return '已屏蔽 $name。';
  }

  @override
  String get sectionProfile => '个人资料';

  @override
  String get photoFromGallery => '选择照片';

  @override
  String get photoFromCamera => '拍照';

  @override
  String get photoRemove => '移除';

  @override
  String get photoPrivacy => '只有你接受的联系人能看到，端到端加密。照片中的位置和相机信息会被删除。';

  @override
  String get photoError => '无法使用这张图片。请换一张试试。';

  @override
  String get chatMenu => '更多';

  @override
  String blockConfirmTitle(String name) {
    return '屏蔽 $name？';
  }

  @override
  String get blockConfirmBody => '此对话将从这部手机删除，对方发送的任何内容都不会到达你这里。对方不会收到通知。';

  @override
  String get cancel => '取消';

  @override
  String get blockedPeople => '已屏蔽的人';

  @override
  String get blockedEmpty => '没有屏蔽任何人。';

  @override
  String get unblock => '取消屏蔽';

  @override
  String get attach => '发送照片';

  @override
  String get imagePreviewTitle => '发送这张照片？';

  @override
  String get imageAnonymized => '位置、相机信息和日期已被删除。照片已调整大小。';

  @override
  String get imageSend => '发送';

  @override
  String get photoPreview => '📷 照片';

  @override
  String get imagePendingRequest => '接受此请求前照片不会显示';

  @override
  String get imageUnavailable => '照片不可用';

  @override
  String get lockTitle => 'Whisper 已锁定';

  @override
  String get lockEnterPin => '输入你的 PIN';

  @override
  String get lockWrongPin => 'PIN 错误';

  @override
  String lockRetryIn(int seconds) {
    return '尝试次数过多。请在 $seconds 秒后重试。';
  }

  @override
  String get lockBiometric => '使用指纹或面容解锁';

  @override
  String get lockBiometricPrompt => '解锁 Whisper';

  @override
  String get lockNow => '立即锁定';

  @override
  String get lockChecking => '正在验证…';

  @override
  String get sectionAppLock => '应用锁';

  @override
  String get appLockSetup => '使用 PIN 保护';

  @override
  String get appLockSetupBody => '你的账户密钥由 PIN 加密。没有 PIN，即使拿到手机也打不开任何内容。';

  @override
  String get appLockBiometrics => '指纹或面容';

  @override
  String get appLockBiometricsBody => '使用手机的安全生物识别。添加新指纹会使其关闭：届时需要输入 PIN。';

  @override
  String get appLockChangePin => '更改 PIN';

  @override
  String get appLockAutoLock => '自动锁定';

  @override
  String get autoLockImmediately => '立即';

  @override
  String get autoLockMinute => '1 分钟后';

  @override
  String get autoLockFiveMinutes => '5 分钟后';

  @override
  String get appLockDuress => '胁迫 PIN';

  @override
  String get appLockDuressBody => '第二个 PIN。在锁屏界面输入它，会悄悄清除一切并打开一个空的应用。';

  @override
  String get appLockDuressSet => '设置胁迫 PIN';

  @override
  String get appLockDuressRemove => '移除胁迫 PIN';

  @override
  String get appLockTurnOff => '关闭应用锁';

  @override
  String get pinNewTitle => '设置 PIN';

  @override
  String get pinConfirmTitle => '确认你的 PIN';

  @override
  String get pinCurrentTitle => '当前 PIN';

  @override
  String get pinDuressTitle => '设置胁迫 PIN';

  @override
  String get pinRules => '6 到 12 位数字。避免使用 123456 或重复数字。';

  @override
  String get pinWeak => '太容易被猜到。请换一个。';

  @override
  String get pinMismatch => '两次输入的 PIN 不一致。请重试。';

  @override
  String get pinSameAsReal => '必须与你的 PIN 不同。';

  @override
  String get pinEncrypting => '正在加密你的密钥…';

  @override
  String get signOut => '退出登录';

  @override
  String get signOutTitle => '在这部手机上退出登录？';

  @override
  String get signOutBody => '你的消息、联系人和密钥将从这部手机清除。之后要回来，你需要恢复短语。';

  @override
  String get biometricCancel => '使用 PIN';

  @override
  String get relayTorStarting => '正在启动 Tor…';

  @override
  String get relayTorFailed => '无法连接 Tor · 正在重试';

  @override
  String get relaysIntroTor => '你的连接经过 Tor：中继看不到你的 IP 地址，也无法读取你的消息或看到发送者。';

  @override
  String get torToggle => '通过 Tor 连接（推荐）';

  @override
  String get torToggleBody => '向中继隐藏你的 IP 地址，并有助于突破网络审查。连接会多花几秒钟。';

  @override
  String get torOffWarning => '不使用 Tor 时，中继和你的网络服务商能看到你在使用 Whisper，以及你的 IP 地址。';

  @override
  String get scanQr => '扫描二维码';

  @override
  String get scanHint => '将摄像头对准 Whisper 二维码';

  @override
  String get scanInvalid => '这个二维码不是 Whisper ID。';

  @override
  String get myIdQrHint => '让朋友扫描此二维码给你发消息。';

  @override
  String get safetyNumber => '验证安全码';

  @override
  String safetyNumberBody(String name) {
    return '请与 $name 当面或通过通话核对这些数字。如果两部手机上的数字一致，就说明没有人在拦截你们的对话。';
  }

  @override
  String get safetyMarkVerified => '标记为已验证';

  @override
  String get verified => '已验证';

  @override
  String get rename => '重命名';

  @override
  String get renameHint => '备注名（仅在这部手机上）';

  @override
  String get save => '保存';

  @override
  String get vaultErrorTitle => '安全存储不可用';

  @override
  String get vaultErrorBody =>
      '手机的安全存储没有响应。没有删除任何内容。请关闭 Whisper 后重新打开；如果问题仍然存在，请重启手机。';

  @override
  String get newGroup => '新建群组';

  @override
  String get groupName => '群组名称';

  @override
  String groupPickMembers(int max) {
    return '成员（最多 $max 人）';
  }

  @override
  String get groupNoContacts => '请先添加联系人：只能邀请你已接受的人。';

  @override
  String get groupCreate => '创建';

  @override
  String groupMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 名成员',
      one: '1 名成员',
    );
    return '$_temp0';
  }

  @override
  String get groupEmpty => '消息经过端到端加密，分别发送给每位成员。没有任何服务器知道这个群组的存在。';

  @override
  String get groupInfo => '群组信息';

  @override
  String get groupAdmin => '管理员';

  @override
  String get groupYou => '你';

  @override
  String get groupRename => '重命名群组';

  @override
  String get groupAddMembers => '添加成员';

  @override
  String get groupRemoveMember => '移出群组';

  @override
  String get groupLeave => '退出群组';

  @override
  String groupLeaveConfirm(String name) {
    return '退出“$name”？其消息将从这部手机删除。';
  }

  @override
  String get groupRemoved => '你已不再是该群组的成员。';

  @override
  String groupInvite(String name) {
    return '$name 邀请你加入此群组。拒绝不会通知任何人。';
  }

  @override
  String get groupInviteRow => '群组邀请';

  @override
  String get groupNoAdminLeave => '作为管理员，你不能退出。请改为移除成员。';

  @override
  String groupNamePrefix(String name, String text) {
    return '$name：$text';
  }

  @override
  String get newChannel => '新建频道';

  @override
  String get joinChannel => '加入频道';

  @override
  String get channelName => '频道名称';

  @override
  String get channelAbout => '简介（可选）';

  @override
  String get channelPublic => '公开';

  @override
  String get channelPublicBody => '任何拥有邀请链接或二维码的人都可以关注并分享它。';

  @override
  String get channelPrivate => '私密';

  @override
  String get channelPrivateBody => '由你亲自邀请联系人。关注者没有分享按钮。';

  @override
  String get channelCreate => '创建频道';

  @override
  String get channelEmptyAdmin => '只有你能在这里发布。关注者可以匿名回应。';

  @override
  String get channelEmptyViewer => '还没有帖子。';

  @override
  String get channelBadge => '频道';

  @override
  String get channelFollowers => '仅管理员可发布 · 回应是匿名的';

  @override
  String get channelInfo => '频道信息';

  @override
  String get channelInvite => '邀请';

  @override
  String get channelInviteBody => '扫描或分享此二维码即可关注频道。它包含阅读频道所需的密钥：只在你希望的地方分享。';

  @override
  String get channelInviteCopied => '邀请已复制';

  @override
  String get channelCopyInvite => '复制邀请';

  @override
  String get channelInviteContacts => '邀请联系人';

  @override
  String get channelInvitesSent => '邀请已发送';

  @override
  String get channelLeave => '退出频道';

  @override
  String channelLeaveConfirm(String name) {
    return '退出“$name”？其帖子将从这部手机删除。管理员不会知道。';
  }

  @override
  String channelInviteFrom(String name) {
    return '$name 邀请你关注此频道。';
  }

  @override
  String get channelInviteRow => '频道邀请';

  @override
  String get channelJoinHint => '粘贴邀请（whisper-channel:…）';

  @override
  String get channelJoinInvalid => '这不是有效的频道邀请。';

  @override
  String get channelJoin => '关注';

  @override
  String get channelEdit => '编辑频道';

  @override
  String get channelReact => '回应';

  @override
  String get channelPostHint => '向关注者发布';

  @override
  String get channelAdminNote => '你的频道密钥来自你的身份：用恢复短语恢复账户即可找回它。';

  @override
  String get relayTorDisguising => '正在建立伪装连接…';

  @override
  String get connProtected => '受保护的连接';

  @override
  String get connDisguised => '伪装连接';

  @override
  String get connProtectedBody => '经由 Tor：中继看不到你的 IP 地址。';

  @override
  String get connDisguisedBody => '经由 Tor，并伪装成普通流量：你所在的网络无法识别你在使用 Tor。';

  @override
  String get torDisguise => '伪装我的连接';

  @override
  String get torDisguiseBody =>
      '适用于使用 Tor 本身就有风险的地方。你的流量看起来像随机数据或视频通话。连接速度较慢。当 Tor 被封锁时，Whisper 会自动切换。';

  @override
  String get bgConnectionTitle => '私密连接已开启';

  @override
  String get bgConnectionText => 'Whisper 可以接收你的消息。';

  @override
  String notifyNew(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条新消息',
      one: '新消息',
    );
    return '$_temp0';
  }

  @override
  String get bgToggle => '后台接收';

  @override
  String get bgToggleBody =>
      '在 Whisper 关闭时保持私密连接，并显示一条常驻通知。提醒从不显示发送者或内容。耗电更多。不涉及任何 Google 服务。';

  @override
  String get sectionBackup => '备份';

  @override
  String get backupExport => '导出历史记录';

  @override
  String get backupExportBody => '保存一个加密文件。只有你的恢复短语才能打开它，在任何手机上都可以。';

  @override
  String get backupImport => '导入历史记录';

  @override
  String get backupImportBody => '添加用此账户制作的备份中的对话。不会覆盖这里的任何内容。';

  @override
  String get backupWorking => '正在准备加密备份…';

  @override
  String get backupSaved => '加密备份已保存';

  @override
  String backupImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已恢复 $count 项',
      one: '已恢复 1 项',
      zero: '此备份中没有新内容',
    );
    return '$_temp0';
  }

  @override
  String get backupWrongKey => '此备份属于其他账户，或已损坏。';

  @override
  String get backupBadFile => '这不是 Whisper 备份。';

  @override
  String get backupNewer => '此备份由更新版本的 Whisper 制作。';

  @override
  String get backupFailed => '无法读取或写入文件。';

  @override
  String get searchHint => '搜索';

  @override
  String get searchNoResults => '没有结果';

  @override
  String get filterAll => '全部';

  @override
  String get filterChats => '聊天';

  @override
  String get filterGroups => '群组';

  @override
  String get filterChannels => '频道';

  @override
  String get filterEmpty => '这里还什么都没有';

  @override
  String get newChatSubtitle => '通过 ID 给某人发消息';

  @override
  String get newGroupSubtitle => '私密，端到端加密';

  @override
  String get newChannelSubtitle => '向很多人广播';

  @override
  String get joinChannelSubtitle => '扫描或粘贴邀请';

  @override
  String get startSomething => '开始';

  @override
  String get appearanceTitle => '外观';

  @override
  String get themeTitle => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '浅色';

  @override
  String get nicknameTitle => '昵称';

  @override
  String get nicknameHint => '你的昵称';

  @override
  String nicknameBody(String username) {
    return '只有你接受的联系人能看到，端到端加密。留空则显示为 $username。';
  }
}
