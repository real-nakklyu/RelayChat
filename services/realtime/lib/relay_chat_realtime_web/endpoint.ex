defmodule RelayChatRealtimeWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :relay_chat_realtime

  socket "/socket", RelayChatRealtimeWeb.UserSocket,
    websocket: true,
    longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], pass: ["*/*"], json_decoder: Jason
  plug RelayChatRealtimeWeb.Router
end
