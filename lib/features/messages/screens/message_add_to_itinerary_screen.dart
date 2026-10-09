import 'package:flutter/material.dart';

import '../../../core/widgets/gomate_itinerary_picker.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';

/// Chỉ làm nhiệm vụ tìm/chọn lịch trình.
///
/// Không xác nhận lời mời ở màn này.
/// Sau khi chọn, màn được pop và trả [MessageItinerary] về MessageDetailScreen.
/// Bottom sheet xác nhận sẽ mở trên chính trang detail để đúng flow thiết kế.
class MessageAddToItineraryScreen extends StatelessWidget {
  final MessageRepository repository;

  const MessageAddToItineraryScreen({
    super.key,
    required this.repository,
  });

  List<GoMateItineraryPickerItem> get _items {
    return repository.inviteableItineraries
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
      showCancel: true,
      searchHint: 'Tìm lịch trình ....',
      onCancel: () => Navigator.of(context).pop(),
      onQuickCreate: () {
        // TODO: đổi sang route tạo lịch trình thật của bạn
        // Ví dụ:
        // Navigator.of(context).pushNamed(AppRoutes.createItinerary);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đi tới tạo lịch trình mới')),
        );
      },
      onSelected: (item) {
        final itinerary = _findItinerary(item.id);
        if (itinerary == null) return;

        Navigator.of(context).pop<MessageItinerary>(itinerary);
      },
    );
  }

  MessageItinerary? _findItinerary(String id) {
    for (final item in repository.inviteableItineraries) {
      if (item.id == id) return item;
    }

    return null;
  }
}
