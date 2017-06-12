defmodule Legacy.FeatureTest do
  use Legacy.RedisCase, async: true

  describe "Legacy.Feature.init/1" do
    test "sets the defaults for a new feature", %{redis: redis} do
      Legacy.Feature.init "ft-feat-1"

      assert Redix.command!(redis, ~w(HKEYS features:ft-feat-1:feature)) ==
        ["created_at", "description", "expire_period", "notified", "rate_threshold", "updated_at"]
      assert Redix.command!(redis, ~w(HMGET features:ft-feat-1:feature description expire_period rate_threshold)) ==
        ["ft-feat-1", "30", "0.05"]

      [created_at, updated_at] =
        Redix.command!(redis, ~w(HMGET features:ft-feat-1:feature created_at updated_at))

      {:ok, _, 0} = DateTime.from_iso8601 created_at
      {:ok, _, 0} = DateTime.from_iso8601 updated_at
    end

    test "does not override preexisting settings", %{redis: redis} do
      now = DateTime.to_iso8601 DateTime.utc_now
      Redix.command! redis, ~w(HMSET features:ft-feat-2:feature description lel created_at #{now})

      Legacy.Feature.init "ft-feat-2"

      [expire_period, updated_at] =
        Redix.command! redis, ~w(HMGET features:ft-feat-2:feature expire_period updated_at)

      assert expire_period == "30"
      assert Redix.command!(redis, ~w(HMGET features:ft-feat-2:feature description created_at)) ==
        ["lel", now] # no changes
      {:ok, _, 0} = DateTime.from_iso8601 updated_at
    end
  end

  describe "Legacy.Feature.init/2" do
    test "sets the defaults updated with given values for a new feature", %{redis: redis} do
      Legacy.Feature.init "ft-feat-3", description: "something-else"

      assert Redix.command!(redis, ~w(HKEYS features:ft-feat-3:feature)) --
        ["description", "expire_period", "rate_threshold", "notified", "created_at", "updated_at"] == []

      assert Redix.command!(redis, ~w(HGET features:ft-feat-3:feature description)) == "something-else"
    end

    test "overrides existing values by given ones", %{redis: redis} do
      Redix.command! redis, ~w(HSET features:ft-feat-4:feature description something-entirely-different)

      Legacy.Feature.init "ft-feat-4", description: "something-else"

      assert Redix.command!(redis, ~w(HGET features:ft-feat-4:feature description)) == "something-else"
    end
  end
end


defmodule Legacy.FeatureSyncTest do
  use Legacy.RedisCase, async: false

  setup_all context do
    Legacy.Redis.scan("*")
    |> Enum.map(&Redix.command!(context.redis, ~w(DEL #{&1})))

    {:ok, context}
  end

  describe "Legacy.Feature.stream_all_features" do
    test "enumerates all available features" do
      Legacy.Feature.init("feat-sync-1")
      Legacy.Feature.init("feat-sync-2")

      features = Enum.into(Legacy.Feature.stream_all_features, [])
      assert Enum.any? features, fn %{description: name} -> name == "feat-sync-1" end
      assert Enum.any? features, fn %{description: name} -> name == "feat-sync-2" end

      Enum.each features, fn feature ->
        assert feature.expire_period == 30
        assert feature.rate_threshold == 0.05
        assert feature.created_at
        assert feature.updated_at
      end
    end
  end
end
