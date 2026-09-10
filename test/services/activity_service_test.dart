import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yellow_sns_education/services/activity_service.dart';

void main() {
  group('ActivitySuggestException.fromFunctionException', () {
    test('gemini_quota_exceeded を quotaExceeded にマップする', () {
      final e = ActivitySuggestException.fromFunctionException(
        const FunctionException(status: 429, details: {'error': 'gemini_quota_exceeded'}),
      );
      expect(e.failure, ActivitySuggestFailure.quotaExceeded);
    });

    test('rate_limited を rateLimited にマップする', () {
      final e = ActivitySuggestException.fromFunctionException(
        const FunctionException(status: 429, details: {'error': 'rate_limited'}),
      );
      expect(e.failure, ActivitySuggestFailure.rateLimited);
    });

    test('gemini_not_configured を notConfigured にマップする', () {
      final e = ActivitySuggestException.fromFunctionException(
        const FunctionException(status: 200, details: {'error': 'gemini_not_configured'}),
      );
      expect(e.failure, ActivitySuggestFailure.notConfigured);
    });

    test('error キーの無い Map は failed にマップする', () {
      final e = ActivitySuggestException.fromFunctionException(
        const FunctionException(status: 502, details: {'detail': 'something'}),
      );
      expect(e.failure, ActivitySuggestFailure.failed);
    });

    test('未知の error 値は failed にマップする(クォータ超過と誤認しない)', () {
      final e = ActivitySuggestException.fromFunctionException(
        const FunctionException(status: 429, details: {'error': 'something_else'}),
      );
      expect(e.failure, ActivitySuggestFailure.failed);
    });

    test('details が Map でない(HTMLエラーページ等)場合は failed にマップする', () {
      final e = ActivitySuggestException.fromFunctionException(
        const FunctionException(status: 401, details: '<html>Unauthorized</html>'),
      );
      expect(e.failure, ActivitySuggestFailure.failed);
    });

    test('details が null(ゲートウェイの空ボディ等)の場合は failed にマップする', () {
      final e = ActivitySuggestException.fromFunctionException(
        const FunctionException(status: 502),
      );
      expect(e.failure, ActivitySuggestFailure.failed);
    });
  });

  group('ActivitySuggestException.fromErrorCode', () {
    test('200応答の gemini_not_configured を notConfigured にマップする', () {
      final e = ActivitySuggestException.fromErrorCode('gemini_not_configured');
      expect(e.failure, ActivitySuggestFailure.notConfigured);
    });
  });
}
