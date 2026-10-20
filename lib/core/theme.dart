import 'package:flutter/material.dart';

const hiveYellow = Color(0xFFF47A20);
const hiveBlack = Color(0xFF0B2D3B);
const hiveGreen = Color(0xFF23846D);
const hiveMuted = Color(0xFF68777E);
const hiveLine = Color(0xFFDDE5E8);
const hiveCanvas = Color(0xFFF5F7F8);

final buildHiveTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: hiveCanvas,
  colorScheme: ColorScheme.fromSeed(
      seedColor: hiveYellow,
      primary: hiveYellow,
      onPrimary: Colors.white,
      secondary: hiveGreen,
      onSecondary: Colors.white,
      surface: Colors.white,
      surfaceTint: Colors.transparent),
  appBarTheme: const AppBarTheme(
    backgroundColor: hiveBlack,
    foregroundColor: Colors.white,
    centerTitle: false,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: hiveLine)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: hiveLine)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: hiveYellow, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    hintStyle: const TextStyle(color: hiveMuted, fontSize: 15),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
    backgroundColor: hiveYellow,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    elevation: 0,
    textStyle: const TextStyle(fontWeight: FontWeight.w800),
  )),
  outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
    foregroundColor: hiveBlack,
    minimumSize: const Size.fromHeight(50),
    side: const BorderSide(color: hiveLine),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  )),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: hiveYellow,
    side: const BorderSide(color: hiveLine),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    labelStyle: const TextStyle(color: hiveBlack, fontWeight: FontWeight.w600),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 68,
    backgroundColor: hiveBlack,
    elevation: 0,
    indicatorColor: hiveYellow,
    indicatorShape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected)
          ? hiveBlack
          : Colors.white70)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
          ? FontWeight.w700
          : FontWeight.w500)),
  ),
  cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: hiveLine))),
);
