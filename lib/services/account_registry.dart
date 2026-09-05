import 'dart:typed_data';

import '../models/account_record.dart';
import '../models/child_profile.dart';
import '../models/user_role.dart';

class AccountRegistry {
  AccountRegistry._();

  static final AccountRegistry instance = AccountRegistry._();

  final Map<String, AccountRecord> _accounts = {};

  void registerParent({
    required String email,
    required String password,
    String? parentName,
    String? groupName,
    String? groupCode,
  }) {
    _accounts[_normalize(email)] = AccountRecord(
      email: _normalize(email),
      password: password,
      role: UserRole.parent,
      parentName: parentName,
      groupName: groupName,
      groupCode: groupCode,
    );
  }

  void updateParentAvatar(String email, Uint8List bytes) {
    _accounts[_normalize(email)]?.parentAvatar = bytes;
  }

  void updateParentName(String email, String name) {
    _accounts[_normalize(email)]?.parentName = name;
  }

  void registerChild({
    required String email,
    required String password,
    required ChildProfile childProfile,
    String? groupName,
    String? groupCode,
  }) {
    _accounts[_normalize(email)] = AccountRecord(
      email: _normalize(email),
      password: password,
      role: UserRole.child,
      childProfile: childProfile,
      groupName: groupName,
      groupCode: groupCode,
    );
  }

  AccountRecord? findByEmail(String email) => _accounts[_normalize(email)];

  bool isRegistered(String email) => _accounts.containsKey(_normalize(email));

  String _normalize(String email) => email.trim().toLowerCase();
}
