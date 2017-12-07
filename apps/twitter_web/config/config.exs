# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :twitter_web, TwitterWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "MeAkU/FXVvfHV2Mpv23Npv0TQFqs0pA1BM8aH7qUqGmXwBbeD1/25epUQdgCu341",
  render_errors: [view: TwitterWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: TwitterWeb.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
