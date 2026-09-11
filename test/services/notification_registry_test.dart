import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/models/app_notification.dart';
import 'package:yellow_sns_education/services/notification_registry.dart';

AppNotification _notification(
  String id, {
  String kind = 'quest_request',
  String? requestId,
  DateTime? createdAt,
  DateTime? readAt,
}) =>
    AppNotification(
      id: id,
      kind: kind,
      childId: 'c1',
      payload: {if (requestId != null) 'request_id': requestId},
      createdAt: createdAt ?? DateTime(2026, 9, 11),
      readAt: readAt,
    );

void main() {
  final registry = NotificationRegistry.instance;

  // シングルトンなのでテスト間で状態が漏れる。毎回まっさらにする。
  setUp(registry.clear);

  test('replaceAll は新しい順に並べ替える', () {
    registry.replaceAll([
      _notification('old', createdAt: DateTime(2026, 9, 1)),
      _notification('new', createdAt: DateTime(2026, 9, 10)),
      _notification('mid', createdAt: DateTime(2026, 9, 5)),
    ]);

    expect([for (final n in registry.notifications) n.id], ['new', 'mid', 'old']);
  });

  test('addFromRealtime は同じ id を二重に積まない', () {
    registry.replaceAll([_notification('a')]);
    registry.addFromRealtime(_notification('a'));
    registry.addFromRealtime(_notification('b'));

    expect(registry.notifications.length, 2);
  });

  test('unreadCount は read_at が入っていない件数', () {
    registry.replaceAll([
      _notification('a'),
      _notification('b'),
      _notification('c', readAt: DateTime(2026, 9, 11)),
    ]);

    expect(registry.unreadCount, 2);
  });

  test('markRead はサーバへの書き込みが失敗しても手元の既読は残す', () async {
    registry.replaceAll([_notification('a')]);
    // Supabase を初期化していないので NotificationService.markRead は必ず失敗する。
    // それでも表示が壊れないことを確かめる(次回ログインで未読に戻るだけ)。
    await registry.markRead(registry.notifications.first);

    expect(registry.notifications.first.isRead, isTrue);
    expect(registry.unreadCount, 0);
  });

  test('markReadByRequestId は同じ申請の通知だけを既読にする', () async {
    registry.replaceAll([
      _notification('a', requestId: 'req-1'),
      _notification('b', requestId: 'req-2'),
    ]);

    await registry.markReadByRequestId('req-1');

    final byId = {for (final n in registry.notifications) n.id: n};
    expect(byId['a']!.isRead, isTrue);
    expect(byId['b']!.isRead, isFalse);
  });

  test('remove はサーバ削除が失敗したら元の位置に戻す', () async {
    registry.replaceAll([
      _notification('new', createdAt: DateTime(2026, 9, 10)),
      _notification('mid', createdAt: DateTime(2026, 9, 5)),
      _notification('old', createdAt: DateTime(2026, 9, 1)),
    ]);

    // Supabase を初期化していないので NotificationService.delete は必ず失敗する。
    // 消えたはずの通知が黙って残るほうが分かりにくいので、例外は投げ直す。
    await expectLater(registry.remove(registry.notifications[1]), throwsA(anything));

    expect([for (final n in registry.notifications) n.id], ['new', 'mid', 'old']);
  });

  test('removeAll はサーバ削除が失敗したら一覧を元に戻す', () async {
    registry.replaceAll([
      _notification('new', createdAt: DateTime(2026, 9, 10)),
      _notification('old', createdAt: DateTime(2026, 9, 1)),
    ]);

    await expectLater(registry.removeAll(), throwsA(anything));

    expect([for (final n in registry.notifications) n.id], ['new', 'old']);
  });

  test('clear で空になる', () {
    registry.replaceAll([_notification('a')]);
    registry.clear();

    expect(registry.notifications, isEmpty);
    expect(registry.unreadCount, 0);
  });
}
