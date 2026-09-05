import 'dart:typed_data';

import 'child_profile.dart';
import 'user_role.dart';

class AccountRecord {
  AccountRecord({
    required this.email,
    required this.password,
    required this.role,
    this.parentName,
    this.childProfile,
    this.groupName,
    this.groupCode,
    this.parentAvatar,
  });

  final String email;
  final String password;
  final UserRole role;
  String? parentName;
  final ChildProfile? childProfile;
  final String? groupName;
  final String? groupCode;
  Uint8List? parentAvatar;
}
