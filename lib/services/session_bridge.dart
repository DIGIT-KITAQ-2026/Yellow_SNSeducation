import '../models/child_profile.dart';
import '../models/signup_draft.dart';
import '../models/user_profile.dart';
import 'app_session.dart';
import 'child_registry.dart';

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
    required List<({String id, String name, int points})> children,
    String? email,
  }) {
    ChildRegistry.instance.replaceGroupChildren(
      profile.groupCode,
      [for (final child in children) (name: child.name, points: child.points)],
    );

    if (profile.role == AccountRole.parent) {
      AppSession.instance.loginAsParent();
      AppSession.instance.setParentName(profile.displayName);
    } else {
      final childProfile = ChildProfile(name: profile.displayName, groupCode: profile.groupCode)
        ..points = profile.pointBalance;
      AppSession.instance.loginAsChild(childProfile);
    }

    AppSession.instance.setGroupCode(profile.groupCode);
    AppSession.instance.setGroupName(profile.groupName);
    if (email != null) AppSession.instance.setCurrentEmail(email);
  }

  /// Resets the UI lineage's state. Used on sign-out.
  static void clear() {
    AppSession.instance.loginAsParent();
    ChildRegistry.instance.clear();
  }
}
