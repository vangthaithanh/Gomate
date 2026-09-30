import '../../../core/services/auth_service.dart';
import '../models/recommendation_models.dart';

class RecommendationRepository {
  final AuthService _auth;

  RecommendationRepository({AuthService? auth})
    : _auth = auth ?? AuthService.instance;

  Future<RecommendationResponse> getMine({
    int topK = 10,
    double? latitude,
    double? longitude,
  }) async {
    final query = <String, String>{
      'topK': topK.toString(),
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    };

    final uri = Uri(path: '/recommendations/me', queryParameters: query);
    final data = await _auth.request('GET', uri.toString());
    return RecommendationResponse.fromJson(data);
  }
}
