import Config

config :relay_chat_realtime, RelayChatRealtimeWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [json: RelayChatRealtimeWeb.ErrorJSON], layout: false],
  pubsub_server: RelayChatRealtime.PubSub,
  live_view: [signing_salt: "relaychat"]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

import_config "#{config_env()}.exs"
