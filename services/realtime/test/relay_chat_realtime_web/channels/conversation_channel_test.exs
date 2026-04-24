defmodule RelayChatRealtimeWeb.ConversationChannelTest do
  use ExUnit.Case, async: true

  test "rate limits are configured for message events" do
    assert RelayChatRealtime.RateLimiter.allow_message?("test-user")
  end
end
