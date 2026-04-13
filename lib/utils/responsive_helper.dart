import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;
  static const double posDeviceBreakpoint = 1920;

  // Device type detection
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < posDeviceBreakpoint;
  }

  static bool isPosDevice(BuildContext context) {
    return MediaQuery.of(context).size.width >= posDeviceBreakpoint;
  }

  // Platform detection
  static bool isIOS(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.iOS;
  }

  static bool isAndroid(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.android;
  }

  // Responsive grid columns
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (isPosDevice(context)) {
      return 6; // POS devices - 6 columns
    } else if (isDesktop(context)) {
      return 5; // Desktop - 5 columns
    } else if (isTablet(context)) {
      return 4; // Tablet - 4 columns
    } else {
      return 3; // Mobile - 3 columns
    }
  }

  // Responsive spacing
  static double getSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (isPosDevice(context)) {
      return 16.0; // POS devices - larger spacing
    } else if (isDesktop(context)) {
      return 12.0; // Desktop - medium spacing
    } else if (isTablet(context)) {
      return 10.0; // Tablet - medium-small spacing
    } else {
      return 8.0; // Mobile - smaller spacing
    }
  }

  // Responsive card aspect ratio
  static double getCardAspectRatio(BuildContext context) {
    if (isPosDevice(context)) {
      return 0.9; // POS devices - slightly taller cards
    } else if (isDesktop(context)) {
      return 0.85; // Desktop - balanced cards
    } else if (isTablet(context)) {
      return 0.8; // Tablet - compact cards
    } else {
      return 0.75; // Mobile - very compact cards
    }
  }

  // Responsive font sizes
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;

    if (isPosDevice(context)) {
      return baseSize * 1.2; // POS devices - larger fonts
    } else if (isDesktop(context)) {
      return baseSize * 1.1; // Desktop - slightly larger fonts
    } else if (isTablet(context)) {
      return baseSize; // Tablet - base size
    } else {
      return baseSize * 0.9; // Mobile - smaller fonts
    }
  }

  // Responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (isPosDevice(context)) {
      return const EdgeInsets.all(24.0); // POS devices - larger padding
    } else if (isDesktop(context)) {
      return const EdgeInsets.all(20.0); // Desktop - medium padding
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16.0); // Tablet - standard padding
    } else {
      return const EdgeInsets.all(12.0); // Mobile - smaller padding
    }
  }

  // Responsive icon sizes
  static double getIconSize(BuildContext context, double baseSize) {
    if (isPosDevice(context)) {
      return baseSize * 1.3; // POS devices - larger icons
    } else if (isDesktop(context)) {
      return baseSize * 1.1; // Desktop - slightly larger icons
    } else if (isTablet(context)) {
      return baseSize; // Tablet - base size
    } else {
      return baseSize * 0.9; // Mobile - smaller icons
    }
  }

  // Get device type string for debugging
  static String getDeviceType(BuildContext context) {
    if (isPosDevice(context)) return 'POS Device';
    if (isDesktop(context)) return 'Desktop';
    if (isTablet(context)) return 'Tablet';
    if (isMobile(context)) return 'Mobile';
    return 'Unknown';
  }

  // Responsive layout builder
  static Widget buildResponsive({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
    Widget? posDevice,
  }) {
    if (isPosDevice(context) && posDevice != null) {
      return posDevice;
    } else if (isDesktop(context) && desktop != null) {
      return desktop;
    } else if (isTablet(context) && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }
}

// Extension methods for easier usage
extension ResponsiveContext on BuildContext {
  bool get isMobile => ResponsiveHelper.isMobile(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isDesktop => ResponsiveHelper.isDesktop(this);
  bool get isPosDevice => ResponsiveHelper.isPosDevice(this);
  bool get isIOS => ResponsiveHelper.isIOS(this);
  bool get isAndroid => ResponsiveHelper.isAndroid(this);

  int get gridColumns => ResponsiveHelper.getGridColumns(this);
  double get spacing => ResponsiveHelper.getSpacing(this);
  double get cardAspectRatio => ResponsiveHelper.getCardAspectRatio(this);
  EdgeInsets get responsivePadding =>
      ResponsiveHelper.getResponsivePadding(this);
  String get deviceType => ResponsiveHelper.getDeviceType(this);

  double responsiveFontSize(double baseSize) =>
      ResponsiveHelper.getResponsiveFontSize(this, baseSize);
  double responsiveIconSize(double baseSize) =>
      ResponsiveHelper.getIconSize(this, baseSize);
}
