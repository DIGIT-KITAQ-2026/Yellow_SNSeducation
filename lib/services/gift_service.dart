import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gift_item.dart';

/// Thin wrapper over the Supabase client for everything gift/reward-related
/// (`rewards` / `reward_redemptions` + the `gift-images` Storage bucket).
/// Holds no state of its own, same shape as [QuestService].
class GiftService {
  static SupabaseClient get _client => Supabase.instance.client;
  static const _bucket = 'gift-images';

  /// Active rewards belonging to [childId], images already downloaded so the
  /// UI can render them with `Image.memory` right away.
  static Future<List<GiftItem>> fetchRewards(String childId) async {
    final rows = await _client
        .from('rewards')
        .select('id, name, cost_points, always_visible, image_path')
        .eq('child_id', childId)
        .eq('is_active', true);

    final list = [for (final row in rows as List) row as Map<String, dynamic>];
    final images = await Future.wait(list.map((row) {
      final path = row['image_path'] as String?;
      return path == null ? Future.value(null) : downloadImage(path);
    }));

    return [
      for (var i = 0; i < list.length; i++)
        GiftItem.fromJson(list[i], imageBytes: images[i]),
    ];
  }

  static String _extensionFor(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    return 'jpg';
  }

  static Future<String> _uploadImage({
    required String groupId,
    required String rewardId,
    required Uint8List bytes,
  }) async {
    final path = '$groupId/$rewardId.${_extensionFor(bytes)}';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  static Future<Uint8List> downloadImage(String path) {
    return _client.storage.from(_bucket).download(path);
  }

  /// Creates a reward for [childId] in [groupId]. `created_by` is the
  /// signed-in (parent) user, required by the `rewards_insert` RLS policy.
  /// Uploads [imageBytes] to Storage after the row exists, so the object key
  /// can be `<groupId>/<rewardId>.<ext>`.
  static Future<GiftItem> createReward({
    required String groupId,
    required String childId,
    required String title,
    required int points,
    bool alwaysVisible = false,
    Uint8List? imageBytes,
  }) async {
    final row = await _client
        .from('rewards')
        .insert({
          'group_id': groupId,
          'child_id': childId,
          'name': title,
          'cost_points': points,
          'always_visible': alwaysVisible,
          'created_by': _client.auth.currentUser!.id,
        })
        .select('id, name, cost_points, always_visible, image_path')
        .single();

    var item = GiftItem.fromJson(row);
    if (imageBytes == null) return item;

    final path = await _uploadImage(groupId: groupId, rewardId: item.id!, bytes: imageBytes);
    await _client.from('rewards').update({'image_path': path}).eq('id', item.id!);
    return item.copyWith(imagePath: path, imageBytes: imageBytes);
  }

  /// Updates [item]'s title/points/alwaysVisible. If [newImageBytes] is
  /// given, it replaces the existing image (same object key, upsert).
  static Future<GiftItem> updateReward(
    GiftItem item, {
    required String groupId,
    Uint8List? newImageBytes,
  }) async {
    final updates = <String, dynamic>{
      'name': item.title,
      'cost_points': item.points,
      'always_visible': item.alwaysVisible,
    };

    String? imagePath = item.imagePath;
    if (newImageBytes != null) {
      imagePath = await _uploadImage(groupId: groupId, rewardId: item.id!, bytes: newImageBytes);
      updates['image_path'] = imagePath;
    }

    final row = await _client
        .from('rewards')
        .update(updates)
        .eq('id', item.id!)
        .select('id, name, cost_points, always_visible, image_path')
        .single();

    return GiftItem.fromJson(row, imageBytes: newImageBytes ?? item.imageBytes);
  }

  /// Toggles `always_visible` only, used by the card's edit-mode pin toggle.
  static Future<void> setAlwaysVisible(String rewardId, bool value) {
    return _client.from('rewards').update({'always_visible': value}).eq('id', rewardId);
  }

  static Future<void> deleteReward(String rewardId, {String? imagePath}) async {
    if (imagePath != null) {
      await _client.storage.from(_bucket).remove([imagePath]);
    }
    await _client.from('rewards').delete().eq('id', rewardId);
  }

  /// Submits an exchange request for [rewardId] on behalf of [childId].
  /// Returns the server-generated `reward_redemptions.id`, needed later by
  /// [approveRequest] / [rejectRequest].
  static Future<String> requestExchange({
    required String rewardId,
  }) async {
    final id = await _client.rpc('request_reward', params: {'reward_id': rewardId}) as String;
    return id;
  }

  /// Pending (未処理) exchange requests across the whole group, for the
  /// parent's notification bell. RLS (`reward_redemptions_select`) already
  /// limits this to the caller's own group.
  ///
  /// Returns raw `(id, childId, item)` tuples rather than a fully-formed
  /// `ExchangeRequest`, because the real `ChildProfile` instance those need
  /// to mutate only exists after `ChildRegistry.replaceGroupChildren` has
  /// run — that lookup happens on the caller's side (see
  /// `ExchangeRequestRegistry.replaceAll`).
  static Future<List<({String id, String childId, GiftItem item})>> fetchPendingRequests(
    String groupId,
  ) async {
    final rows = await _client
        .from('reward_redemptions')
        .select(
          'id, child_id, reward_id, reward_name, cost_points, '
          'rewards!inner(id, name, cost_points, always_visible, image_path, group_id)',
        )
        .eq('status', 'pending')
        .eq('rewards.group_id', groupId);

    return [
      for (final row in rows as List)
        (
          id: row['id'] as String,
          childId: row['child_id'] as String,
          item: GiftItem.fromJson(row['rewards'] as Map<String, dynamic>),
        ),
    ];
  }

  static Future<void> approveRequest(String requestId) {
    return _client.rpc('approve_reward_request', params: {'request_id': requestId});
  }

  static Future<void> rejectRequest(String requestId) {
    return _client.rpc('reject_reward_request', params: {'request_id': requestId});
  }
}
