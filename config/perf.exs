import Config

config :dialectic, Dialectic.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dialectic_dev",
  pool_size: 10

config :dialectic, DialecticWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],
  url: [host: "localhost", port: 4001, scheme: "http"],
  cache_static_manifest: "priv/static/cache_manifest.json",
  code_reloader: false,
  debug_errors: false,
  server: true,
  check_origin: false,
  secret_key_base: "local-performance-testing-only-secret-key-base-1234567890abcdefghij"

config :dialectic, dev_routes: false
config :phoenix, :plug_init_mode, :compile

config :phoenix_live_view,
  debug_heex_annotations: false,
  enable_expensive_runtime_checks: false

config :logger, level: :warning
