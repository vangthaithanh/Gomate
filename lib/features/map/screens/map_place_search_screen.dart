import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/map_place.dart';
import '../state/map_ui_session.dart';
import '../utils/cloudinary_image_url.dart';

class MapPlaceSearchScreen extends StatefulWidget {
  final List<GoMateMapPlace> initialPlaces;
  final Future<List<GoMateMapPlace>> Function(String query) onSearch;

  const MapPlaceSearchScreen({
    super.key,
    required this.initialPlaces,
    required this.onSearch,
  });

  @override
  State<MapPlaceSearchScreen> createState() => _MapPlaceSearchScreenState();
}

class _MapPlaceSearchScreenState extends State<MapPlaceSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  late List<GoMateMapPlace> _results;
  bool _loading = false;

  bool get _searching => _controller.text.trim().isNotEmpty;

  List<GoMateMapPlace> get _favorites {
    final byId = <String, GoMateMapPlace>{};
    for (final place in widget.initialPlaces) {
      if (place.isSaved) byId[place.placeId] = place;
    }
    for (final place in _results) {
      if (place.isSaved) byId[place.placeId] = place;
    }
    return byId.values.toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _results = widget.initialPlaces;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final result = await widget.onSearch(value.trim());
        if (!mounted) return;
        setState(() => _results = result);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
    setState(() {});
  }

  void _choose(GoMateMapPlace place) {
    GoMateMapUiSession.addRecent(place);
    Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.070).clamp(24.0, 30.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                width * 0.040,
                horizontal,
                width * 0.035,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: (width * 0.10).clamp(38.0, 44.0).toDouble(),
                      padding: EdgeInsets.symmetric(horizontal: width * 0.035),
                      decoration: BoxDecoration(
                        color: AppColors.grayBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: (width * 0.052).clamp(18.0, 22.0).toDouble(),
                            color: AppColors.grayText,
                          ),
                          SizedBox(width: width * 0.018),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              onChanged: _onChanged,
                              cursorColor: AppColors.primaryIcon,
                              decoration: const InputDecoration(
                                hintText: 'Tìm kiếm ....',
                                hintStyle: TextStyle(
                                  color: AppColors.grayText,
                                  fontWeight: FontWeight.w500,
                                ),
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: width * 0.030),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: width * 0.020),
                      child: Text(
                        'Huỷ',
                        style: TextStyle(
                          fontSize:
                              (width * 0.033).clamp(12.0, 14.0).toDouble(),
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primaryIcon,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  width * 0.015,
                  horizontal,
                  width * 0.060,
                ),
                children: [
                  if (!_searching) ...[
                    _SectionTitle(title: 'Gần đây', width: width),
                    SizedBox(height: width * 0.018),
                    if (GoMateMapUiSession.recentPlaces.isEmpty)
                      _EmptyLine(
                        text: 'Chưa có địa điểm đã xem gần đây',
                        width: width,
                      )
                    else
                      ...GoMateMapUiSession.recentPlaces.take(5).map(
                        (place) => _PlaceRow(
                          place: place,
                          width: width,
                          onTap: () => _choose(place),
                        ),
                      ),
                    SizedBox(height: width * 0.050),
                  ] else ...[
                    ..._results.map(
                      (place) => _PlaceRow(
                        place: place,
                        width: width,
                        onTap: () => _choose(place),
                      ),
                    ),
                    SizedBox(height: width * 0.025),
                  ],
                  if (_favorites.isNotEmpty) ...[
                    _SectionTitle(title: 'Yêu thích', width: width),
                    SizedBox(height: width * 0.018),
                    ..._favorites.map(
                      (place) => _PlaceRow(
                        place: place,
                        width: width,
                        onTap: () => _choose(place),
                      ),
                    ),
                  ],
                  if (_searching && _results.isEmpty && !_loading)
                    _EmptyLine(
                      text: 'Không tìm thấy địa điểm phù hợp',
                      width: width,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final double width;

  const _SectionTitle({required this.title, required this.width});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: (width * 0.034).clamp(12.0, 14.0).toDouble(),
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;
  final double width;

  const _EmptyLine({required this.text, required this.width});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: width * 0.030),
      child: Text(
        text,
        style: TextStyle(
          fontSize: (width * 0.030).clamp(11.0, 12.5).toDouble(),
          color: AppColors.grayText,
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final GoMateMapPlace place;
  final double width;
  final VoidCallback onTap;

  const _PlaceRow({
    required this.place,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageSize = (width * 0.13).clamp(46.0, 54.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: width * 0.020),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: _PlaceImage(place: place),
                ),
              ),
              SizedBox(width: width * 0.032),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            (width * 0.033).clamp(12.0, 14.0).toDouble(),
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: width * 0.006),
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            (width * 0.029).clamp(10.5, 12.0).toDouble(),
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: width * 0.025),
              Text(
                'Chi tiết',
                style: TextStyle(
                  fontSize: (width * 0.030).clamp(11.0, 12.5).toDouble(),
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  final GoMateMapPlace place;

  const _PlaceImage({required this.place});

  @override
  Widget build(BuildContext context) {
    final raw = place.thumbnailUrl ??
        (place.mediaUrls.isEmpty ? null : place.mediaUrls.first);

    if (raw == null) {
      return ColoredBox(
        color: AppColors.blue50,
        child: Center(
          child: Icon(
            LucideIcons.map_pin,
            color: AppColors.primaryIcon,
          ),
        ),
      );
    }

    return Image.network(
      cloudinaryMapThumbnailUrl(raw),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: AppColors.blue50,
        child: Center(
          child: Icon(
            LucideIcons.map_pin,
            color: AppColors.primaryIcon,
          ),
        ),
      ),
    );
  }
}
