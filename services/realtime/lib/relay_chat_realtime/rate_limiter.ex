defmodule RelayChatRealtime.RateLimiter do
  @message_limit {40, 60_000}
  @typing_limit {120, 60_000}

  def allow_message?(user_id), do: allow?("message:#{user_id}", @message_limit)
  def allow_typing?(user_id), do: allow?("typing:#{user_id}", @typing_limit)

  defp allow?(key, {limit, window_ms}) do
    case Hammer.check_rate(key, window_ms, limit) do
      {:allow, _count} -> true
      {:deny, _limit} -> false
    end
  end
end
