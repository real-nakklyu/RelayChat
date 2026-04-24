defmodule RelayChatRealtimeWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RelayChatRealtimeWeb do
    pipe_through :api
    get "/health", HealthController, :show
  end
end
