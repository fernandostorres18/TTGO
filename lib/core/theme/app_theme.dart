import 'package:flutter/material.dart';

class AppTheme {
  // ── TTGO Purple Color Palette ──────────────────────────────────────────────
  static const Color primary       = Color(0xFF7B1FA2); // roxo principal
  static const Color primaryLight  = Color(0xFFAB47BC); // roxo médio
  static const Color primaryDark   = Color(0xFF4A148C); // roxo escuro (parte baixa da seta)
  static const Color primarySurface= Color(0xFFF3E5F5); // superfície roxa suave
  static const Color accent        = Color(0xFFCE93D8); // roxo claro (parte alta da seta)
  static const Color accentLight   = Color(0xFFE1BEE7);
  // Gradiente mais claro para o logo TTGO se destacar no header
  static const Color gradientStart = Color(0xFF9C27B0); // roxo vivo (topo do header)
  static const Color gradientEnd   = Color(0xFF6A1B9A); // roxo médio-escuro (base do header)

  // Utility colors (unchanged)
  static const Color warning       = Color(0xFFFF9800);
  static const Color warningLight  = Color(0xFFFFF3E0);
  static const Color error         = Color(0xFFE53935);
  static const Color errorLight    = Color(0xFFFFEBEE);
  static const Color success       = Color(0xFF43A047);
  static const Color successLight  = Color(0xFFE8F5E9);
  static const Color info          = Color(0xFF7B1FA2); // usa roxo como info
  static const Color infoLight     = Color(0xFFF3E5F5);
  static const Color surface       = Color(0xFFF8F5FC); // superfície com toque roxo
  static const Color cardBg        = Colors.white;
  static const Color textPrimary   = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint      = Color(0xFFBDBDBD);
  static const Color divider       = Color(0xFFEEEEEE);

  // Status colors
  static const Color statusRecebido   = Color(0xFF90A4AE);
  static const Color statusAguardando = Color(0xFFFFA726);
  static const Color statusSeparando  = Color(0xFFAB47BC);
  static const Color statusFaturado   = Color(0xFF7B1FA2);
  static const Color statusEnviado    = Color(0xFF26C6DA);
  static const Color statusFinalizado = Color(0xFF66BB6A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primarySurface,
        labelStyle: const TextStyle(color: primary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(color: divider, space: 1, thickness: 1),
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold,  color: textPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,  color: textPrimary),
        headlineSmall:  TextStyle(fontSize: 18, fontWeight: FontWeight.w600,  color: textPrimary),
        titleLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w600,  color: textPrimary),
        titleMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600,  color: textPrimary),
        titleSmall:     TextStyle(fontSize: 13, fontWeight: FontWeight.w500,  color: textPrimary),
        bodyLarge:      TextStyle(fontSize: 15, color: textPrimary),
        bodyMedium:     TextStyle(fontSize: 14, color: textPrimary),
        bodySmall:      TextStyle(fontSize: 12, color: textSecondary),
        labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelSmall:     TextStyle(fontSize: 11, color: textSecondary),
      ),
    );
  }

  // Gradient header – roxo vivo → roxo médio (mais claro para destacar o logo)
  static BoxDecoration get headerGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [gradientStart, gradientEnd],
    ),
  );
}
