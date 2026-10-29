import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../models/post_compose_models.dart';

/// Selects/previews the range; PostVideoExporter produces the actual upload file.
class GoMatePostVideoTrimScreen extends StatefulWidget {
  final File video;
  final Duration estimatedDuration;

  const GoMatePostVideoTrimScreen({
    super.key,
    required this.video,
    required this.estimatedDuration,
  });

  @override
  State<GoMatePostVideoTrimScreen> createState() =>
      _GoMatePostVideoTrimScreenState();
}

class _GoMatePostVideoTrimScreenState extends State<GoMatePostVideoTrimScreen> {
  late final VideoPlayerController _controller;
  late Future<void> _initialization;
  RangeValues _range = const RangeValues(0, 30);
  double _totalSeconds = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.video);
    _controller.addListener(_watchPosition);
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      final actual = _controller.value.duration.inMilliseconds / 1000;
      final estimated = widget.estimatedDuration.inMilliseconds / 1000;
      final seconds = actual > 0 ? actual : estimated;
      setState(() {
        _totalSeconds = seconds.clamp(1.0, double.infinity).toDouble();
        _range = RangeValues(0, _totalSeconds.clamp(1.0, 30.0).toDouble());
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể mở video này để xem trước.');
      }
    }
  }

  void _watchPosition() {
    if (!_controller.value.isInitialized || !_controller.value.isPlaying)
      return;
    if (_controller.value.position.inMilliseconds / 1000 >= _range.end) {
      _controller.pause();
      _controller.seekTo(Duration(milliseconds: (_range.start * 1000).round()));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_watchPosition);
    _controller.dispose();
    super.dispose();
  }

  void _changeRange(RangeValues values) {
    var start = values.start;
    var end = values.end;
    if (end - start > 30) {
      if ((start - _range.start).abs() > (end - _range.end).abs()) {
        end = (start + 30).clamp(0.0, _totalSeconds).toDouble();
      } else {
        start = (end - 30).clamp(0.0, _totalSeconds).toDouble();
      }
    }
    if (end - start < 1) {
      end = (start + 1).clamp(0.0, _totalSeconds).toDouble();
      if (end - start < 1)
        start = (end - 1).clamp(0.0, _totalSeconds).toDouble();
    }
    setState(() => _range = RangeValues(start, end));
    _controller.pause();
    _controller.seekTo(Duration(milliseconds: (start * 1000).round()));
  }

  String _time(double value) {
    final total = value.round();
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _finish() {
    final start = (_range.start * 1000).round();
    final end = (_range.end * 1000).round();
    if (end <= start || end - start > 30000) return;
    Navigator.of(context).pop(GoMatePostTrimRange(startMs: start, endMs: end));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * 0.055).clamp(18.0, 24.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 50,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.chevron_left, size: 22),
                  ),
                  const Expanded(
                    child: Text(
                      'Cắt video',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<void>(
                future: _initialization,
                builder: (context, snapshot) {
                  if (_error != null) {
                    return Center(
                      child: Text(_error!, textAlign: TextAlign.center),
                    );
                  }
                  if (!_controller.value.isInitialized) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryIcon,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () async {
                              if (_controller.value.isPlaying) {
                                await _controller.pause();
                              } else {
                                await _controller.seekTo(
                                  Duration(
                                    milliseconds: (_range.start * 1000).round(),
                                  ),
                                );
                                await _controller.play();
                              }
                              if (mounted) setState(() {});
                            },
                            child: AspectRatio(
                              aspectRatio: _controller.value.aspectRatio <= 0
                                  ? 1
                                  : _controller.value.aspectRatio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  VideoPlayer(_controller),
                                  if (!_controller.value.isPlaying)
                                    const Center(
                                      child: Icon(
                                        LucideIcons.play,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(gap, 18, gap, 8),
                        child: Column(
                          children: [
                            Text(
                              'Chọn đoạn video tối đa 30 giây',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_time(_range.start)} – ${_time(_range.end)}  ·  '
                              '${(_range.end - _range.start).round()} giây',
                              style: const TextStyle(color: AppColors.grayText),
                            ),
                            RangeSlider(
                              activeColor: AppColors.primaryIcon,
                              values: _range,
                              min: 0,
                              max: _totalSeconds,
                              labels: RangeLabels(
                                _time(_range.start),
                                _time(_range.end),
                              ),
                              onChanged: _changeRange,
                            ),
                            Text(
                              'Vuốt hai đầu thanh để chọn đoạn phát. '
                              'Video được cắt thành tệp khi tích hợp xử lý media.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.grayText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                gap,
                8,
                gap,
                14 + MediaQuery.paddingOf(context).bottom,
              ),
              child: InkWell(
                onTap: _error == null && _controller.value.isInitialized
                    ? _finish
                    : null,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Sử dụng đoạn này',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
