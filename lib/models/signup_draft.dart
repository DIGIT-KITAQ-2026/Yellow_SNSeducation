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

  /// Child only: the 4-digit code the user typed in to join a group.
  /// The parent's code doesn't exist until create_parent_account has run.
  final String? groupCode;
}
