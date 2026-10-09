import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_navigation.dart';
import 'app/app_services.dart';

/// Entry point: build the service graph once, then hand it to the widget tree.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final services = await AppServices.bootstrap();

  runApp(
    MultiProvider(
      providers: [
        ...services.providers(),
        ChangeNotifierProvider<AppNavigation>(create: (_) => AppNavigation()),
      ],
      child: const JameJamApp(),
    ),
  );
}
