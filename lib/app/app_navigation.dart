import 'package:flutter/foundation.dart';

/// The shell's current destination, shared so any screen can navigate (the dashboard is
/// the obvious example).
class AppNavigation extends ChangeNotifier {
  AppNavigation({String initial = 'dashboard'}) : _current = initial;

  String _current;

  /// Route id of the visible destination.
  String get current => _current;

  /// Navigates to [id]. Unknown ids are ignored rather than throwing — a stale deep link
  /// should not crash the app.
  void open(String id) {
    if (_current == id) return;
    _current = id;
    notifyListeners();
  }
}
