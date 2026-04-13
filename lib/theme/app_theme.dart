import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary brand: Primary Pink (#FF477E)
  static const Color primary = Color(0xFFFF477E);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFAE0E4);
  static const Color onPrimaryContainer = Color(0xFF8B1538);
  static const Color primaryLight = Color(0xFFFF5C8A);
  static const Color primaryDark = Color(0xFFFF6B8F);
  static const Color onPrimaryDark = Color(0xFF000000);

  // Secondary: Teal
  static const Color secondary = Color(0xFF1E637C);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD6E8EF);
  static const Color onSecondaryContainer = Color(0xFF0A2E3D);

  // Tertiary: Yellow
  static const Color tertiary = Color(0xFFF59E0B);
  static const Color onTertiary = Color(0xFF000000);
  static const Color tertiaryContainer = Color(0xFFFEF3C7);
  static const Color onTertiaryContainer = Color(0xFF422006);

  // Light theme surfaces (scaffold — keep neutral; brand pink is `primary` only)
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color onBackgroundLight = Color(0xFF374151);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF374151);
  static const Color onSurfaceVariantLight = Color(0xFF718096);
  static const Color surfaceVariantLight = Color(0xFFFCE8EC);

  // Dark theme surfaces
  static const Color backgroundDark = Color(0xFF111827);
  static const Color onBackgroundDark = Color(0xFFF1F5F9);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color onSurfaceDark = Color(0xFFF1F5F9);
  static const Color onSurfaceVariantDark = Color(0xFFA0AEC0);
  static const Color surfaceVariantDark = Color(0xFF374151);

  // Outlines
  static const Color outlineLight = Color(0xFFA0AEC0);
  static const Color outlineDark = Color(0xFF4B5563);
  static const Color outlineVariantLight = Color(0xFFE5E7EB);
  static const Color outlineVariantDark = Color(0xFF374151);

  // Semantic colors
  static const Color error = Color(0xFFD32929);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF450A0A);
  static const Color errorDark = Color(0xFFF87171);

  static const Color warning = Color(0xFFF59E0B);
  static const Color onWarning = Color(0xFF000000);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF422006);

  static const Color success = Color(0xFF91C713);
  static const Color onSuccess = Color(0xFF000000);
  static const Color successContainer = Color(0xFFE8F5CF);
  static const Color onSuccessContainer = Color(0xFF2D3D0F);
  static const Color successDark = Color(0xFFA8D84A);

  static const Color info = Color(0xFF1E637C);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFD6E8EF);
  static const Color onInfoContainer = Color(0xFF0A2E3D);

  // Neutral scale
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFFA0AEC0);
  static const Color neutral500 = Color(0xFF718096);
  static const Color neutral600 = Color(0xFF4B5563);
  static const Color neutral700 = Color(0xFF374151);
  static const Color neutral800 = Color(0xFF1F2937);
  static const Color neutral900 = Color(0xFF111827);
  static const Color neutral950 = Color(0xFF0B0F19);

  // Shadows
  static const Color shadow = Color(0xFF000000);
  static const Color scrim = Color(0x66000000);

  // Inverse
  static const Color inverseSurfaceLight = Color(0xFF374151);
  static const Color inverseOnSurfaceLight = Color(0xFFF9FAFB);
  static const Color inverseSurfaceDark = Color(0xFFE5E7EB);
  static const Color inverseOnSurfaceDark = Color(0xFF111827);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.onSurfaceLight,
        surfaceContainerHighest: AppColors.surfaceVariantLight,
        onSurfaceVariant: AppColors.onSurfaceVariantLight,
        outline: AppColors.outlineLight,
        outlineVariant: AppColors.outlineVariantLight,
        shadow: AppColors.shadow,
        scrim: AppColors.scrim,
        inverseSurface: AppColors.inverseSurfaceLight,
        onInverseSurface: AppColors.inverseOnSurfaceLight,
        inversePrimary: AppColors.primaryDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.onBackgroundLight,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onBackgroundLight,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outlineVariantLight),
        ),
        color: AppColors.surfaceLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.outlineLight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantLight,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceVariantLight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.outlineLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.onSurfaceVariantLight,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.neutral400,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariantLight,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        elevation: 0,
        indicatorColor: AppColors.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariantLight,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inverseSurfaceLight,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.inverseOnSurfaceLight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariantLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryDark,
        onPrimary: AppColors.onPrimaryDark,
        primaryContainer: AppColors.neutral700,
        onPrimaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.neutral700,
        onSecondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.neutral700,
        onTertiaryContainer: AppColors.tertiaryContainer,
        error: AppColors.errorDark,
        onError: AppColors.onError,
        errorContainer: AppColors.neutral700,
        onErrorContainer: AppColors.errorContainer,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.onSurfaceDark,
        surfaceContainerHighest: AppColors.surfaceVariantDark,
        onSurfaceVariant: AppColors.onSurfaceVariantDark,
        outline: AppColors.outlineDark,
        outlineVariant: AppColors.outlineVariantDark,
        shadow: AppColors.shadow,
        scrim: AppColors.scrim,
        inverseSurface: AppColors.inverseSurfaceDark,
        onInverseSurface: AppColors.inverseOnSurfaceDark,
        inversePrimary: AppColors.primary,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.onBackgroundDark,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onBackgroundDark,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outlineVariantDark),
        ),
        color: AppColors.surfaceDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.onPrimaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.outlineDark),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantDark,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceVariantDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.outlineDark),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorDark),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.onSurfaceVariantDark,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.neutral500,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariantDark,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        indicatorColor: AppColors.neutral700,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariantDark,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.onPrimaryDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inverseSurfaceDark,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.inverseOnSurfaceDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.onSurfaceVariantDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final baseTextTheme = GoogleFonts.interTextTheme();
    final onSurface = brightness == Brightness.light
        ? AppColors.onSurfaceLight
        : AppColors.onSurfaceDark;
    final onSurfaceVariant = brightness == Brightness.light
        ? AppColors.onSurfaceVariantLight
        : AppColors.onSurfaceVariantDark;

    return baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        color: onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        color: onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        color: onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
