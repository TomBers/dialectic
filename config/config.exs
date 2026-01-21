# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configure Hammer for rate limiting
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 2, cleanup_interval_ms: 60_000 * 10]}

config :dialectic, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [
    api_request: String.to_integer(System.get_env("OBAN_API_CONCURRENCY") || "10"),
    llm_request: String.to_integer(System.get_env("OBAN_LLM_CONCURRENCY") || "5"),
    db_write: String.to_integer(System.get_env("OBAN_DB_CONCURRENCY") || "5")
  ],
  repo: Dialectic.Repo,
  plugins: [
    {Oban.Plugins.Lifeline, rescue_after: 60}
  ]

config :dialectic,
  ecto_repos: [Dialectic.Repo],
  generators: [timestamp_type: :utc_datetime],
  env: config_env()

# Configures the endpoint
config :dialectic, DialecticWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DialecticWeb.ErrorHTML, json: DialecticWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Dialectic.PubSub,
  live_view: [signing_salt: "qRvt+kFw"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dialectic, Dialectic.Mailer, adapter: Swoosh.Adapters.Local

config :swoosh, :api_client, Swoosh.ApiClient.Finch
config :swoosh, :finch_name, Dialectic.Finch

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  dialectic: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  dialectic: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Ueberauth for OAuth
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, []}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
