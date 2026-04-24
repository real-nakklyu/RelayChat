defmodule RelayChatRealtimeWeb.HealthController do
  use Phoenix.Controller, formats: [:json]

  def show(conn, _params) do
    json(conn, %{ok: true, service: "relaychat-realtime"})
  end
end
