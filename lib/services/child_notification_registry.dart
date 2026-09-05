import 'package:flutter/foundation.dart';

import '../models/child_notification.dart';
import '../models/child_profile.dart';

class ChildNotificationRegistry extends ChangeNotifier {
  ChildNotificationRegistry._();

  static final ChildNotificationRegistry instance = ChildNotificationRegistry._();

  final List<ChildNotification> _notifications = [];

  List<ChildNotification> get notifications => List.unmodifiable(_notifications);

  void add(ChildProfile childProfile, String message, {String? stampAssetPath}) {
    _notifications.add(ChildNotification(
      childProfile: childProfile,
      message: message,
      stampAssetPath: stampAssetPath,
    ));
    notifyListeners();
  }

  void markRead(ChildNotification notification) {
    if (notification.read) return;
    notification.read = true;
    notifyListeners();
  }
}
