import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';

class ChildRegistry extends ChangeNotifier {
  ChildRegistry._();

  static final ChildRegistry instance = ChildRegistry._();

  final List<ChildProfile> _children = [];
  ChildProfile? _selected;

  List<ChildProfile> get children => List.unmodifiable(_children);
  ChildProfile? get selected => _selected;

  List<ChildProfile> childrenInGroup(String? groupCode) => groupCode == null
      ? const []
      : _children.where((child) => child.groupCode == groupCode).toList();

  ChildProfile? selectedInGroup(String? groupCode) =>
      (_selected != null && _selected!.groupCode == groupCode) ? _selected : null;

  ChildProfile addChild(String name, {required String groupCode}) {
    final profile = ChildProfile(name: name, groupCode: groupCode);
    _children.add(profile);
    _selected ??= profile;
    notifyListeners();
    return profile;
  }

  void selectChild(String name) {
    final matches = _children.where((child) => child.name == name);
    if (matches.isEmpty) return;
    _selected = matches.first;
    notifyListeners();
  }
}
