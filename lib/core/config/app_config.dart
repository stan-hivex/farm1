import 'env.dart';

/// Application configuration that uses environment variables.
/// This file maintains backward compatibility while delegating to [Env].
class AppConfig {
  static String get baseUrl => Env.apiBaseUrl;

  static String get apiVersion => Env.apiVersion;

  static String get api => Env.api;

  static String get supabaseUrl => Env.supabaseUrl;

  static String get supabaseAnonKey => Env.supabaseAnonKey;
}
