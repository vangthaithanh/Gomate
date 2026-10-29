String lastKnownLocationLabel(DateTime updatedAt, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(updatedAt);
  final String relative;
  if (age.inMinutes <= 0) {
    relative = 'Vừa cập nhật';
  } else if (age.inHours == 0) {
    relative = '${age.inMinutes} phút trước';
  } else if (age.inDays == 0) {
    relative = '${age.inHours} giờ trước';
  } else {
    relative = '${age.inDays} ngày trước';
  }
  return relative;
}
