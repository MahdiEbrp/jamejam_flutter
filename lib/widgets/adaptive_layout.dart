import 'package:flutter/material.dart';

/// Lays a screen out as *chrome* (headers, toolbars) above a *body* region.
///
/// On a roomy viewport this is exactly the column every feature screen has always been: the
/// chrome at its natural height, the body filling the rest through `Expanded`. On a compact
/// viewport — a phone, or any window at a large text scale — that same column can ask for more
/// height than it is given and overflow, clipping the page past the last pixel of the window.
///
/// Here the compact case turns the page into one scrolling column and gives the body a bounded
/// slice of the viewport, so the chrome scrolls away and nothing is unreachable. The .NET
/// reference never had the problem (a console window scrolls for free); this is the Flutter
/// counterpart of that affordance.
///
/// `test/app/accessibility_test.dart` sweeps every route at 400 x 800 px with text scales 1.0,
/// 1.3 and 1.6 and fails on any `RenderFlex` overflow, which is what keeps this honest.
class AdaptivePageBody extends StatelessWidget {
  /// Creates the layout from the widgets that sit above the body.
  const AdaptivePageBody({
    required this.chrome,
    required this.body,
    this.bodyFraction = 0.62,
    this.bodyMinHeight = 260,
    this.bodyMaxHeight = 760,
    this.compactWidth = 620,
    this.compactTextScale = 1.15,
    super.key,
  });

  /// Header, toolbar and banner widgets, stacked in order above the body.
  final List<Widget> chrome;

  /// The scrolling region the screen exists for.
  final Widget body;

  /// Share of the viewport the body keeps once the page starts scrolling.
  final double bodyFraction;

  /// Lower bound for that slice, so the body stays usable on a short window.
  final double bodyMinHeight;

  /// Upper bound for that slice, so a tall window does not stretch it pointlessly.
  final double bodyMaxHeight;

  /// Width below which the page is treated as compact.
  final double compactWidth;

  /// Text scale above which the page is treated as compact, whatever the width.
  final double compactTextScale;

  @override
  Widget build(BuildContext context) {
    // `TextScaler` is the modern spelling of the accessibility text setting; scaling a
    // reference size keeps this comparable to the `compactTextScale` constant.
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < compactWidth || scale > compactTextScale;
        if (!compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...chrome,
              Expanded(child: body),
            ],
          );
        }
        final height = (constraints.maxHeight * bodyFraction).clamp(
          bodyMinHeight,
          bodyMaxHeight,
        );
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...chrome,
              SizedBox(height: height, child: body),
            ],
          ),
        );
      },
    );
  }
}

/// A text field followed by the controls that act on it, reflowing when the row is too wide.
///
/// The reference CLI never had this problem — one command per line. In a window the same
/// "field plus actions" row overflows as soon as a phone-sized viewport meets a long
/// localized button label, so the actions wrap onto extra lines instead of clipping. The
/// field keeps a comfortable minimum and never grows past [fieldMaxWidth].
class FieldActionFlow extends StatelessWidget {
  /// Creates the flow from the field and the actions that follow it.
  const FieldActionFlow({
    required this.field,
    required this.actions,
    this.fieldMinWidth = 200,
    this.fieldMaxWidth = 420,
    this.spacing = 8,
    super.key,
  });

  /// The input being edited.
  final Widget field;

  /// Buttons, pickers and chips that belong beside the field.
  final List<Widget> actions;

  /// Smallest sensible width for the field; clamped by the parent when there is less room.
  final double fieldMinWidth;

  /// Largest width the field is allowed to grow to.
  final double fieldMaxWidth;

  /// Gap between items, in both directions.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: fieldMinWidth,
            maxWidth: fieldMaxWidth,
          ),
          child: field,
        ),
        ...actions,
      ],
    );
  }
}
