import 'package:flutter_test/flutter_test.dart';
import 'package:yellow_sns_education/utils/validators.dart';

void main() {
  group('validateEmail', () {
    test('empty input is "not entered"', () {
      expect(validateEmail(''), '入力されていません');
      expect(validateEmail('   '), '入力されていません');
    });

    test('malformed email is rejected', () {
      expect(validateEmail('not-an-email'), 'メールアドレスの形式が正しくありません');
      expect(validateEmail('missing-domain@'), 'メールアドレスの形式が正しくありません');
      expect(validateEmail('@missing-local.com'), 'メールアドレスの形式が正しくありません');
      expect(validateEmail('no-at-sign.com'), 'メールアドレスの形式が正しくありません');
    });

    test('well-formed email passes', () {
      expect(validateEmail('user@example.com'), null);
      expect(validateEmail('  user@example.com  '), null);
      expect(validateEmail('first.last+tag@sub.example.co.jp'), null);
    });
  });
}
