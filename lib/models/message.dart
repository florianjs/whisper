import '../logic/image_transfer.dart';

/// [receiving]: an incoming image whose chunks are still arriving.
enum MessageStatus { sending, sent, failed, received, receiving }

/// Whether I agreed to talk with a peer. Nothing about me (profile card,
/// later read receipts…) goes to a peer that isn't [accepted].
enum ContactState { accepted, pending, blocked }

/// State for a conversation that predates contact tracking: if I ever wrote,
/// I accepted it; otherwise it's still a request.
ContactState deriveContactState(Iterable<Message> messages) =>
    messages.any((m) => m.fromMe)
    ? ContactState.accepted
    : ContactState.pending;

/// A decrypted 1:1 message as stored in the encrypted DB. [id] is the NIP-17
/// rumor id, identical on both sides and across transports.
class Message {
  const Message({
    required this.id,
    required this.peer,
    required this.fromMe,
    required this.text,
    required this.createdAt,
    required this.status,
    this.image,
    this.groupId,
  });

  final String id;

  /// Hex pubkey of the other participant.
  final String peer;
  final bool fromMe;
  final String text;

  /// Unix seconds, from the rumor (the sender's clock).
  final int createdAt;
  final MessageStatus status;

  /// Set for image messages (then [text] is empty). The bytes live in the
  /// encrypted DB, keyed by [ImageHeader.fileId].
  final ImageHeader? image;

  /// Set for group messages; then [peer] is the sender (or me).
  final String? groupId;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  Message copyWith({MessageStatus? status}) => Message(
    id: id,
    peer: peer,
    fromMe: fromMe,
    text: text,
    createdAt: createdAt,
    status: status ?? this.status,
    image: image,
    groupId: groupId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'peer': peer,
    'fromMe': fromMe,
    'text': text,
    'createdAt': createdAt,
    'status': status.name,
    if (image != null) 'image': image!.toJson(),
    if (groupId != null) 'groupId': groupId,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    peer: json['peer'] as String,
    fromMe: json['fromMe'] as bool,
    text: json['text'] as String,
    createdAt: json['createdAt'] as int,
    status: MessageStatus.values.byName(json['status'] as String),
    image: ImageHeader.fromJson(json['image']),
    groupId: json['groupId'] as String?,
  );
}

class Conversation {
  const Conversation({required this.peer, required this.last});

  final String peer;
  final Message last;
}
