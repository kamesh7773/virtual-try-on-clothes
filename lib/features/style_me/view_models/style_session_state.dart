import 'package:flutter/foundation.dart';

import '../../web_view/models/shop_link.dart';
import '../../web_view/models/try_on_category.dart';
import '../models/look_preview.dart';
import '../models/style_photo.dart';

/// Who the looks are for and which shelf they are on — the two fields that
/// change what the service is asked to make.
typedef LookRequest = ({ShopVariant variant, ShopDept dept});

/// One shopper's pass through Style Me, from the snapshot to the looks.
@immutable
class StyleSessionState {
  final StylePhoto? photo;

  /// The server's id for [photo], once uploaded. Null before the upload
  /// finishes, and again once the id has expired.
  final UploadedPhoto? upload;

  /// Who the looks are styled for, and whose links they open.
  final ShopVariant variant;

  /// The MEN'S / WOMEN'S pick over the camera. Kept apart from [variant]
  /// because a youth row restyles the looks without changing who is
  /// shopping, and the apparel list keys off this one.
  final ShopVariant adult;

  final ShopDept dept;

  /// Whether a look opens its shelf on Dick's when tapped. False under a
  /// heading Dick's has no shelf for — accessories, the fan shop — where
  /// the looks are shown and lead nowhere.
  final bool shops;

  /// The heading over the looks: the tile that led to them.
  final String heading;

  /// What [previews] were made for. Null until the previews screen first
  /// asks for them; the looks are only ever made for a screen showing them.
  final LookRequest? previewsFor;

  final Map<TryOnCategory, LookPreview> previews;

  const StyleSessionState({
    this.photo,
    this.upload,
    this.variant = ShopVariant.men,
    this.adult = ShopVariant.men,
    this.dept = ShopDept.apparel,
    this.heading = "MEN'S APPAREL",
    this.shops = true,
    this.previewsFor,
    this.previews = const {},
  });

  /// What the previews screen would ask for now.
  LookRequest get request => (variant: variant, dept: dept);

  int get readyCount => previews.values.where((p) => p.isDone).length;

  /// A look nobody asked for yet reads as failed, as on the site: there is
  /// nothing coming to wait for.
  LookPreview previewFor(TryOnCategory category) =>
      previews[category] ?? const LookPreview.error();

  StyleSessionState copyWith({
    StylePhoto? photo,
    UploadedPhoto? upload,
    bool clearUpload = false,
    ShopVariant? variant,
    ShopVariant? adult,
    ShopDept? dept,
    String? heading,
    bool? shops,
    LookRequest? previewsFor,
    Map<TryOnCategory, LookPreview>? previews,
  }) => StyleSessionState(
    photo: photo ?? this.photo,
    upload: clearUpload ? null : upload ?? this.upload,
    variant: variant ?? this.variant,
    adult: adult ?? this.adult,
    dept: dept ?? this.dept,
    heading: heading ?? this.heading,
    shops: shops ?? this.shops,
    previewsFor: previewsFor ?? this.previewsFor,
    previews: previews ?? this.previews,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyleSessionState &&
          photo == other.photo &&
          upload == other.upload &&
          variant == other.variant &&
          adult == other.adult &&
          dept == other.dept &&
          heading == other.heading &&
          shops == other.shops &&
          previewsFor == other.previewsFor &&
          mapEquals(previews, other.previews);

  @override
  int get hashCode => Object.hash(
    photo,
    upload,
    variant,
    adult,
    dept,
    heading,
    shops,
    previewsFor,
    Object.hashAllUnordered(
      previews.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
