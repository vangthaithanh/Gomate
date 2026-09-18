import 'package:flutter/material.dart';

import '../models/map_place.dart';
import '../models/map_route.dart';
import '../theme/map_ui_tokens.dart';

class GoMateDirectionsRouteSheet extends StatelessWidget {
  final GoMateMapRoute route;
  final GoMateMapPlace destination;
  final String originLabel;
  final bool originIsCurrentLocation;
  final bool choosingOrigin;
  final VoidCallback onChooseOrigin;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onClose;

  const GoMateDirectionsRouteSheet({
    super.key,
    required this.route,
    required this.destination,
    required this.originLabel,
    required this.originIsCurrentLocation,
    required this.choosingOrigin,
    required this.onChooseOrigin,
    required this.onUseCurrentLocation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: GoMateMapUi.floatingPanel(context),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(.8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.directions_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${route.distanceKm.toStringAsFixed(1)} km • ~${route.durationMinutes} phút',
                      style: GoMateMapUi.title(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chỉ đường đến ${destination.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoMateMapUi.caption(context),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LocationRow(
            icon: originIsCurrentLocation
                ? Icons.my_location_rounded
                : Icons.trip_origin_rounded,
            title: 'Điểm bắt đầu',
            value: originLabel,
          ),
          const SizedBox(height: 7),
          _LocationRow(
            icon: Icons.location_on_rounded,
            title: 'Điểm đến',
            value: destination.name,
          ),
          if (choosingOrigin) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(.75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Chạm lên bản đồ để chọn điểm bắt đầu mới.',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChooseOrigin,
                  icon: const Icon(
                    Icons.edit_location_alt_rounded,
                    size: 18,
                  ),
                  label: const Text('Đổi điểm đầu'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      originIsCurrentLocation ? null : onUseCurrentLocation,
                  icon: const Icon(
                    Icons.my_location_rounded,
                    size: 18,
                  ),
                  label: const Text('Vị trí của tôi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _LocationRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
