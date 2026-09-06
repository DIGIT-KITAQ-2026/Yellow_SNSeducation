import 'dart:math';

import '../models/group.dart';

class GroupRegistry {
  GroupRegistry._();

  static final GroupRegistry instance = GroupRegistry._();

  final Map<String, Group> _groups = {};
  Group? _testGroup;

  Group createGroup(String name) {
    String code;
    do {
      code = (1000 + Random().nextInt(9000)).toString();
    } while (_groups.containsKey(code));
    final group = Group(code: code, name: name);
    _groups[code] = group;
    return group;
  }

  void renameGroup(String code, String name) {
    _groups[code]?.name = name;
  }

  Group? findByCode(String code) => _groups[code];

  Group ensureTestGroup() => _testGroup ??= createGroup('テストグループ');
}
