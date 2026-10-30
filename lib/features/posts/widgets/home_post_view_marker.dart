import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef HomePostViewedCallback = Future<void> Function(int postId);

/// Fraction of the post's viewable vertical region currently inside Home.
///
/// For a post taller than the viewport, the viewport height is the largest
/// region that can ever be shown, so it becomes the denominator.
double homePostVisibleRatio(Rect post, Rect viewport) {
  if (!post.isFinite ||
      !viewport.isFinite ||
      post.height <= 0 ||
      viewport.height <= 0 ||
      !post.overlaps(viewport)) {
    return 0;
  }
  final visibleHeight = post
      .intersect(viewport)
      .height
      .clamp(0.0, math.min(post.height, viewport.height));
  return visibleHeight / math.min(post.height, viewport.height);
}

/// Records a Home view only after a card stays sufficiently visible.
///
/// A failed request is not acknowledged locally. It may be retried only after
/// the card leaves and enters the qualifying viewport region again.
class HomePostViewMarker extends StatefulWidget {
  final int postId;
  final ScrollController? scrollController;
  final bool active;
  final HomePostViewedCallback onViewed;
  final Widget child;
  final Duration dwellTime;
  final double minimumVisibleRatio;

  const HomePostViewMarker({
    super.key,
    required this.postId,
    required this.active,
    required this.onViewed,
    required this.child,
    this.scrollController,
    this.dwellTime = const Duration(seconds: 2),
    this.minimumVisibleRatio = .5,
  });

  @override
  State<HomePostViewMarker> createState() => _HomePostViewMarkerState();
}

class _HomePostViewMarkerState extends State<HomePostViewMarker> {
  Timer? _timer;
  bool _checkScheduled = false;
  bool _qualifying = false;
  bool _attemptedThisExposure = false;
  bool _sending = false;
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_scheduleCheck);
    _scheduleCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleCheck();
  }

  @override
  void didUpdateWidget(covariant HomePostViewMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_scheduleCheck);
      widget.scrollController?.addListener(_scheduleCheck);
    }
    if (oldWidget.postId != widget.postId) {
      _timer?.cancel();
      _qualifying = false;
      _attemptedThisExposure = false;
      _sending = false;
      _acknowledged = false;
    }
    if (!widget.active) _endExposure();
    _scheduleCheck();
  }

  bool _isQualifying() {
    if (!widget.active ||
        !TickerMode.of(context) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return false;
    }
    final postBox = context.findRenderObject();
    final viewportBox = Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    )?.context.findRenderObject();
    if (postBox is! RenderBox ||
        !postBox.attached ||
        !postBox.hasSize ||
        viewportBox is! RenderBox ||
        !viewportBox.attached ||
        !viewportBox.hasSize) {
      return false;
    }
    final postRect = postBox.localToGlobal(Offset.zero) & postBox.size;
    final viewportRect =
        viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    return homePostVisibleRatio(postRect, viewportRect) >=
        widget.minimumVisibleRatio;
  }

  void _endExposure() {
    _timer?.cancel();
    _timer = null;
    _qualifying = false;
    _attemptedThisExposure = false;
  }

  void _evaluate() {
    if (!_isQualifying()) {
      _endExposure();
      return;
    }
    if (_qualifying) return;
    _qualifying = true;
    if (_acknowledged || _sending || _attemptedThisExposure) return;
    _timer = Timer(widget.dwellTime, _dwellElapsed);
  }

  Future<void> _dwellElapsed() async {
    _timer = null;
    if (!mounted || !_isQualifying()) {
      _endExposure();
      return;
    }
    final postId = widget.postId;
    final callback = widget.onViewed;
    _attemptedThisExposure = true;
    _sending = true;
    try {
      await callback(postId);
      if (mounted && widget.postId == postId) _acknowledged = true;
    } catch (_) {
      // A failed request remains unacknowledged and can retry on re-entry.
    } finally {
      if (mounted && widget.postId == postId) _sending = false;
    }
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _evaluate();
    });
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_scheduleCheck);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
