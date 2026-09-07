import 'package:flutter/foundation.dart';

import '../models/child_profile.dart';
import '../models/quest_item.dart';

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

  /// Looks up a cached child by `profiles.id`, e.g. to resolve the real
  /// [ChildProfile] instance a server-fetched achievement request refers to.
  ChildProfile? findById(String id) {
    for (final child in _children) {
      if (child.id == id) return child;
    }
    return null;
  }

  ChildProfile addChild(String name, {required String groupCode, String? id}) {
    final profile = ChildProfile(name: name, groupCode: groupCode, id: id);
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

  /// Replaces every cached child of [groupCode] with [children] (each with its
  /// `profiles.id` and current quests), e.g. after fetching the group roster
  /// from Supabase. Keeps the current selection if a child with the same name
  /// is still present, otherwise selects the first of the new list (if any).
  void replaceGroupChildren(
    String groupCode,
    List<({String id, String name, int points, List<QuestItem> quests})> children,
  ) {
    final previousSelectedName = _selected?.groupCode == groupCode ? _selected?.name : null;
    _children.removeWhere((child) => child.groupCode == groupCode);

    ChildProfile? restoredSelection;
    for (final child in children) {
      final profile = ChildProfile(name: child.name, groupCode: groupCode, id: child.id)
        ..points = child.points
        ..questItems.addAll(child.quests);
      _children.add(profile);
      if (child.name == previousSelectedName) restoredSelection = profile;
    }

    if (_selected?.groupCode == groupCode) {
      final remaining = _children.where((child) => child.groupCode == groupCode);
      _selected = restoredSelection ?? (remaining.isEmpty ? null : remaining.first);
    }
    notifyListeners();
  }

  /// Drops every cached child and the current selection. Used on sign-out.
  void clear() {
    _children.clear();
    _selected = null;
    notifyListeners();
  }
}
