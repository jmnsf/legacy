defmodule Legacy.FeaturesTest do
  use Legacy.RedisCase, async: true

  describe "Legacy.Features.init/1" do
    test "sets the defaults for a new feature", %{redis: redis} do
      Legacy.Features.init "ft-feat-1"

      assert Redix.command!(redis, ~w(HKEYS features:ft-feat-1)) ==
        ["description", "expire_period", "rate_threshold", "created_at", "updated_at"]
      assert Redix.command!(redis, ~w(HMGET features:ft-feat-1 description expire_period rate_threshold)) ==
        ["ft-feat-1", "30", "0.05"]

      [created_at, updated_at] =
        Redix.command!(redis, ~w(HMGET features:ft-feat-1 created_at updated_at))

      {:ok, _, 0} = DateTime.from_iso8601 created_at
      {:ok, _, 0} = DateTime.from_iso8601 updated_at
    end

    test "does not override preexisting settings", %{redis: redis} do
      now = DateTime.to_iso8601 DateTime.utc_now
      Redix.command! redis, ~w(HMSET features:ft-feat-2 description lel created_at #{now})

      Legacy.Features.init "ft-feat-2"

      [expire_period, updated_at] =
        Redix.command! redis, ~w(HMGET features:ft-feat-2 expire_period updated_at)

      assert expire_period == "30"
      assert Redix.command!(redis, ~w(HMGET features:ft-feat-2 description created_at)) ==
        ["lel", now] # no changes
      {:ok, _, 0} = DateTime.from_iso8601 updated_at
    end
  end

  describe "Legacy.Features.init/2" do
    test "sets the defaults updated with given values for a new feature", %{redis: redis} do
      Legacy.Features.init "ft-feat-3", description: "something-else"

      assert Redix.command!(redis, ~w(HKEYS features:ft-feat-3)) --
        ["description", "expire_period", "rate_threshold", "created_at", "updated_at"] == []

      assert Redix.command!(redis, ~w(HGET features:ft-feat-3 description)) == "something-else"
    end

    test "overrides existing values by given ones", %{redis: redis} do
      Redix.command! redis, ~w(HSET ft-feat-4 description something-entirely-different)

      Legacy.Features.init "ft-feat-4", description: "something-else"

      assert Redix.command!(redis, ~w(HGET features:ft-feat-4 description)) == "something-else"
    end
  end
end
