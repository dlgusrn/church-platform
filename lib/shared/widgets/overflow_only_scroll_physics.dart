import 'package:flutter/widgets.dart';

/// Disables drag and platform overscroll while a viewport has no scroll range.
class OverflowOnlyScrollPhysics extends ScrollPhysics {
  const OverflowOnlyScrollPhysics({super.parent});

  @override
  OverflowOnlyScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      OverflowOnlyScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      position.maxScrollExtent > position.minScrollExtent &&
      super.shouldAcceptUserOffset(position);
}
