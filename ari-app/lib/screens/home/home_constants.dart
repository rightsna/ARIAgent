import 'package:flutter/material.dart';

const double homeWindowRadius = 20;
const double homeWindowResizePadding = 6;

Color homeBackgroundColorForTheme(String theme) {
  switch (theme) {
    case 'gray':
      return const Color(0xFF3D3D3D);
    case 'blue':
      return const Color(0xFF123B78);
    case 'purple':
      return const Color(0xFF4A226E);
    case 'dark':
    default:
      return const Color(0xFF12122A);
  }
}
