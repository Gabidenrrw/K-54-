import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class RecipientPhoto extends StatelessWidget {
  const RecipientPhoto({super.key, required this.path, this.size = 43});
  final String path;
  final double size;
  static bool available(String path) {
    if (path.isEmpty) return false;
    try { return File(path).existsSync(); } on FileSystemException { return false; }
  }
  @override
  Widget build(BuildContext context) => !available(path)
    ? _defaultAvatar(size)
    : SizedBox(width: size, height: size, child: ClipOval(child: Image.file(File(path),
      key: const Key('recipient_photo_image'), width: size, height: size, fit: BoxFit.cover,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      errorBuilder: (_, error, stack) => _defaultAvatar(size))));
}

Widget _defaultAvatar(double size) => SizedBox(
  width: size,
  height: size,
  child: ClipOval(
    child: SvgPicture.asset('assets/icons/recipient_avatar.svg', fit: BoxFit.cover),
  ),
);

class RecipientPhotoStore {
  RecipientPhotoStore({ImagePicker? picker, Future<Directory> Function()? directory})
    : _picker = picker ?? ImagePicker(), _directory = directory ?? getApplicationSupportDirectory;
  final ImagePicker _picker;
  final Future<Directory> Function() _directory;
  Directory? _root;

  Future<String?> pick() async {
    final image = await _picker.pickImage(source: ImageSource.gallery,
      maxWidth: 1080, maxHeight: 1080, imageQuality: 85, requestFullMetadata: false);
    return image == null ? null : importPickedFile(image);
  }

  Future<String?> recover() async {
    if (!Platform.isAndroid) return null;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.files == null || response.files!.isEmpty) return null;
      return importPickedFile(response.files!.first);
    } on MissingPluginException { return null; }
  }

  Future<String> importPickedFile(XFile image) async {
    if (await image.length() > 20 * 1024 * 1024) throw const FormatException('Фото слишком большое.');
    final bytes = await image.readAsBytes();
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 32, allowUpscaling: false);
      try { final frame = await codec.getNextFrame(); frame.image.dispose(); } finally { codec.dispose(); }
    } catch (_) { throw const FormatException('Не удалось прочитать фото. Выберите другое изображение.'); }
    _root ??= Directory('${(await _directory()).path}/recipient_photos');
    await _root!.create(recursive: true);
    final suffix = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    final destination = File('${_root!.path}/${DateTime.now().microsecondsSinceEpoch}_$suffix.jpg');
    await destination.writeAsBytes(bytes, flush: true);
    return destination.path;
  }

  Future<void> discard(String path) async {
    if (_root == null || File(path).parent.absolute.path != _root!.absolute.path) return;
    try { final file = File(path); if (await file.exists()) await file.delete(); } on FileSystemException { /* Best effort. */ }
  }
}
