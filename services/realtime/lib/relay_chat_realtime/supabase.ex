defmodule RelayChatRealtime.Supabase do
  @moduledoc """
  Small Supabase REST client used by channels to authorize membership.
  The client forwards the user's JWT so Postgres RLS remains the source of truth.
  """

  def participant?(conversation_id, user_id, token) do
    url =
      "#{supabase_url()}/rest/v1/conversation_participants?conversation_id=eq.#{conversation_id}&user_id=eq.#{user_id}&select=conversation_id"

    headers = [
      {"apikey", publishable_key()},
      {"authorization", "Bearer #{token}"},
      {"accept", "application/json"}
    ]

    case Finch.build(:get, url, headers) |> Finch.request(RelayChatRealtime.Finch) do
      {:ok, %{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, [_ | _]} -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  defp supabase_url, do: Application.fetch_env!(:relay_chat_realtime, :supabase_url)
  defp publishable_key, do: Application.fetch_env!(:relay_chat_realtime, :supabase_publishable_key)
end
