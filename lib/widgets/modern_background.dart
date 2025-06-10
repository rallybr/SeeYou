import 'package:flutter/material.dart';

class ModernBackground extends StatelessWidget {
  final Widget? child;
  const ModernBackground({Key? key, this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradiente principal
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF2D2EFF), // Azul
                Color(0xFF7B2FF2), // Roxo
                Color(0xFFE94057), // Rosa
              ],
            ),
          ),
        ),
        // Elementos geométricos
        Positioned(
          top: 60,
          left: 30,
          child: Opacity(
            opacity: 0.18,
            child: _DotMatrix(rows: 7, columns: 7, color: Colors.white),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 10,
          child: Opacity(
            opacity: 0.13,
            child: _DotMatrix(rows: 8, columns: 8, color: Colors.white),
          ),
        ),
        Positioned(
          top: 120,
          right: 40,
          child: Opacity(
            opacity: 0.18,
            child: _DotMatrix(rows: 6, columns: 6, color: Colors.white),
          ),
        ),
        // Círculo
        Positioned(
          top: 180,
          right: 60,
          child: Opacity(
            opacity: 0.22,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.cyanAccent, width: 4),
              ),
            ),
          ),
        ),
        // Semicírculo
        Positioned(
          left: -40,
          top: 300,
          child: Opacity(
            opacity: 0.13,
            child: Container(
              width: 120,
              height: 60,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(60),
                  topRight: Radius.circular(60),
                ),
                border: Border(
                  top: BorderSide(color: Colors.cyanAccent, width: 3),
                ),
              ),
            ),
          ),
        ),
        // Linhas diagonais
        Positioned(
          top: 80,
          left: 120,
          child: Transform.rotate(
            angle: 0.5,
            child: Container(
              width: 120,
              height: 2,
              color: Colors.cyanAccent.withOpacity(0.25),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          right: 80,
          child: Transform.rotate(
            angle: -0.4,
            child: Container(
              width: 90,
              height: 2,
              color: Colors.cyanAccent.withOpacity(0.18),
            ),
          ),
        ),
        // Conteúdo da tela
        if (child != null)
          Positioned.fill(child: child!),
      ],
    );
  }
}

class _DotMatrix extends StatelessWidget {
  final int rows;
  final int columns;
  final Color color;
  const _DotMatrix({required this.rows, required this.columns, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (i) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(columns, (j) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
        )),
      )),
    );
  }
} 