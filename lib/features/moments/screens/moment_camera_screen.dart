import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../data/moments_repository.dart';
import '../models/moment_models.dart';
import '../widgets/moment_image_frame.dart';
import 'moment_viewer_screen.dart';
import 'my_moments_screen.dart';

/// Màn "Ảnh khoảnh khắc".
///
/// Lưu ý UI:
/// - Không dùng artboard/frame 375x715 cố định.
/// - Không scale cả màn theo một hệ số chung.
/// - Mọi kích thước chính lấy từ constraints thực tế của màn hình.
/// - Thumbnail có badge ở góc phải là KHOẢNH KHẮC CHƯA XEM CỦA BẠN BÈ.
class MomentCameraScreen extends StatefulWidget {
  final MomentsRepository repository;
  final Widget Function(bool enabled)? modeSelectorBuilder;

  const MomentCameraScreen({
    super.key,
    required this.repository,
    this.modeSelectorBuilder,
  });

  @override
  State<MomentCameraScreen> createState() => _MomentCameraScreenState();
}

class _MomentCameraScreenState extends State<MomentCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _selectedCamera;
  bool _cameraLoading = true;
  bool _uploading = false;
  bool _flashOn = false;
  String? _cameraError;
  int _cameraRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraRequest++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraRequest++;
      _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(camera: _selectedCamera);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: widget.modeSelectorBuilder?.call(!_uploading),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            double c(double value, double min, double max) {
              return value.clamp(min, max).toDouble();
            }

            final horizontalPadding = c(width * 0.053, 16, 22);
            final headerHeight = c(width * 0.155, 54, 66);
            final iconSize = c(width * 0.064, 22, 25);
            final titleSize = c(width * 0.043, 15, 17);

            // Ảnh chính ưu tiên gần 80% chiều rộng như mockup, nhưng nếu màn
            // thấp thì tự thu theo chiều cao để không overflow.
            final availableBodyHeight = math.max(0.0, height - headerHeight);
            final shutterOuter = c(width * 0.213, 72, 84);
            final reservedHeight =
                c(width * 0.20, 68, 80) +
                c(width * 0.16, 52, 64) +
                shutterOuter +
                c(height * 0.018, 10, 16) +
                c(height * 0.045, 18, 34);
            final previewSize = math.min(
              math.min(width * 0.80, availableBodyHeight * 0.60),
              math.max(0.0, availableBodyHeight - reservedHeight),
            );

            final shutterInner = shutterOuter * 0.72;
            final controlIcon = c(width * 0.064, 22, 26);

            return AnimatedBuilder(
              animation: widget.repository,
              builder: (context, _) {
                final unseen = widget.repository.availableFriendMoments;

                return Column(
                  children: [
                    SizedBox(
                      height: headerHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: horizontalPadding),
                              child: _CircleIconButton(
                                icon: LucideIcons.x,
                                iconSize: iconSize,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                          Text(
                            'Ảnh khoảnh khắc',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: titleSize,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: horizontalPadding,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _CircleIconButton(
                                    icon: LucideIcons.layout_grid,
                                    iconSize: iconSize,
                                    onTap: () => _openLibrary(context),
                                  ),
                                  SizedBox(width: c(width * 0.012, 4, 6)),
                                  if (unseen.isNotEmpty)
                                    _UnseenFriendsPreview(
                                      items: unseen,
                                      size: c(width * 0.115, 40, 48),
                                      onTap: () => _openUnseenFriends(
                                        context,
                                        unseen.first,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Column(
                          children: [
                            // Giữ preview gần header như mockup; không để chiều cao
                            // màn hình quyết định khoảng trống phía trên.
                            SizedBox(height: c(width * 0.20, 68, 80)),
                            Center(
                              child: _CameraFrame(
                                size: previewSize,
                                controller: _controller,
                                loading: _cameraLoading,
                                uploading: _uploading,
                                error: _cameraError,
                              ),
                            ),
                            SizedBox(height: c(width * 0.16, 52, 64)),
                            SizedBox(
                              width: math.min(width * 0.74, 360),
                              height: shutterOuter,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _CircleIconButton(
                                    icon: _flashOn
                                        ? LucideIcons.zap
                                        : LucideIcons.zap_off,
                                    iconSize: controlIcon,
                                    onTap: _controlsLocked
                                        ? null
                                        : _toggleFlash,
                                  ),
                                  InkWell(
                                    onTap: _controlsLocked
                                        ? null
                                        : _captureAndUpload,
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: shutterOuter,
                                      height: shutterOuter,
                                      padding: EdgeInsets.all(
                                        c(width * 0.011, 4, 5),
                                      ),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppColors.primaryGradient,
                                      ),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                        alignment: Alignment.center,
                                        child: Container(
                                          width: shutterInner,
                                          height: shutterInner,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0x4DDADADA),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _CircleIconButton(
                                    icon: LucideIcons.refresh_cw,
                                    iconSize: controlIcon,
                                    onTap: _controlsLocked
                                        ? null
                                        : _switchCamera,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            SizedBox(height: c(height * 0.018, 10, 16)),
                            SizedBox(height: c(height * 0.045, 18, 34)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool get _controlsLocked {
    final controller = _controller;
    return _cameraLoading ||
        _uploading ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture;
  }

  Future<void> _initializeCamera({CameraDescription? camera}) async {
    final request = ++_cameraRequest;
    setState(() {
      _cameraLoading = true;
      _cameraError = null;
    });
    try {
      final cameras = _cameras.isEmpty ? await availableCameras() : _cameras;
      if (!mounted || request != _cameraRequest) return;
      if (cameras.isEmpty) {
        throw CameraException('NO_CAMERA', 'Không tìm thấy camera.');
      }
      _cameras = cameras;
      final selected = camera ?? _preferredCamera(cameras);
      final oldController = _controller;
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _selectedCamera = selected;
      _controller = controller;
      await oldController?.dispose();
      if (!mounted || request != _cameraRequest) {
        await controller.dispose();
        return;
      }
      await controller.initialize();
      if (!mounted || request != _cameraRequest) return;
      await controller.setFlashMode(FlashMode.off);
      if (!mounted || request != _cameraRequest) return;
      setState(() {
        _flashOn = false;
        _cameraLoading = false;
      });
    } on CameraException catch (error) {
      if (!mounted || request != _cameraRequest) return;
      setState(() {
        _cameraError = _cameraErrorMessage(error);
        _cameraLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _cameraRequest) return;
      setState(() {
        _cameraError = 'Không mở được camera.';
        _cameraLoading = false;
      });
    }
  }

  CameraDescription _preferredCamera(List<CameraDescription> cameras) {
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) return camera;
    }
    return cameras.first;
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _flashOn = next);
      HapticFeedback.selectionClick();
    } on CameraException {
      _showSnack('Camera hiện tại không hỗ trợ flash.');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      _showSnack('Thiết bị chỉ có một camera.');
      return;
    }
    final current = _selectedCamera;
    final target = _cameras.firstWhere(
      (camera) =>
          current == null ||
          camera.name != current.name &&
              camera.lensDirection != current.lensDirection,
      orElse: () => _cameras.firstWhere(
        (camera) => current == null || camera.name != current.name,
      ),
    );
    HapticFeedback.selectionClick();
    await _initializeCamera(camera: target);
  }

  Future<void> _captureAndUpload() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      HapticFeedback.mediumImpact();
      setState(() => _uploading = true);
      final image = await controller.takePicture();
      await widget.repository.createFromImagePath(imagePath: image.path);
      if (!mounted) return;
      _showSnack('Đã đăng ảnh khoảnh khắc');
    } on CameraException catch (error) {
      if (!mounted) return;
      _showSnack(_cameraErrorMessage(error));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không đăng được khoảnh khắc. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _cameraErrorMessage(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' =>
        'Bạn cần cấp quyền camera để chụp khoảnh khắc.',
      'AudioAccessDenied' => 'Bạn cần cấp quyền camera để chụp khoảnh khắc.',
      'NO_CAMERA' => 'Không tìm thấy camera trên thiết bị.',
      _ => 'Không mở được camera.',
    };
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLibrary(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyMomentsScreen(repository: widget.repository),
      ),
    );
  }

  Future<void> _openUnseenFriends(
    BuildContext context,
    MomentItem first,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentViewerScreen(
          repository: widget.repository,
          startUserId: first.ownerId,
        ),
      ),
    );
  }
}

class _CameraFrame extends StatelessWidget {
  final double size;
  final CameraController? controller;
  final bool loading;
  final bool uploading;
  final String? error;

  const _CameraFrame({
    required this.size,
    required this.controller,
    required this.loading,
    required this.uploading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    final cameraReady =
        activeController != null && activeController.value.isInitialized;
    final child = Stack(
      fit: StackFit.expand,
      children: [
        if (cameraReady)
          _LiveCameraPreview(controller: activeController)
        else
          _CameraFallback(error: error),
        if (loading || uploading)
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.18),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );

    return MomentImageFrame(size: size, showShadow: true, child: child);
  }
}

class _LiveCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _LiveCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final previewWidth = isPortrait ? previewSize.height : previewSize.width;
    final previewHeight = isPortrait ? previewSize.width : previewSize.height;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  final String? error;

  const _CameraFallback({required this.error});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x4DDADADA),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.camera_off,
                color: AppColors.grayText,
                size: 30,
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.grayText,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: iconSize + 18,
        height: iconSize + 18,
        child: Center(
          child: Icon(icon, size: iconSize, color: AppColors.black),
        ),
      ),
    );
  }
}

class _UnseenFriendsPreview extends StatelessWidget {
  final List<MomentItem> items;
  final double size;
  final VoidCallback onTap;

  const _UnseenFriendsPreview({
    required this.items,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final thumbSize = size * 0.64;
    final radius = size * 0.20;

    Widget thumb(String asset) {
      return Container(
        width: thumbSize,
        height: thumbSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: _SourceImage(source: asset, iconSize: thumbSize * 0.45),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (count > 1)
              Positioned(
                right: 0,
                top: size * 0.11,
                child: Transform.rotate(
                  angle: -0.07,
                  child: thumb(items[1].imageAsset),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              child: Transform.rotate(
                angle: -0.035,
                child: thumb(items.first.imageAsset),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  color: AppColors.primaryIcon,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.18,
                    height: 1,
                    fontWeight: FontWeight.w800,
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

class _SourceImage extends StatelessWidget {
  final String source;
  final double iconSize;

  const _SourceImage({required this.source, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    Widget fallback() {
      return Container(
        color: AppColors.blue50,
        alignment: Alignment.center,
        child: Icon(
          LucideIcons.image,
          size: iconSize,
          color: AppColors.grayText,
        ),
      );
    }

    final value = source.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    }
    if (value.contains(':\\') || value.startsWith('/')) {
      return Image.file(
        File(value),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    }
    if (value.isEmpty) return fallback();
    return Image.asset(
      value,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );
  }
}
