import 'package:flutter/foundation.dart';

/// Local authorization changes only. This carries no content or permission grant.
class ContentAccessChanges {
  static final revision = ValueNotifier<int>(0);
  static void changed() => revision.value++;
}
