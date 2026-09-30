import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/theme/app_colors.dart';

/// Answers a page's `<input type="file">` on Android.
///
/// WKWebView puts up its own "Photo Library / Take Photo / Choose File" menu;
/// Android WebView shows nothing at all unless the app picks the files
/// itself, so a tap on an upload button there does nothing. This is that
/// menu, and the pickers behind it.
///
/// Returns the picked files as URIs, or an empty list when the user backs
/// out. It never throws: the page's input waits for this answer, and one
/// that never comes leaves the input unable to open again.
Future<List<String>> pickFilesForPage(
  BuildContext context,
  FileSelectorParams params,
) async {
  try {
    // A save dialog is not something a page in this app asks for.
    if (params.mode == FileSelectorMode.save) return const [];

    final multiple = params.mode == FileSelectorMode.openMultiple;
    final accept = _acceptTypes(params.acceptTypes);
    final takesImages =
        accept.isEmpty || accept.any((t) => t == '*/*' || _isImageType(t));
    final onlyImages = accept.isNotEmpty && accept.every(_isImageType);

    // Every pick below is awaited, not returned: a future returned from
    // inside `try` fails past the `catch`, straight into the WebView.

    // A page asking for a PDF has no use for the camera or the gallery.
    if (!takesImages) {
      return await _pickFiles(onlyImages: false, multiple: multiple);
    }

    // `capture` on the input asks for the camera straight away, as Chrome
    // does it.
    if (params.isCaptureEnabled) return await _takePhoto();

    if (!context.mounted) return const [];
    final source = await showModalBottomSheet<_UploadSource>(
      context: context,
      backgroundColor: AppColors.stageSurface,
      shape: const RoundedRectangleBorder(),
      builder: (_) => const _UploadSourceSheet(),
    );

    switch (source) {
      case _UploadSource.library:
        return await _pickFromLibrary(multiple: multiple);
      case _UploadSource.camera:
        return await _takePhoto();
      case _UploadSource.files:
        return await _pickFiles(onlyImages: onlyImages, multiple: multiple);
      case null:
        return const [];
    }
  } catch (error, stack) {
    debugPrint('[web] file chooser failed: $error\n$stack');
    return const [];
  }
}

/// `accept` arrives as the page wrote it — sometimes one comma-separated
/// string, sometimes file extensions rather than MIME types.
List<String> _acceptTypes(List<String> raw) => raw
    .expand((type) => type.split(','))
    .map((type) => type.trim().toLowerCase())
    .where((type) => type.isNotEmpty)
    .toList();

const _imageExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'heic',
  'heif',
  'bmp',
];

bool _isImageType(String type) =>
    type.startsWith('image/') ||
    (type.startsWith('.') && _imageExtensions.contains(type.substring(1)));

Future<List<String>> _pickFromLibrary({required bool multiple}) async {
  final picker = ImagePicker();
  final images = multiple
      ? await picker.pickMultiImage()
      : [?await picker.pickImage(source: ImageSource.gallery)];
  return [for (final image in images) Uri.file(image.path).toString()];
}

Future<List<String>> _takePhoto() async {
  final photo = await ImagePicker().pickImage(source: ImageSource.camera);
  return [if (photo != null) Uri.file(photo.path).toString()];
}

/// The system Files screen, opened on Recent. Images are narrowed by
/// extension rather than with [FileType.image]: that one goes through
/// `GET_CONTENT`, which Android hands to a gallery app, not to Files.
Future<List<String>> _pickFiles({
  required bool onlyImages,
  required bool multiple,
}) async {
  final type = onlyImages ? FileType.custom : FileType.any;
  final extensions = onlyImages ? _imageExtensions : null;
  final files = multiple
      ? await FilePicker.pickFiles(type: type, allowedExtensions: extensions)
      : [?await FilePicker.pickFile(type: type, allowedExtensions: extensions)];
  return [for (final file in files) file.uri.toString()];
}

enum _UploadSource { library, camera, files }

class _UploadSourceSheet extends StatelessWidget {
  const _UploadSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 10.h),
              child: Text(
                'UPLOAD',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: AppColors.onStageFaint,
                  letterSpacing: 3,
                ),
              ),
            ),
            const _SourceTile(
              source: _UploadSource.library,
              icon: Icons.photo_library_outlined,
              label: 'Photo Library',
            ),
            const _SourceTile(
              source: _UploadSource.camera,
              icon: Icons.photo_camera_outlined,
              label: 'Take Photo',
            ),
            const _SourceTile(
              source: _UploadSource.files,
              icon: Icons.folder_outlined,
              label: 'Choose File',
            ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final _UploadSource source;
  final IconData icon;
  final String label;

  const _SourceTile({
    required this.source,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(source),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: AppColors.onStageSecondary),
            SizedBox(width: 14.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.onStagePrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
