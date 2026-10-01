import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../web_view/models/shop_link.dart';
import '../../web_view/models/try_on_category.dart';
import '../models/look_preview.dart';
import '../models/style_catalog.dart';
import '../models/style_photo.dart';
import '../repositories/style_me_repository.dart';
import 'style_session_state.dart';

part 'style_session_view_model.g.dart';

/// The Style Me session: the snapshot, who it is styled for, and the four
/// looks made from it.
///
/// The photo is uploaded as soon as it is taken — that is cheap, and it
/// means the id is ready by the time it is needed. The looks are not: each
/// one costs the service a generation, so they are only asked for by the
/// screen that shows them, through [showLooks], and only for the shopper
/// and shelf it is showing. A shopper who takes a photo and leaves costs
/// nothing more than the upload.
///
/// Kept alive across the flow's screens, so the looks go on arriving while
/// the shopper is on another one. The intro screen resets it.
@Riverpod(keepAlive: true)
class StyleSessionViewModel extends _$StyleSessionViewModel {
  @override
  StyleSessionState build() => const StyleSessionState();

  StyleMeRepository get _repo => ref.read(styleMeRepositoryProvider);

  /// Tries per look before it is shown as failed. A retry costs nothing
  /// when the first try did get through: the service caches each look.
  static const int maxAttempts = 3;

  static const List<Duration> retryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
  ];

  /// Bumped whenever the looks are asked for afresh. A request that comes
  /// back under an older number belongs to a photo or a shopper that has
  /// since been replaced, and is dropped.
  int _generation = 0;

  /// The upload in flight, if any, so two callers share one.
  Future<UploadedPhoto?>? _uploading;

  @visibleForTesting
  Future<void> Function(Duration) wait = Future<void>.delayed;

  @visibleForTesting
  DateTime Function() now = DateTime.now;

  void reset() {
    _generation++;
    _uploading = null;
    final upload = state.upload;
    if (upload != null) _repo.deletePhoto(upload.id);
    state = const StyleSessionState();
  }

  /// The MEN'S / WOMEN'S switch over the camera.
  void setAdult(ShopVariant adult) =>
      state = state.copyWith(adult: adult, variant: adult);

  /// Takes the snapshot and uploads it. The looks wait for [showLooks].
  void usePhoto(StylePhoto photo) {
    _generation++;
    final previous = state.upload;
    if (previous != null) _repo.deletePhoto(previous.id);
    state = StyleSessionState(
      photo: photo,
      variant: state.variant,
      adult: state.adult,
      dept: state.dept,
      heading: state.heading,
      shops: state.shops,
    );
    _upload(photo);
  }

  /// A tile on the explore screen. Every one of them shows the shopper's
  /// own apparel looks, and none of them is a shelf on Dick's — those are
  /// the rows behind APPAREL.
  void chooseExplore(ExploreTile tile) => state = state.copyWith(
    heading: tile.label,
    variant: state.adult,
    dept: ShopDept.apparel,
    shops: false,
  );

  /// A row on the apparel screen, which can restyle the looks for a child
  /// or for shoes.
  ///
  /// Who the looks are for is worked out from the shopper each time, never
  /// carried over from the row before: shoes opened after the youth row are
  /// the shopper's shoes, not a child's.
  void chooseApparel(ApparelTile tile) => state = state.copyWith(
    heading: tile.label,
    variant: tile.variantFor(state.adult),
    dept: tile.dept,
    shops: tile.shops,
  );

  /// Called by the previews screen as it opens: makes the looks it is about
  /// to show, for the shopper and shelf chosen on the way to it.
  ///
  /// Looks already made for that same request are kept, and a look that
  /// failed is asked for again — the service answers from its cache for
  /// one it did finish, so a second ask is free.
  Future<void> showLooks() async {
    final photo = state.photo;
    if (photo == null) return;

    final request = state.request;
    final categories = [for (final look in StyleCatalog.looks) look.category];

    final List<TryOnCategory> wanted;
    if (state.previewsFor == request) {
      wanted = [
        for (final category in categories)
          if (state.previewFor(category).status == LookPreviewStatus.error)
            category,
      ];
      if (wanted.isEmpty) return;
    } else {
      _generation++;
      wanted = categories;
    }

    final generation = _generation;
    state = state.copyWith(
      previewsFor: request,
      previews: {
        if (state.previewsFor == request) ...state.previews,
        for (final category in wanted) category: const LookPreview.loading(),
      },
    );

    // All at once: each takes up to a minute, and one after another is
    // longer than a shopper waits.
    await Future.wait([
      for (final category in wanted)
        _runLook(
          photo: photo,
          category: category,
          request: request,
          generation: generation,
        ),
    ]);
  }

  Future<void> _runLook({
    required StylePhoto photo,
    required TryOnCategory category,
    required LookRequest request,
    required int generation,
  }) async {
    var reuploaded = false;

    for (var attempt = 1; ; attempt++) {
      if (!_isCurrent(generation)) return;

      final photoId = await _photoId(photo);
      if (!_isCurrent(generation)) return;
      if (photoId == null) {
        debugPrint('[style-me] ${category.wireName}: no photo id to send');
        _setPreview(category, const LookPreview.error());
        return;
      }

      final result = await _repo.requestLook(
        photoId: photoId,
        category: category,
        variant: request.variant,
        dept: request.dept,
      );
      if (!_isCurrent(generation)) return;

      var retryable = true;
      switch (result) {
        case LookReady(:final image, :final shopUrl):
          debugPrint('[style-me] ✓ ${category.wireName} (attempt $attempt)');
          _setPreview(category, LookPreview.done(image, shopUrl: shopUrl));
          return;
        case LookPhotoExpired():
          // The id died between the upload and this look. Once: an id that
          // expires straight after being issued is not going to do better
          // a third time.
          markPhotoExpired(photoId);
          if (!reuploaded) {
            reuploaded = true;
            continue;
          }
        case LookFailed(retryable: final canRetry, :final reason):
          debugPrint('[style-me] ${category.wireName} failed: $reason');
          retryable = canRetry;
      }

      if (retryable && attempt < maxAttempts) {
        await wait(retryDelays[(attempt - 1).clamp(0, retryDelays.length - 1)]);
        continue;
      }

      _setPreview(category, const LookPreview.error());
      return;
    }
  }

  /// The id of this shopper's photo, for a service outside Style Me that
  /// needs to name it — the browser's product try-on. Uploads again if the
  /// id held has run out. Null when no photo has been taken, or the upload
  /// fails.
  Future<String?> photoId() async {
    final photo = state.photo;
    return photo == null ? null : _photoId(photo);
  }

  /// Called when the service refuses [id] as expired, so the next ask
  /// uploads afresh instead of sending it again. Ignored for an id that has
  /// already been replaced.
  void markPhotoExpired(String id) {
    if (state.upload?.id == id) state = state.copyWith(clearUpload: true);
  }

  /// The id to send for [photo]: the one already held while it is good,
  /// otherwise a fresh upload — shared with anyone else waiting on one.
  Future<String?> _photoId(StylePhoto photo) async {
    final held = state.upload;
    if (held != null && held.isUsableAt(now())) return held.id;
    return (await _upload(photo))?.id;
  }

  Future<UploadedPhoto?> _upload(StylePhoto photo) {
    final inFlight = _uploading;
    if (inFlight != null) return inFlight;

    // Tied to the photo, not to a round of looks: the looks are asked for
    // again and again from the same upload.
    final future = _repo.uploadPhoto(photo).then((upload) {
      _uploading = null;
      if (!ref.mounted) return null;
      if (!identical(state.photo, photo)) {
        // Uploaded for a photo since replaced, or a session since reset:
        // not ours to keep.
        if (upload != null) _repo.deletePhoto(upload.id);
        return null;
      }
      if (upload != null) state = state.copyWith(upload: upload);
      return upload;
    });
    _uploading = future;
    return future;
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _setPreview(TryOnCategory category, LookPreview preview) {
    state = state.copyWith(previews: {...state.previews, category: preview});
  }
}
