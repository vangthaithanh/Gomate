import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_itinerary_picker.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';
import '../widgets/message_widgets.dart';

/// Màn "Thêm vào lịch trình" mới cho Message.
///
/// Dùng chung UI với Place Detail.
/// Không thay MessageRepository / backend.
class MessageAddToItineraryScreen extends StatelessWidget {
  final String conversationId;
  final MessageRepository repository;

  const MessageAddToItineraryScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  List<GoMateItineraryPickerItem> get _items {
    return repository.itineraries
        .map(
          (item) => GoMateItineraryPickerItem(
            id: item.id,
            title: item.title,
            dateRange: item.dateRange,
            summary: item.summary,
            imageAsset: item.imageAsset,
            memberCount: item.memberCount,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return GoMateItineraryPickerScreen(
      items: _items,
      onSelected: (item) => _select(context, item),
    );
  }

  Future<void> _select(
    BuildContext context,
    GoMateItineraryPickerItem item,
  ) async {
    final itinerary = _findItinerary(item.id);
    if (itinerary == null) return;

    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      child: MessageConfirmContent(
        title: 'Thêm vào lịch trình?',
        description:
            'Đoạn chat sẽ được thêm vào lịch trình "${itinerary.title}".',
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );

    if (!context.mounted || confirmed != true) return;

    repository.attachItinerary(
      conversationId: conversationId,
      itineraryId: itinerary.id,
    );

    GoMateSnackBar.show(
      context,
      message: 'Đã thêm vào lịch trình ${itinerary.title}',
      icon: LucideIcons.circle_check,
    );
  }

  MessageItinerary? _findItinerary(String id) {
    for (final item in repository.itineraries) {
      if (item.id == id) return item;
    }
    return null;
  }
}
