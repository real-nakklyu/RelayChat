defmodule RelayChatRealtimeWeb.UserSocket do
  use Phoenix.Socket

  channel "conversation:*", RelayChatRealtimeWeb.ConversationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    with {:ok, claims} <- verify_token(token),
         %{"sub" => user_id} <- claims do
      {:ok, socket |> assign(:user_id, user_id) |> assign(:token, token)}
    else
      _ -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  defp verify_token(token) do
    signer = Joken.Signer.create("HS256", Application.fetch_env!(:relay_chat_realtime, :supabase_jwt_secret))
    Joken.verify(token, signer)
  end
end
