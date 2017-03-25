defmodule Legacy.RedisCase do
  use ExUnit.CaseTemplate

  setup_all do
    {:ok, redis} = Redix.start_link "redis://localhost/15"
    {:ok, redis: redis}
  end
end
