import 'package:flutter/foundation.dart';

enum LookPreviewStatus { loading, done, error }

/// One of the four looks, as far as the styling service has got with it.
@immutable
class LookPreview {
  final LookPreviewStatus status;

  /// The styled picture's URL. Only set once [status] is
  /// [LookPreviewStatus.done].
  final String? image;

  /// Where the service says this look is sold, for the GET THIS STYLE
  /// button. Null until the look is done, or when the service sent none.
  final Uri? shopUrl;

  const LookPreview._(this.status, {this.image, this.shopUrl});

  const LookPreview.loading() : this._(LookPreviewStatus.loading);
  const LookPreview.error() : this._(LookPreviewStatus.error);
  const LookPreview.done(String image, {Uri? shopUrl})
    : this._(LookPreviewStatus.done, image: image, shopUrl: shopUrl);

  bool get isLoading => status == LookPreviewStatus.loading;
  bool get isDone => status == LookPreviewStatus.done && image != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookPreview &&
          status == other.status &&
          image == other.image &&
          shopUrl == other.shopUrl;

  @override
  int get hashCode => Object.hash(status, image, shopUrl);
}
