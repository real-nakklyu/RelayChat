import Config

config :relay_chat_realtime, RelayChatRealtimeWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  secret_key_base: String.duplicate("b", 64)

config :logger, level: :warning
