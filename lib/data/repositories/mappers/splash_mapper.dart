import '../../../core/utils/url_ext.dart';
import '../../models/splash_item.dart';

/// Mapea un splash del API TRIVVO (`GET /app/splash`) al modelo [SplashItem].
/// Shape real: `{orden, imagen, link}` (`imagen` es una URL absoluta de S3).
SplashItem splashFromJson(Map<String, dynamic> j) => SplashItem(
  order: (j['orden'] as num?)?.toInt() ?? 0,
  imageUrl: absoluteUrlOrNull(j['imagen'] as String?),
  link: j['link'] as String?,
);
