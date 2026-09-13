import 'package:flutter/material.dart';

class AppTheme {
  static const Color primarySeed = Color(0xFF4F46E5);
  static const Color secondarySeed = Color(0xFF6366F1);

  // Light Theme Color System Tokens
  static const Color lightMainBackground = Color(0xFFFFFFFF);
  static const Color lightSecondaryBackground = Color(0xFFF8FAFC);
  static const Color lightSidebar = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightHoverSurface = Color(0xFFEEF2F6);
  static const Color lightSelectedSurface = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);
  static const Color lightPrimaryText = Color(0xFF0F172A);
  static const Color lightSecondaryText = Color(0xFF64748B);
  static const Color lightDisabledText = Color(0xFF94A3B8);
  static const Color lightIcon = Color(0xFF64748B);

  static const Color lightAccent = Color(0xFF4F46E5); // Modern Indigo 600
  static const Color lightAccentHover = Color(0xFF4338CA);
  static const Color lightAccentPressed = Color(0xFF3730A3);

  static const Color lightSwitchOnBg = Color(0xFF4F46E5);
  static const Color lightSwitchThumb = Color(0xFFFFFFFF);

  static const Color lightActiveSidebarIcon = Color(0xFF4F46E5);
  static const Color lightActiveSidebarBg = Color(0xFFEEF2FF); // Indigo 50

  static const Color lightSegmentBg = Color(0xFFF1F5F9);
  static const Color lightSegmentSelected = Color(0xFFFFFFFF);
  static const Color lightSegmentSelectedBorder = Color(0xFFE2E8F0);
  static const Color lightSegmentSelectedText = Color(0xFF0F172A);
  static const Color lightSegmentUnselectedText = Color(0xFF64748B);

  static const Color lightSubtleShadow = Color.fromRGBO(15, 23, 42, 0.06);

  // Modern Status Color Tokens
  static const Color statusPresent = Color(0xFF10B981);
  static const Color statusPresentBgLight = Color(0xFFECFDF5);
  static const Color statusPresentBgDark = Color(0xFF064E3B);

  static const Color statusLate = Color(0xFFF59E0B);
  static const Color statusLateBgLight = Color(0xFFFFFBEB);
  static const Color statusLateBgDark = Color(0xFF78350F);

  static const Color statusAbsent = Color(0xFFEF4444);
  static const Color statusAbsentBgLight = Color(0xFFFEF2F2);
  static const Color statusAbsentBgDark = Color(0xFF7F1D1D);

  static const Color statusCheckout = Color(0xFF3B82F6);
  static const Color statusCheckoutBgLight = Color(0xFFEFF6FF);
  static const Color statusCheckoutBgDark = Color(0xFF1E3A8A);

  // Linear Gradient Presets
  static const LinearGradient primaryGradientLight = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [Color(0xFF3730A3), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightMainBackground,
        colorScheme: const ColorScheme.light(
          primary: lightAccent,
          onPrimary: lightMainBackground,
          primaryContainer: lightActiveSidebarBg,
          onPrimaryContainer: lightAccent,
          secondary: lightAccent,
          onSecondary: lightMainBackground,
          surface: lightMainBackground,
          onSurface: lightPrimaryText,
          onSurfaceVariant: lightSecondaryText,
          surfaceContainer: lightMainBackground,
          surfaceContainerLow: lightSecondaryBackground,
          surfaceContainerHigh: lightHoverSurface,
          surfaceContainerHighest: lightSelectedSurface,
          outline: lightBorder,
          outlineVariant: lightDivider,
          shadow: lightSubtleShadow,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: lightMainBackground,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: lightIcon),
          actionsIconTheme: IconThemeData(color: lightIcon),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: lightPrimaryText,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: lightCard,
          shadowColor: lightSubtleShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: lightBorder, width: 1),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: lightDivider,
          thickness: 1,
          space: 1,
        ),
        iconTheme: const IconThemeData(
          color: lightIcon,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return lightSwitchThumb;
            }
            return lightIcon;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return lightSwitchOnBg;
            }
            return lightSegmentBg;
          }),
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.transparent;
            }
            return lightBorder;
          }),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return lightSegmentSelected;
              }
              return lightSegmentBg;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return lightSegmentSelectedText;
              }
              return lightSegmentUnselectedText;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const BorderSide(color: lightSegmentSelectedBorder);
              }
              return const BorderSide(color: Colors.transparent);
            }),
            iconColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return lightSegmentSelectedText;
              }
              return lightSegmentUnselectedText;
            }),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightSecondaryBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: lightDisabledText),
          labelStyle: const TextStyle(color: lightSecondaryText),
          prefixIconColor: lightIcon,
          suffixIconColor: lightIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: lightAccent, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return lightSegmentBg;
              }
              if (states.contains(WidgetState.pressed)) {
                return lightAccentPressed;
              }
              if (states.contains(WidgetState.hovered)) {
                return lightAccentHover;
              }
              return lightAccent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return lightDisabledText;
              }
              return lightMainBackground;
            }),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightCard,
            foregroundColor: lightPrimaryText,
            shadowColor: lightSubtleShadow,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: lightBorder),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: lightPrimaryText,
            side: const BorderSide(color: lightBorder),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: lightSidebar,
          selectedIconTheme: IconThemeData(color: lightActiveSidebarIcon),
          unselectedIconTheme: IconThemeData(color: lightIcon),
          indicatorColor: lightActiveSidebarBg,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: lightSidebar,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: lightMainBackground,
          selectedItemColor: lightActiveSidebarIcon,
          unselectedItemColor: lightIcon,
        ),
        dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: lightMainBackground,
          surfaceTintColor: Colors.transparent,
          shadowColor: lightSubtleShadow,
          elevation: 2,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: lightMainBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: lightIcon,
          textColor: lightPrimaryText,
        ),
        hoverColor: lightAccent.withValues(alpha: 0.04),
        highlightColor: lightAccent.withValues(alpha: 0.08),
      );

  // Dark Theme Color System Tokens
  static const Color darkMainBackground = Color(0xFF0B0F17); // Deep Obsidian
  static const Color darkSecondaryBackground =
      Color(0xFF111827); // Rich dark slate
  static const Color darkSidebar = Color(0xFF111827);
  static const Color darkCard = Color(0xFF111827);
  static const Color darkHoverSurface = Color(0xFF1F2937);
  static const Color darkSelectedSurface = Color(0xFF283548);
  static const Color darkBorder = Color(0xFF1F293D);
  static const Color darkDivider = Color(0xFF1E293B);
  static const Color darkPrimaryText = Color(0xFFF8FAFC);
  static const Color darkSecondaryText = Color(0xFF94A3B8);
  static const Color darkDisabledText = Color(0xFF64748B);
  static const Color darkIcon = Color(0xFF94A3B8);

  static const Color darkAccent = Color(0xFF6366F1); // Modern Indigo 500
  static const Color darkAccentHover = Color(0xFF818CF8); // Indigo 400
  static const Color darkAccentPressed = Color(0xFF4F46E5); // Indigo 600

  static const Color darkSwitchOnBg = Color(0xFF6366F1);
  static const Color darkSwitchThumb = Color(0xFFFFFFFF);

  static const Color darkActiveSidebarIcon = Color(0xFF6366F1);
  static const Color darkActiveSidebarBg = Color(0xFF1E2238);

  static const Color darkSegmentBg = Color(0xFF151D2C);
  static const Color darkSegmentSelected = Color(0xFF1E293B);
  static const Color darkSegmentSelectedBorder = Color(0xFF334155);
  static const Color darkSegmentSelectedText = Color(0xFFF8FAFC);
  static const Color darkSegmentUnselectedText = Color(0xFF94A3B8);

  static const Color darkSubtleShadow = Color.fromRGBO(0, 0, 0, 0.45);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkMainBackground,
        colorScheme: const ColorScheme.dark(
          primary: darkAccent,
          onPrimary: Colors.white,
          primaryContainer: darkActiveSidebarBg,
          onPrimaryContainer: darkAccent,
          secondary: darkAccent,
          onSecondary: Colors.white,
          surface: darkSecondaryBackground,
          onSurface: darkPrimaryText,
          onSurfaceVariant: darkSecondaryText,
          surfaceContainer: darkSecondaryBackground,
          surfaceContainerLow: darkMainBackground,
          surfaceContainerHigh: darkHoverSurface,
          surfaceContainerHighest: darkSelectedSurface,
          outline: darkBorder,
          outlineVariant: darkDivider,
          shadow: darkSubtleShadow,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: darkMainBackground,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: darkIcon),
          actionsIconTheme: IconThemeData(color: darkIcon),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkPrimaryText,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: darkCard,
          shadowColor: darkSubtleShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: darkBorder, width: 1),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: darkDivider,
          thickness: 1,
          space: 1,
        ),
        iconTheme: const IconThemeData(
          color: darkIcon,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return darkSwitchThumb;
            }
            return darkIcon;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return darkSwitchOnBg;
            }
            return darkSegmentBg;
          }),
          trackOutlineColor: WidgetStateProperty.all(darkBorder),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return darkSegmentSelected;
              }
              return darkSegmentBg;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return darkSegmentSelectedText;
              }
              return darkSegmentUnselectedText;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const BorderSide(color: darkSegmentSelectedBorder);
              }
              return const BorderSide(color: darkBorder);
            }),
            iconColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return darkSegmentSelectedText;
              }
              return darkSegmentUnselectedText;
            }),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkSecondaryBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: const TextStyle(color: darkDisabledText),
          labelStyle: const TextStyle(color: darkSecondaryText),
          prefixIconColor: darkIcon,
          suffixIconColor: darkIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: darkAccent, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return darkSegmentBg;
              }
              if (states.contains(WidgetState.pressed)) {
                return darkAccentPressed;
              }
              if (states.contains(WidgetState.hovered)) {
                return darkAccentHover;
              }
              return darkAccent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return darkDisabledText;
              }
              return Colors.white;
            }),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkSecondaryBackground,
            foregroundColor: darkPrimaryText,
            shadowColor: darkSubtleShadow,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: darkBorder),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkPrimaryText,
            side: const BorderSide(color: darkBorder),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: darkSidebar,
          selectedIconTheme: IconThemeData(color: darkActiveSidebarIcon),
          unselectedIconTheme: IconThemeData(color: darkIcon),
          indicatorColor: darkActiveSidebarBg,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: darkSidebar,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: darkSecondaryBackground,
          selectedItemColor: darkActiveSidebarIcon,
          unselectedItemColor: darkIcon,
        ),
        dialogTheme: DialogThemeData(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: darkSecondaryBackground,
          surfaceTintColor: Colors.transparent,
          shadowColor: darkSubtleShadow,
          elevation: 2,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: darkSecondaryBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: darkIcon,
          textColor: darkPrimaryText,
        ),
        hoverColor: darkAccent.withValues(alpha: 0.08),
        highlightColor: darkAccent.withValues(alpha: 0.12),
      );
}
