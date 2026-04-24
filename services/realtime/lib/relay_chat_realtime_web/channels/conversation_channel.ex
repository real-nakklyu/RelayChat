defmodule RelayChatRealtimeWeb.ConversationChannel do
  use Phoenix.Channel
  alias RelayChatRealtime.{RateLimiter, Supabase}

  @impl true
  def join("conversation:" <> conversation_id, _payload, socket) do
    if Supabase.participant?(conversation_id, socket.assigns.user_id, socket.assigns.token) do
      {:ok, assign(socket, :conversation_id, conversation_id)}
    else
      {:error, %{reason: "not_authorized"}}
    end
  end

  @impl true
  def handle_in("typing", %{"username" => username}, socket) do
    if RateLimiter.allow_typing?(socket.assigns.user_id) do
      broadcast_from!(socket, "typing", %{user_id: socket.assigns.user_id, username: username})
    end

    {:noreply, socket}
  end

  def handle_in("new_message", %{"message_id" => message_id}, socket) do
    if RateLimiter.allow_message?(socket.assigns.user_id) do
      broadcast!(socket, "new_message", %{message_id: message_id, conversation_id: socket.assigns.conversation_id})
    end

    {:reply, :ok, socket}
  end

  def handle_in("message_updated", %{"message_id" => message_id}, socket) do
    broadcast!(socket, "message_updated", %{message_id: message_id, conversation_id: socket.assigns.conversation_id})
    {:reply, :ok, socket}
  end
end
