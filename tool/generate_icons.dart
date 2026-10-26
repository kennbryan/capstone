// Renders the placeholder MSU mark to PNGs for the launcher icon and the
// launch splash. Run with:
//
//   flutter test tool/generate_icons.dart
//   dart run flutter_launcher_icons
//
// TODO(DKMSU): once the official logo exists, point flutter_launcher_icons
// at it instead and delete this generator.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/theme/app_colors.dart';
import 'package:msu_wellbeing/core/widgets/msu_logo.dart';

const _size = 1024.0;
const _white = Color(0xFFFFFFFF);

Future<void> _render(WidgetTester tester, Widget child, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox.square(dimension: _size, child: child),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('generate launcher icon and splash images', (tester) async {
    tester.view
      ..physicalSize = const Size(_size, _size)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final font = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'));
    await tester.runAsync(font.load);

    final brand = [AppPalette.light.brandStart, AppPalette.light.brandEnd];

    // Legacy / iOS icon: full-bleed brand gradient with the mark.
    await _render(
      tester,
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: brand,
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(_size * 0.14),
          child: MsuLogoMark(color: _white),
        ),
      ),
      'assets/icon/icon.png',
    );

    // Adaptive icon foreground: mark inside the 66% safe zone.
    await _render(
      tester,
      const Padding(
        padding: EdgeInsets.all(_size * 0.25),
        child: MsuLogoMark(color: _white),
      ),
      'assets/icon/foreground.png',
    );

    // Launch splash: mark without text (the app splash shows the name).
    await _render(
      tester,
      const Padding(
        padding: EdgeInsets.all(_size * 0.2),
        child: MsuLogoMark(color: _white, showText: false),
      ),
      'assets/icon/splash.png',
    );
  });
}
