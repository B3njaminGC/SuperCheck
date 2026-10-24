abstract final class AppConstants {
  static const appName = 'SuperCheck';

  // --- Open Food Facts -------------------------------------------------
  static const offHost = 'world.openfoodfacts.org';

  /// Buscador de texto moderno de Open Food Facts (Search-a-licious). Aguanta mucho
  /// más tráfico que `/cgi/search.pl`, que limita a 10 búsquedas por minuto por IP.
  static const offSearchHost = 'search.openfoodfacts.org';

  /// Open Food Facts pide identificar a la app en el User-Agent.
  static const offUserAgent =
      'SuperCheck/0.1.0 (https://github.com/B3njaminGC/SuperCheck)';

  /// Etiqueta de país para priorizar productos vendidos en Argentina.
  /// Poné `null` para buscar en todo el mundo.
  static const offDefaultCountryTag = 'argentina';

  /// Campos que pedimos a la API (evita descargar el JSON completo del producto).
  static const offFields = 'code,product_name,product_name_es,generic_name,'
      'brands,quantity,product_quantity,product_quantity_unit,'
      'image_front_small_url,image_front_url,image_small_url,image_url';

  static const httpTimeout = Duration(seconds: 12);
}
