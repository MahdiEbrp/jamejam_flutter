// Renders the app's icon from the app's own mark and palette, so the launcher tile and the
// dashboard cannot drift apart.
//
//   flutter test --no-pub --update-goldens tool/icon/render_icon_test.dart
//   tool/icon/install_icons.sh          # resize it into every platform's icon set
//
// The mark is `Icons.grid_view_rounded` — the same glyph the shell and the dashboard put beside
// "Welcome back" — in white on the theme's seed colour (`AppTheme.seed`, the teal the whole
// palette is derived from).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/app/app_theme.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('MaterialIcons');
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/home/user/.cache/flutter';
  loader.addFont(
    Future.value(
      ByteData.sublistView(
        File(
          '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytesSync(),
      ),
    ),
  );
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('the icon: the grid mark, white on the seed colour', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: ColoredBox(
            color: AppTheme.seed,
            child: Center(
              child: Icon(
                Icons.grid_view_rounded,
                size: 560,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('jamejam-icon-1024.png'),
    );
  });
}
