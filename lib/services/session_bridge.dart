import '../models/child_profile.dart';
import '../models/quest_item.dart';
import '../models/signup_draft.dart';
import '../models/user_profile.dart';
import 'achievement_request_registry.dart';
import 'app_session.dart';
import 'child_registry.dart';
import 'screen_time_registry.dart';

/// Bridges the Supabase-backed [UserProfile] onto the UI lineage's global
/// singletons ([AppSession], [ChildRegistry]), which every screen under
/// MainShell reads directly instead of taking constructor arguments.
///
/// Must run (and finish) before the first frame that builds MainShell, since
/// AccountBar / QuestBody / GiftBody read AppSession synchronously in build().
class SessionBridge {
  SessionBridge._();

  static void hydrate({
    required UserProfile profile,
    required List<({String id, String name, int points, List<QuestItem> quests})> children,
    List<({String id, String childId, QuestItem item})> pendingRequests = const [],
    String? email,
  }) {
    // children はそのまま ChildRegistry.replaceGroupChildren に渡す
    // (id/name/points/quests を保ったまま)。
    ChildRegistry.instance.replaceGroupChildren(profile.groupCode, children);

    if (profile.role == AccountRole.parent) {
      AppSession.instance.loginAsParent();
      AppSession.instance.setParentName(profile.displayName);
    } else {
      final matchingChild = children.where((c) => c.id == profile.id);
      final childProfile = ChildProfile(
        name: profile.displayName,
        groupCode: profile.groupCode,
        id: profile.id,
      )..points = profile.pointBalance;
      if (matchingChild.isNotEmpty) {
        childProfile.questItems.addAll(matchingChild.first.quests);
      }
      AppSession.instance.loginAsChild(childProfile);
    }

    AppSession.instance.setGroupCode(profile.groupCode);
    AppSession.instance.setGroupId(profile.groupId);
    AppSession.instance.setGroupName(profile.groupName);
    if (email != null) AppSession.instance.setCurrentEmail(email);

    // サーバが正: 親の未処理の達成申請一覧を丸ごと差し替える。
    AchievementRequestRegistry.instance.replaceAll(pendingRequests);
  }

  /// Resets the UI lineage's state. Used on sign-out.
  static void clear() {
    AppSession.instance.loginAsParent();
    ChildRegistry.instance.clear();
    ScreenTimeRegistry.instance.clear();
  }
}
