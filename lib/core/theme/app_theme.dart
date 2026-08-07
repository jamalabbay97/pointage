import 'package:flutter/material.dart';

class AppTheme {
  static const Color primarySeed = Color(0xFF246BFD);
  static const Color secondarySeed = Color(0xFF00C9A7);

  // Light Theme Color System Tokens
  static const Color lightMainBackground = Color(0xFFFFFFFF);
  static const Color lightSecondaryBackground = Color(0xFFF8FAFC);
  static const Color lightSidebar = Color(0xFFF4F5F7); // Slightly gray sidebar like in image
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightHoverSurface = Color(0xFFF1F5F9);
  static const Color lightSelectedSurface = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);
  static const Color lightPrimaryText = Color(0xFF0F172A);
  static const Color lightSecondaryText = Color(0xFF64748B);
  static const Color lightDisabledText = Color(0xFF94A3B8);
  static const Color lightIcon = Color(0xFF64748B);

  static const Color lightAccent = Color(0xFF74A99A); // Same green as dark mode
  static const Color lightAccentHover = Color(0xFF80B3A5);
  static const Color lightAccentPressed = Color(0xFF679989);

  static const Color lightSwitchOnBg = Color(0xFF74A99A);
  static const Color lightSwitchThumb = Color(0xFFFFFFFF);

  static const Color lightActiveSidebarIcon = Color(0xFF74A99A);
  static const Color lightActiveSidebarBg = Color(0xFFFFFFFF);

  static const Color lightSegmentBg = Color(0xFFF1F5F9);
  static const Color lightSegmentSelected = Color(0xFFFFFFFF);
  static const Color lightSegmentSelectedBorder = Color(0xFFE2E8F0);
  static const Color lightSegmentSelectedText = Color(0xFF0F172A);
  static const Color lightSegmentUnselectedText = Color(0xFF64748B);

  static const Color lightSubtleShadow = Color.fromRGBO(0, 0, 0, 0.05);

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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
        hoverColor: lightHoverSurface,
        highlightColor: lightSelectedSurface,
      );

  // Dark Theme Color System Tokens
  static const Color darkMainBackground = Color(0xFF181818);
  static const Color darkSecondaryBackground = Color(0xFF202020);
  static const Color darkSidebar = Color(0xFF202020);
  static const Color darkCard = Color(0xFF202020);
  static const Color darkHoverSurface = Color(0xFF292929);
  static const Color darkSelectedSurface = Color(0xFF2E2E2E);
  static const Color darkBorder = Color(0xFF313131);
  static const Color darkDivider = Color(0xFF333333);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFA5A5A5);
  static const Color darkDisabledText = Color(0xFF707070);
  static const Color darkIcon = Color(0xFFA0A0A0);

  static const Color darkAccent = Color(0xFF74A99A);
  static const Color darkAccentHover = Color(0xFF80B3A5);
  static const Color darkAccentPressed = Color(0xFF679989);

  static const Color darkSwitchOnBg = Color(0xFF74A99A);
  static const Color darkSwitchThumb = Color(0xFF202020);

  static const Color darkActiveSidebarIcon = Color(0xFF74A99A);
  static const Color darkActiveSidebarBg = Color(0xFF262626);

  static const Color darkSegmentBg = Color(0xFF242424);
  static const Color darkSegmentSelected = Color(0xFF1D1D1D);
  static const Color darkSegmentSelectedBorder = Color(0xFF363636);
  static const Color darkSegmentSelectedText = Color(0xFFFFFFFF);
  static const Color darkSegmentUnselectedText = Color(0xFF9C9C9C);

  static const Color darkSubtleShadow = Color.fromRGBO(0, 0, 0, 0.35);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkMainBackground,
        colorScheme: const ColorScheme.dark(
          primary: darkAccent,
          onPrimary: darkSecondaryBackground,
          primaryContainer: darkActiveSidebarBg,
          onPrimaryContainer: darkAccent,
          secondary: darkAccent,
          onSecondary: darkSecondaryBackground,
          surface: darkSecondaryBackground,
          onSurface: darkPrimaryText,
          onSurfaceVariant: darkSecondaryText,
          surfaceContainer: darkSecondaryBackground,
          surfaceContainerLow: darkSecondaryBackground,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              return darkSecondaryBackground;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
        hoverColor: darkHoverSurface,
        highlightColor: darkSelectedSurface,
      );
}
