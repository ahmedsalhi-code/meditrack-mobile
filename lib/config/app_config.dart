enum AppEnvironment {
  development,
  staging,
  production,
}

class AppConfig {
  static const String _environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static const String defaultTimezone = String.fromEnvironment(
    'APP_TIMEZONE',
    defaultValue: 'Africa/Tunis',
  );

  static const String _productionApiBaseUrl =
      'https://meditrack-backend-production-1b17.up.railway.app';

  static const String _stagingApiBaseUrl =
      'https://meditrack-backend-staging.up.railway.app';

  static const String _developmentApiBaseUrl = 'http://10.0.2.2:3000';

  static AppEnvironment get environment {
    switch (_environmentName.toLowerCase()) {
      case 'dev':
      case 'development':
        return AppEnvironment.development;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
      default:
        return AppEnvironment.production;
    }
  }

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.trim().isNotEmpty) {
      return _withoutTrailingSlash(_apiBaseUrlOverride);
    }

    switch (environment) {
      case AppEnvironment.development:
        return _developmentApiBaseUrl;
      case AppEnvironment.staging:
        return _stagingApiBaseUrl;
      case AppEnvironment.production:
        return _productionApiBaseUrl;
    }
  }

  static bool get isProduction => environment == AppEnvironment.production;

  static String _withoutTrailingSlash(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
