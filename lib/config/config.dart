import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// FontSource
// Tells BrandConfig where a font comes from so we can handle both
// bundled (asset) fonts and Google Fonts at runtime.
// ---------------------------------------------------------------------------
enum FontSource {
  /// A font already registered in the app's pubspec.yaml (e.g. ClashDisplay).
  asset,

  /// A font resolved at runtime via the google_fonts package.
  googleFont,
}

// ---------------------------------------------------------------------------
// FontConfig
// Encapsulates a client's chosen font family and where to load it from.
// ---------------------------------------------------------------------------
class FontConfig {
  /// The font family name.
  /// - For [FontSource.asset]      → must match the `family:` key in pubspec.yaml
  /// - For [FontSource.googleFont] → must match the exact Google Fonts name
  final String family;

  /// Where the font comes from.
  final FontSource source;

  const FontConfig({
    required this.family,
    this.source = FontSource.asset,
  });

  // Built-in presets --------------------------------------------------------

  /// Default display font (bundled ClashDisplay).
  static const FontConfig clashDisplay = FontConfig(
    family: 'ClashDisplay',
    source: FontSource.asset,
  );

  /// Default body font (bundled ClashGrotesk).
  static const FontConfig clashGrotesk = FontConfig(
    family: 'ClashGrotesk',
    source: FontSource.asset,
  );

  /// Convenience preset – Inter via Google Fonts.
  static const FontConfig inter = FontConfig(
    family: 'Inter',
    source: FontSource.googleFont,
  );

  /// Convenience preset – Poppins via Google Fonts.
  static const FontConfig poppins = FontConfig(
    family: 'Poppins',
    source: FontSource.googleFont,
  );

  /// Convenience preset – Outfit via Google Fonts.
  static const FontConfig outfit = FontConfig(
    family: 'Outfit',
    source: FontSource.googleFont,
  );
}

// ---------------------------------------------------------------------------
// BrandColors
// A strongly-typed palette for a single client brand.
// Maps 1-to-1 with Flutter's ColorScheme so buildTheme() stays clean.
// ---------------------------------------------------------------------------
class BrandColors {
  // Core semantic colors
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;

  // Surface / background
  final Color background;
  final Color surface;
  final Color surfaceContainer;

  // Content on surfaces
  final Color onBackground;
  final Color onSurface;
  final Color onSurfaceVariant;

  // Utility
  final Color error;
  final Color onError;

  const BrandColors({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.onBackground,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.error,
    required this.onError,
  });

  factory BrandColors.fromJson(Map<String, dynamic> json) {
    Color parseHex(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      try {
        String cleanHex = hex.replaceAll('#', '');
        if (cleanHex.length == 6) {
          cleanHex = 'FF$cleanHex';
        }
        return Color(int.parse(cleanHex, radix: 16));
      } catch (e) {
        return fallback;
      }
    }

    final primary = parseHex(json['color_primary'], BrandColors.qless.primary);
    final onPrimary = parseHex(json['color_on_primary'], BrandColors.qless.onPrimary);
    final secondary = parseHex(json['color_secondary'], BrandColors.qless.secondary);
    final onSecondary = parseHex(json['color_on_secondary'], BrandColors.qless.onSecondary);
    final background = parseHex(json['color_background'], BrandColors.qless.background);
    final surface = parseHex(json['color_surface'], BrandColors.qless.surface);
    final surfaceContainer = parseHex(json['color_surface_container'], BrandColors.qless.surfaceContainer);
    final onSurface = parseHex(json['color_on_surface'], BrandColors.qless.onSurface);
    final onSurfaceVariant = parseHex(json['color_on_surface_variant'], BrandColors.qless.onSurfaceVariant);

    return BrandColors(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      background: background,
      surface: surface,
      surfaceContainer: surfaceContainer,
      onBackground: onSurface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      error: BrandColors.qless.error,
      onError: BrandColors.qless.onError,
    );
  }

  // ---------------------------------------------------------------------------
  // Built-in brand presets
  // ---------------------------------------------------------------------------

  /// Default Qless palette (dark-navy + mint green).
  static const BrandColors qless = BrandColors(
    primary: Color(0xFF001A23),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFB3EFB2),
    onSecondary: Color(0xFF001A23),
    background: Color(0xFFE8F1F2),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFE8F1F2),
    onBackground: Color(0xFF001A23),
    onSurface: Color(0xFF001A23),
    onSurfaceVariant: Color(0xFF4A5568),
    error: Color(0xFFEF4444),
    onError: Color(0xFFFFFFFF),
  );

  /// Sample Lulu palette (red + gold).
  static const BrandColors lulu = BrandColors(
    primary: Color(0xFFCC0000),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFCC00),
    onSecondary: Color(0xFF1A0000),
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFEEEEEE),
    onBackground: Color(0xFF1A0000),
    onSurface: Color(0xFF1A0000),
    onSurfaceVariant: Color(0xFF555555),
    error: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
  );

  /// Sample Carrefour palette (blue + red).
  static const BrandColors carrefour = BrandColors(
    primary: Color(0xFF004B87),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFE30613),
    onSecondary: Color(0xFFFFFFFF),
    background: Color(0xFFF0F4F8),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFE4ECF4),
    onBackground: Color(0xFF001529),
    onSurface: Color(0xFF001529),
    onSurfaceVariant: Color(0xFF4A5568),
    error: Color(0xFFD32F2F),
    onError: Color(0xFFFFFFFF),
  );

  /// Creates a copy of this BrandColors with specific fields overridden.
  BrandColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? background,
    Color? surface,
    Color? surfaceContainer,
    Color? onBackground,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? error,
    Color? onError,
  }) {
    return BrandColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      onBackground: onBackground ?? this.onBackground,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      error: error ?? this.error,
      onError: onError ?? this.onError,
    );
  }
}

// ---------------------------------------------------------------------------
// BrandTypography
// Controls which font is used for display/headline text vs body/label text.
// The split mirrors how main.dart already differentiates ClashDisplay (display)
// from ClashGrotesk (body).
// ---------------------------------------------------------------------------
class BrandTypography {
  /// Font used for large display text, headlines, and titles.
  final FontConfig displayFont;

  /// Font used for body copy, labels, and captions.
  final FontConfig bodyFont;

  /// Optional: override base font size scale (1.0 = default).
  final double fontSizeScale;

  const BrandTypography({
    required this.displayFont,
    required this.bodyFont,
    this.fontSizeScale = 1.0,
  });

  factory BrandTypography.fromJson(Map<String, dynamic> json) {
    final displayFamily = json['font_display'] as String? ?? 'ClashDisplay';
    final bodyFamily = json['font_body'] as String? ?? 'ClashGrotesk';
    final scale = (json['font_size_scale'] as num?)?.toDouble() ?? 1.0;

    final displaySource = (displayFamily == 'ClashDisplay' || displayFamily == 'ClashGrotesk')
        ? FontSource.asset
        : FontSource.googleFont;
    final bodySource = (bodyFamily == 'ClashDisplay' || bodyFamily == 'ClashGrotesk')
        ? FontSource.asset
        : FontSource.googleFont;

    return BrandTypography(
      displayFont: FontConfig(family: displayFamily, source: displaySource),
      bodyFont: FontConfig(family: bodyFamily, source: bodySource),
      fontSizeScale: scale,
    );
  }

  // Built-in typography presets ---------------------------------------------

  /// Default Qless typography (ClashDisplay / ClashGrotesk — both bundled).
  static const BrandTypography qless = BrandTypography(
    displayFont: FontConfig.clashDisplay,
    bodyFont: FontConfig.clashGrotesk,
  );

  /// Clean, modern sans-serif using Google Fonts (Inter everywhere).
  static const BrandTypography modern = BrandTypography(
    displayFont: FontConfig.inter,
    bodyFont: FontConfig.inter,
  );

  /// Friendly rounded look using Poppins.
  static const BrandTypography friendly = BrandTypography(
    displayFont: FontConfig.poppins,
    bodyFont: FontConfig.poppins,
  );

  /// Geometric style using Outfit.
  static const BrandTypography geometric = BrandTypography(
    displayFont: FontConfig.outfit,
    bodyFont: FontConfig.outfit,
  );

  /// Creates a copy of this BrandTypography with specific fields overridden.
  BrandTypography copyWith({
    FontConfig? displayFont,
    FontConfig? bodyFont,
    double? fontSizeScale,
  }) {
    return BrandTypography(
      displayFont: displayFont ?? this.displayFont,
      bodyFont: bodyFont ?? this.bodyFont,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
    );
  }
}

// ---------------------------------------------------------------------------
// BrandIdentity
// Non-visual brand metadata: name, logo, and other identifiers.
// ---------------------------------------------------------------------------
class BrandIdentity {
  /// The human-readable name of the hypermarket (used in AppBar titles etc.)
  final String appName;

  /// Asset path to the logo image bundled with the app.
  /// e.g. 'assets/logos/lulu_logo.png'
  /// Leave null to fall back to a text-based logo.
  final String? logoAssetPath;

  /// Remote URL to load a logo from (used when logo is stored in Supabase).
  /// logoAssetPath takes precedence if both are provided.
  final String? logoNetworkUrl;

  /// Short tagline shown on splash/onboarding screens. Optional.
  final String? tagline;

  /// Unique slug used to identify this tenant in Supabase.
  /// e.g. 'lulu', 'carrefour', 'nesto'
  final String tenantId;

  const BrandIdentity({
    required this.appName,
    required this.tenantId,
    this.logoAssetPath,
    this.logoNetworkUrl,
    this.tagline,
  });

  factory BrandIdentity.fromJson(Map<String, dynamic> json) {
    return BrandIdentity(
      appName: json['app_name'] as String? ?? 'Qless',
      tenantId: json['tenant_id'] as String? ?? 'qless',
      tagline: json['tagline'] as String? ?? 'Skip the queue.',
      logoNetworkUrl: json['logo_url'] as String?,
    );
  }

  // Built-in identity presets -----------------------------------------------

  /// Default Qless identity (used during development / fallback).
  static const BrandIdentity qless = BrandIdentity(
    appName: 'Qless',
    tenantId: 'qless',
    tagline: 'Skip the queue.',
  );

  static const BrandIdentity lulu = BrandIdentity(
    appName: 'LuLu',
    tenantId: 'lulu',
    tagline: 'Quality you can trust.',
  );

  static const BrandIdentity carrefour = BrandIdentity(
    appName: 'Carrefour',
    tenantId: 'carrefour',
    tagline: 'Live more, spend less.',
  );

  /// Creates a copy of this BrandIdentity with specific fields overridden.
  BrandIdentity copyWith({
    String? appName,
    String? tenantId,
    String? logoAssetPath,
    String? logoNetworkUrl,
    String? tagline,
  }) {
    return BrandIdentity(
      appName: appName ?? this.appName,
      tenantId: tenantId ?? this.tenantId,
      logoAssetPath: logoAssetPath ?? this.logoAssetPath,
      logoNetworkUrl: logoNetworkUrl ?? this.logoNetworkUrl,
      tagline: tagline ?? this.tagline,
    );
  }
}

// ---------------------------------------------------------------------------
// BrandConfig  ← the top-level object the app consumes
// Composes Identity + Colors + Typography and exposes a buildTheme() method
// that the MaterialApp can consume directly.
// ---------------------------------------------------------------------------
class BrandConfig {
  static BrandConfig active = BrandConfig.qless();

  final BrandIdentity identity;
  final BrandColors colors;
  final BrandTypography typography;

  const BrandConfig({
    required this.identity,
    required this.colors,
    required this.typography,
  });

  factory BrandConfig.fromJson(Map<String, dynamic> json) {
    return BrandConfig(
      identity: BrandIdentity.fromJson(json),
      colors: BrandColors.fromJson(json),
      typography: BrandTypography.fromJson(json),
    );
  }

  // ---------------------------------------------------------------------------
  // Factory constructors — one per known preset combination
  // ---------------------------------------------------------------------------

  /// The default Qless configuration — used as a fallback.
  factory BrandConfig.qless() => const BrandConfig(
        identity: BrandIdentity.qless,
        colors: BrandColors.qless,
        typography: BrandTypography.qless,
      );

  /// LuLu Hypermarket preset.
  factory BrandConfig.lulu() => const BrandConfig(
        identity: BrandIdentity.lulu,
        colors: BrandColors.lulu,
        typography: BrandTypography.friendly,
      );

  /// Carrefour preset.
  factory BrandConfig.carrefour() => const BrandConfig(
        identity: BrandIdentity.carrefour,
        colors: BrandColors.carrefour,
        typography: BrandTypography.modern,
      );

  // ---------------------------------------------------------------------------
  // buildTheme()
  // Converts this BrandConfig into a Flutter ThemeData ready for MaterialApp.
  // ---------------------------------------------------------------------------
  TextStyle _resolveStyle(FontConfig fontConfig, TextStyle baseStyle) {
    if (fontConfig.source == FontSource.googleFont) {
      try {
        return GoogleFonts.getFont(
          fontConfig.family,
          textStyle: baseStyle,
        );
      } catch (e) {
        return baseStyle.copyWith(fontFamily: fontConfig.family);
      }
    } else {
      return baseStyle.copyWith(fontFamily: fontConfig.family);
    }
  }

  ThemeData buildTheme() {
    final c = colors;
    final t = typography;

    final String bodyFamily = t.bodyFont.family;

    final colorScheme = ColorScheme.light(
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.secondary,
      onSecondary: c.onSecondary,
      surface: c.surface,
      surfaceContainer: c.surfaceContainer,
      surfaceContainerHigh: c.surfaceContainer,
      onSurface: c.onSurface,
      onSurfaceVariant: c.onSurfaceVariant,
      error: c.error,
      onError: c.onError,
    );

    final baseTextTheme = ThemeData.light().textTheme;

    final textTheme = baseTextTheme
        .copyWith(
          displayLarge: _resolveStyle(t.displayFont, baseTextTheme.displayLarge ?? const TextStyle()),
          displayMedium: _resolveStyle(t.displayFont, baseTextTheme.displayMedium ?? const TextStyle()),
          displaySmall: _resolveStyle(t.displayFont, baseTextTheme.displaySmall ?? const TextStyle()),
          headlineLarge: _resolveStyle(t.displayFont, baseTextTheme.headlineLarge ?? const TextStyle()),
          headlineMedium: _resolveStyle(t.displayFont, baseTextTheme.headlineMedium ?? const TextStyle()),
          headlineSmall: _resolveStyle(t.displayFont, baseTextTheme.headlineSmall ?? const TextStyle()),
          titleLarge: _resolveStyle(t.displayFont, baseTextTheme.titleLarge ?? const TextStyle()),
          titleMedium: _resolveStyle(t.displayFont, baseTextTheme.titleMedium ?? const TextStyle()),
          titleSmall: _resolveStyle(t.displayFont, baseTextTheme.titleSmall ?? const TextStyle()),
          bodyLarge: _resolveStyle(t.bodyFont, baseTextTheme.bodyLarge ?? const TextStyle()),
          bodyMedium: _resolveStyle(t.bodyFont, baseTextTheme.bodyMedium ?? const TextStyle()),
          bodySmall: _resolveStyle(t.bodyFont, baseTextTheme.bodySmall ?? const TextStyle()),
          labelLarge: _resolveStyle(t.bodyFont, baseTextTheme.labelLarge ?? const TextStyle()),
          labelMedium: _resolveStyle(t.bodyFont, baseTextTheme.labelMedium ?? const TextStyle()),
          labelSmall: _resolveStyle(t.bodyFont, baseTextTheme.labelSmall ?? const TextStyle()),
        )
        .apply(
          bodyColor: c.onSurface,
          displayColor: c.onSurface,
          // Apply font size scaling if set
          fontSizeFactor: t.fontSizeScale,
        );

    return ThemeData(
      fontFamily: bodyFamily,
      scaffoldBackgroundColor: c.background,
      colorScheme: colorScheme,
      textTheme: textTheme,
    );
  }

  /// Creates a copy of this BrandConfig with specific sections overridden.
  BrandConfig copyWith({
    BrandIdentity? identity,
    BrandColors? colors,
    BrandTypography? typography,
  }) {
    return BrandConfig(
      identity: identity ?? this.identity,
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
    );
  }
}
