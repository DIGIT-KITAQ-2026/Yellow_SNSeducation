import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import '../models/user_role.dart';

export '../models/user_role.dart';

class AppSession extends ChangeNotifier {
  AppSession._();

  static final AppSession instance = AppSession._();

  UserRole role = UserRole.parent;
  ChildProfile? childProfile;
  String? groupCode;
  String? groupName;
  String? parentName;
  Uint8List? parentAvatar;
  String? currentEmail;

  bool get isChild => role == UserRole.child;

  void loginAsParent() {
    role = UserRole.parent;
    childProfile = null;
    groupCode = null;
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
}
