import Config

if config_env() == :prod do
  port = String.to_integer(System.get_env("PORT") || "4000")
  host = System.get_env("PHX_HOST") || "localhost"
  secret_key_base = System.fetch_env!("SECRET_KEY_BASE")

  config :relay_chat_realtime, RelayChatRealtimeWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    check_origin: [
      System.get_env("APP_ORIGIN") || "https://relaychat.example.com"
    ],
    server: true
end

config :relay_chat_realtime,
  supabase_url: System.fetch_env!("NEXT_PUBLIC_SUPABASE_URL"),
  supabase_publishable_key: System.get_env("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY") || System.get_env("NEXT_PUBLIC_SUPABASE_ANON_KEY"),
  supabase_jwt_secret: System.fetch_env!("SUPABASE_JWT_SECRET")
