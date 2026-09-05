import 'dart:typed_data';

class GiftItem {
  const GiftItem({required this.title, required this.points, this.imageBytes});

  final String title;
  final String points;
  final Uint8List? imageBytes;
}
