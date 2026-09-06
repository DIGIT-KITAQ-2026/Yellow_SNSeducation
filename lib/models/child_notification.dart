import 'child_profile.dart';

class ChildNotification {
  ChildNotification({
    required this.childProfile,
    required this.message,
    this.stampAssetPath,
  }) : createdAt = DateTime.now();

  final ChildProfile childProfile;
  final String message;
  final String? stampAssetPath;
  final DateTime createdAt;
  bool read = false;
}
