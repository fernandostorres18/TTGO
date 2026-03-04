// lib/core/widgets/ttgo_logo.dart
// Logo TTGO com seta roxa bicolor (roxo claro em cima, escuro embaixo)
import 'package:flutter/material.dart';

class TtgoLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool darkBackground; // true = texto branco, false = texto roxo

  const TtgoLogo({
    super.key,
    this.size = 56,
    this.showText = true,
    this.darkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkBackground ? Colors.white : const Color(0xFF4A148C);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showText) ...[
          Text(
            'TTGO',
            style: TextStyle(
              fontSize: size * 0.55,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(width: size * 0.12),
        ],
        // Seta TTGO bicolor
        CustomPaint(
          size: Size(size * 0.55, size * 0.7),
          painter: _TtgoArrowPainter(),
        ),
      ],
    );
  }
}

// Chevron/seta roxa bicolor: a parte de cima usa roxo claro, a parte de baixo roxo escuro
class _TtgoArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h / 2; // ponto central vertical

    // ── Seta superior (roxo claro – parte acima da ponta) ─────────────────
    final paintLight = Paint()
      ..color = const Color(0xFFCE93D8)  // roxo claro
      ..style = PaintingStyle.fill;

    // Forma: triângulo/chevron superior
    //   top-left → ponta central-direita → mid-left
    final topPath = Path();
    topPath.moveTo(0, 0);              // topo esquerdo
    topPath.lineTo(w, mid);            // ponta direita (centro)
    topPath.lineTo(w * 0.15, mid);     // retorno ao centro esquerdo
    topPath.lineTo(0, 0);
    topPath.close();
    canvas.drawPath(topPath, paintLight);

    // ── Seta inferior (roxo escuro – parte abaixo da ponta) ──────────────
    final paintDark = Paint()
      ..color = const Color(0xFF6A1B9A)  // roxo escuro
      ..style = PaintingStyle.fill;

    final botPath = Path();
    botPath.moveTo(0, h);              // fundo esquerdo
    botPath.lineTo(w * 0.15, mid);     // centro esquerdo
    botPath.lineTo(w, mid);            // ponta direita
    botPath.lineTo(0, h);
    botPath.close();
    canvas.drawPath(botPath, paintDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Versão compacta para AppBar / shell (só ícone da seta)
class TtgoArrowIcon extends StatelessWidget {
  final double size;
  const TtgoArrowIcon({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.75, size),
      painter: _TtgoArrowPainter(),
    );
  }
}
