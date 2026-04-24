import Config

config :relay_chat_realtime, RelayChatRealtimeWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  check_origin: [
    System.get_env("APP_ORIGIN") || "https://relaychat-two.vercel.app"
  ]

config :logger, level: :info
