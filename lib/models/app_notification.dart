/// `notifications` テーブルの1行。
///
/// 表示文面はサーバに持たせず、[kind] と [payload] から
/// `lib/services/notification_messages.dart` が組み立てる。文面を直すのに
/// マイグレーションを足さなくて済むようにするため。
class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.childId,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        kind: json['kind'] as String,
        childId: json['child_id'] as String?,
        payload: Map<String, dynamic>.from(
          (json['payload'] as Map?) ?? const <String, dynamic>{},
        ),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        readAt: json['read_at'] == null
            ? null
            : DateTime.tryParse(json['read_at'] as String)?.toLocal(),
      );

  final String id;
  final String kind;
  final String? childId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  DateTime? readAt;

  bool get isRead => readAt != null;

  /// 申請系の通知で、対応する申請行の id。親がこの通知をタップしたときに
  /// 承認/却下ダイアログを開く相手を探す鍵になる。
  String? get requestId => payload['request_id'] as String?;

  String? get itemTitle => payload['item_title'] as String?;

  String? get childName => payload['child_name'] as String?;

  int? get points => (payload['points'] as num?)?.toInt();

  /// 承認通知に同梱される、サーバ側で確定した子どものポイント残高。
  int? get pointBalance => (payload['point_balance'] as num?)?.toInt();
}
