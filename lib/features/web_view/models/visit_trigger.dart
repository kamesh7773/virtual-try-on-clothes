/// How a page came to be opened.
///
/// The browser can only tell these apart at the moment of the tap, so the
/// value is recorded with the visit rather than worked out later.
enum VisitTrigger {
  /// The app opened it — a destination from the sheet, or a row reopened from
  /// the history.
  direct('Opened from the app'),

  /// The user tapped an ordinary link on the page.
  link('Tapped a link'),

  /// The user tapped something that carried a link without being one — a card
  /// or a button with the URL on itself.
  element('Tapped a card'),

  /// The page tried to show the link inside an embedded frame, and the app
  /// took it out.
  frame('Lifted out of an embedded frame'),

  /// The page was a viewer holding the real link in its address.
  viewer('Unwrapped from a viewer page'),

  /// The site navigated itself — a redirect, a form, a script.
  inPage('Followed inside the site');

  final String label;

  const VisitTrigger(this.label);

  static VisitTrigger fromName(String? name) => values.firstWhere(
    (trigger) => trigger.name == name,
    orElse: () => VisitTrigger.direct,
  );
}
