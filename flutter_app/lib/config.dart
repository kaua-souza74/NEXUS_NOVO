/// Public client configuration for the NEXUS Flutter app.
///
/// These defaults let `flutter run` work from a fresh clone. Supabase
/// publishable keys are intended for client apps; access still depends on Auth
/// and the project's Row Level Security policies. Never put a Supabase secret
/// or service-role key here.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  final String url;
  final String publishableKey;

  bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

const supabaseConfig = SupabaseConfig(
  url: String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tcqddqyrnhlcnbldurqy.supabase.co',
  ),
  publishableKey: String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_PIoVGOtrxDaMvYZVaDiGzg_jqZEtUQM',
  ),
);
