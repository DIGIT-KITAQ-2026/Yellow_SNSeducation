/// Which side of the parent/child flow the current signup belongs to.
enum AccountRole { parent, child }

/// Carries the account-creation details collected across screens ②③④
/// until they're ready to be submitted together at the end of the flow.
class SignupDraft {
  SignupDraft({
    required this.role,
    required this.displayName,
    this.groupName,
    this.groupCode,
  });

  final AccountRole role;
  final String displayName;

  /// Parent only: the group's name, entered on screen ③.
  final String? groupName;

  /// Parent: the randomly generated 4-digit code shown on screen ③.
  /// Child: the 4-digit code the user typed in to join a group.
  final String? groupCode;

  SignupDraft copyWith({String? groupCode}) {
    return SignupDraft(
      role: role,
      displayName: displayName,
      groupName: groupName,
      groupCode: groupCode ?? this.groupCode,
    );
  }
}
