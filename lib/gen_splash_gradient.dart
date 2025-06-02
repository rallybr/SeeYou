import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';

void main() async {
  const width = 1080;
  const height = 1920;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final paint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, 0),
      Offset(width.toDouble(), height.toDouble()),
      [
        Color(0xFF2D2EFF),
        Color(0xFF7B2FF2),
        Color(0xFFE94057),
      ],
      [0.0, 0.5, 1.0],
    );
  canvas.drawRect(rect, paint);

  final picture = recorder.endRecording();
  final img = await picture.toImage(width, height);
  final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final file = File('assets/images/splash_gradient.png');
  await file.create(recursive: true);
  await file.writeAsBytes(pngBytes!.buffer.asUint8List());
  print('Imagem do gradiente salva em assets/images/splash_gradient.png');
} 