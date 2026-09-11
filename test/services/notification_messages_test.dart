import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/models/app_notification.dart';
import 'package:yellow_sns_education/services/notification_messages.dart';

AppNotification _notification(String kind, Map<String, dynamic> payload) => AppNotification(
      id: 'n1',
      kind: kind,
      childId: 'c1',
      payload: payload,
      createdAt: DateTime(2026, 9, 11),
    );

void main() {
  group('notificationContent - 保護者宛', () {
    test('達成申請は子どもの名前を入れる', () {
      final content = notificationContent(_notification('quest_request', {'child_name': '太郎'}));
      expect(content.title, '太郎から達成申請が届きました。');
      expect(content.stampAssetPath, isNull);
    });

    test('交換申請・おでかけ申請も同じ形', () {
      expect(
        notificationContent(_notification('reward_request', {'child_name': '花子'})).title,
        '花子から交換申請が届きました。',
      );
      expect(
        notificationContent(_notification('activity_request', {'child_name': '花子'})).title,
        '花子からおでかけ申請が届きました。',
      );
    });

    test('スクリーンタイム更新', () {
      final content =
          notificationContent(_notification('screen_time_updated', {'child_name': '太郎'}));
      expect(content.title, '太郎のスクリーンタイムが更新されました。');
    });

    test('child_name が無くても落ちず、無難な呼び方にする', () {
      expect(
        notificationContent(_notification('quest_request', {})).title,
        'お子さまから達成申請が届きました。',
      );
    });
  });

  group('notificationContent - 子ども宛', () {
    test('達成承認はポイントとスタンプを添える', () {
      final content = notificationContent(
        _notification('quest_approved', {'item_title': 'お皿あらい', 'points': 10}),
      );
      expect(content.title, '保護者から達成認証スタンプが押されました。10Pが追加されました。');
      expect(content.stampAssetPath, 'assets/images/checked_stamp.png');
    });

    test('達成却下はクエスト名を入れる', () {
      final content =
          notificationContent(_notification('quest_rejected', {'item_title': 'お皿あらい'}));
      expect(content.title, 'お皿あらいの達成申請が却下されました。');
      expect(content.stampAssetPath, isNull);
    });

    test('交換承認・交換却下', () {
      expect(
        notificationContent(
          _notification('reward_approved', {'item_title': 'ゲーム30分', 'points': 50}),
        ).title,
        '保護者から交換認証スタンプが押されました。50Pが引かれました。',
      );
      expect(
        notificationContent(_notification('reward_rejected', {'item_title': 'ゲーム30分'})).title,
        'ゲーム30分との交換申請が却下されました。',
      );
    });

    test('おでかけ承認・おでかけ却下', () {
      expect(
        notificationContent(
          _notification('activity_approved', {'item_title': '公園', 'points': 20}),
        ).title,
        '「公園」のおでかけが承認され、クエストに追加されました。(20P)',
      );
      expect(
        notificationContent(_notification('activity_rejected', {'item_title': '公園'})).title,
        '「公園」のおでかけ申請は承認されませんでした。',
      );
    });

    test('points が無い場合はポイントの文を省く', () {
      expect(
        notificationContent(_notification('quest_approved', {'item_title': 'お皿あらい'})).title,
        '保護者から達成認証スタンプが押されました。',
      );
    });
  });

  test('知らない kind が来てもアプリを落とさず無難な文面にする', () {
    expect(notificationContent(_notification('something_new', {})).title, '新しいお知らせがあります。');
  });

  group('notificationOsTitle', () {
    test('申請はどれも「申請が届きました」でまとめる', () {
      expect(
        notificationOsTitle(_notification('activity_request', {'child_name': '太郎'})),
        '太郎から申請が届きました',
      );
    });

    test('スクリーンタイムは子どもの名前を見出しにする', () {
      expect(
        notificationOsTitle(_notification('screen_time_updated', {'child_name': '太郎'})),
        '太郎のスクリーンタイム',
      );
    });

    test('子ども宛の通知は保護者からのお知らせとして出す', () {
      expect(
        notificationOsTitle(_notification('quest_approved', {'points': 10})),
        'おうちの人からのお知らせ',
      );
    });
  });
}
