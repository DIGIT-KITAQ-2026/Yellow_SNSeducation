import 'package:flutter_test/flutter_test.dart';

import 'package:yellow_sns_education/services/daily_notification_service.dart';

void main() {
  group('dailyScreenTimeNotificationContent', () {
    test('子どもには固定の文面を返す', () {
      final content = dailyScreenTimeNotificationContent(isChild: true, childNames: const []);
      expect(content?.title, '先日のスクリーンタイム');
      expect(content?.body, '先日のスクリーンタイムを確認しましょう。');
    });

    test('子どもの場合、同グループの子ども一覧に関わらず文面は変わらない', () {
      final content =
          dailyScreenTimeNotificationContent(isChild: true, childNames: const ['太郎', '花子']);
      expect(content?.title, '先日のスクリーンタイム');
      expect(content?.body, '先日のスクリーンタイムを確認しましょう。');
    });

    test('保護者・子ども1人の場合、その子の名前を文面に入れる', () {
      final content =
          dailyScreenTimeNotificationContent(isChild: false, childNames: const ['太郎']);
      expect(content?.title, '太郎のスクリーンタイム');
      expect(content?.body, '太郎の先日のスクリーンタイムを確認してみましょう。');
    });

    test('保護者・子ども2人以上の場合、名前を「、」で連結して1件にまとめる', () {
      final content =
          dailyScreenTimeNotificationContent(isChild: false, childNames: const ['太郎', '花子']);
      expect(content?.title, '太郎、花子のスクリーンタイム');
      expect(content?.body, '太郎、花子の先日のスクリーンタイムを確認してみましょう。');
    });

    test('保護者・子どもが1人もいない場合は知らせる相手がいないので null を返す', () {
      final content = dailyScreenTimeNotificationContent(isChild: false, childNames: const []);
      expect(content, isNull);
    });
  });
}
