// Shared UI constants to keep layout stable across locales and user FontScale.
//
// Prefer putting *layout-affecting* numbers here (widths, fractions, paddings)
// so they don't drift between screens and cause i18n regressions.

/// Fixed width for items in horizontal choice carousels.
///
/// Keeping this constant ensures long localized labels never change the card
/// width; instead, text wraps/ellipsizes within the card.
const double carouselItemWidth = 170;

/// PageView viewport fraction for horizontal carousels.
///
/// This is tuned to show a hint of neighboring cards without making the active
/// card overly wide or overly narrow.
const double carouselViewportFraction = 0.78;

/// Diameter of the big circular buttons on the Home page.
const double homeCircleDiameter = 220;

/// Max lines for labels inside the Home page circles.
const int homeCircleLabelMaxLines = 3;
