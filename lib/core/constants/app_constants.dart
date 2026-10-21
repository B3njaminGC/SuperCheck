abstract final class AppConstants {
  static const appName = 'SuperCheck';

  // --- Open Food Facts -------------------------------------------------
  static const offHost = 'world.openfoodfacts.org';

  /// Open Food Facts pide identificar a la app en el User-Agent.
  /// Reemplazá el contacto por un mail real tuyo antes de publicar.
  static const offUserAgent = 'SuperCheck/0.1.0 (contacto: TU_EMAIL_AQUI)';

  /// Etiqueta de país para priorizar productos vendidos en Argentina.
  /// Poné `null` para buscar en todo el mundo.
  static const offDefaultCountryTag = 'argentina';

  /// Campos que pedimos a la API (evita descargar el JSON completo del producto).
  static const offFields = 'code,product_name,product_name_es,generic_name,'
      'brands,quantity,product_quantity,product_quantity_unit,'
      'image_front_small_url,image_front_url,image_small_url,image_url';

  static const httpTimeout = Duration(seconds: 12);
}
