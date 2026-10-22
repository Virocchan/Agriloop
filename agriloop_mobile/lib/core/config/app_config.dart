/// Compile-time switches for the demo.
///
/// The app runs fully offline by default. Supplying an n8n webhook at build
/// time transparently routes deposits through the real pipeline:
///
/// ```
/// flutter run -d chrome --dart-define=N8N_WEBHOOK_URL=https://n8n.example/webhook/deposit
/// ```
class AppConfig {
  const AppConfig._();

  /// n8n webhook that receives deposit events. Empty = local simulation.
  static const String n8nWebhookUrl =
      String.fromEnvironment('N8N_WEBHOOK_URL', defaultValue: '');

  /// Telegram bot that mirrors resident notifications. Empty = in-app only.
  static const String telegramBotToken =
      String.fromEnvironment('TELEGRAM_BOT_TOKEN', defaultValue: '');

  /// Chat id used for Telegram notifications. Empty = in-app only.
  static const String telegramChatId =
      String.fromEnvironment('TELEGRAM_CHAT_ID', defaultValue: '');

  // ---------------------------------------------------------------------
  // Supabase
  // ---------------------------------------------------------------------
  // The anon key is a *public* key by design — it ships inside every client
  // app and is protected by the row level security policies in
  // supabase/schema.sql. Point the build at another project with:
  //   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

  /// Supabase project URL. Empty = run fully offline against the local
  /// snapshot.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ohryccufcjbrsotwepwb.supabase.co',
  );

  /// Supabase anon (public) key.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ocnljY3VmY2picnNvdHdlcHdiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2NDY1MjcsImV4cCI6MjEwODIyMjUyN30.jYu2w7i8vNXxruYYfz3bNqd0vPnv5rZ5wjW3Lteu5LU',
  );

  /// Name of the Postgres function that scores a deposit server-side.
  static const String submitDepositRpc =
      String.fromEnvironment('SUPABASE_SUBMIT_RPC', defaultValue: 'rpc_submit_deposit');

  /// Seed the demo with two weeks of synthetic pilot history when running
  /// offline. Against a live database the history comes from Postgres.
  static const bool seedDemoHistory =
      bool.fromEnvironment('SEED_DEMO_HISTORY', defaultValue: true);

  static bool get hasRemoteBackend => n8nWebhookUrl.isNotEmpty;

  /// True when the app should talk to Supabase Postgres.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasTelegram =>
      telegramBotToken.isNotEmpty && telegramChatId.isNotEmpty;
}
