import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import '../models/quest_item.dart';
import '../models/user_role.dart';

export '../models/user_role.dart';

class AppSession extends ChangeNotifier {
  AppSession._();

  static final AppSession instance = AppSession._();

  UserRole role = UserRole.parent;
  ChildProfile? childProfile;
  String? groupCode;
  /// `groups.id`(SupabaseのUUID)。`tasks.group_id` 等のinsertに必要。
  String? groupId;
  String? groupName;
  String? parentName;
  Uint8List? parentAvatar;
  String? currentEmail;

  bool get isChild => role == UserRole.child;

  void loginAsParent() {
    role = UserRole.parent;
    childProfile = null;
    groupCode = null;
    groupId = null;
    groupName = null;
    parentName = null;
    parentAvatar = null;
    currentEmail = null;
    notifyListeners();
  }

  void loginAsChild(ChildProfile profile) {
    role = UserRole.child;
    childProfile = profile;
    notifyListeners();
  }

  void setGroupCode(String code) {
    groupCode = code;
    notifyListeners();
  }

  void setGroupId(String id) {
    groupId = id;
    notifyListeners();
  }

  void setParentName(String name) {
    parentName = name;
    notifyListeners();
  }

  void setGroupName(String name) {
    groupName = name;
    notifyListeners();
  }

  void setCurrentEmail(String email) {
    currentEmail = email;
  }

  void setParentAvatar(Uint8List bytes) {
    parentAvatar = bytes;
    notifyListeners();
  }

  void setChildAvatar(Uint8List bytes) {
    childProfile?.avatarBytes = bytes;
    notifyListeners();
  }

  void renameChild(String name) {
    childProfile?.name = name;
    notifyListeners();
  }

  /// ログイン中の子どもの `questItems` をサーバから取得した最新の一覧に差し替える。
  /// [ActivityRealtime] が、親が別端末で承認したアクティビティ由来のタスクを
  /// 子ども側に反映するために使う。
  void refreshChildQuests(List<QuestItem> quests) {
    final profile = childProfile;
    if (profile == null) return;
    profile.questItems
      ..clear()
      ..addAll(quests);
    notifyListeners();
  }
}
