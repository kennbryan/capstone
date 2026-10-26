/// Deployment environment, selected with `--dart-define=APP_ENV=...`.
enum Environment {
  dev,
  staging,
  prod;

  /// Parses [raw], falling back to [dev] for unknown values.
  static Environment parse(String raw) => Environment.values.firstWhere(
    (env) => env.name == raw,
    orElse: () => Environment.dev,
  );

  bool get isDev => this == Environment.dev;

  bool get isProd => this == Environment.prod;
}
