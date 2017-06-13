defmodule Legacy.Feature.Store.StoreTest do
  use Legacy.RedisCase, async: true
  import Legacy.ExtraAsserts

  describe "Legacy.Feature.Store.update/2" do
    test "sets the given values on a new feature", %{redis: redis} do
      Legacy.Feature.Store.update "feat-store-1", description: "something-else", expire_period: "12"

      assert Redix.command!(redis, ~w(HGETALL features:feat-store-1:feature)) ==
        ["description", "something-else", "expire_period", "12"]
    end

    test "updates the given values in an existing feature", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat-store-2:feature description something name else)

      Legacy.Feature.Store.update "feat-store-2", description: "something-else", expire_period: "12"

      assert Redix.command!(redis, ~w(HMGET features:feat-store-2:feature name description expire_period)) ==
        ["else", "something-else", "12"]
    end

    test "handles values with spaces", %{redis: redis} do
      Legacy.Feature.Store.update "feat-store-8", description: "something else"
      assert Redix.command!(redis, ~w(HGET features:feat-store-8:feature description)) == "something else"
    end
  end

  describe "Legacy.Feature.Store.exists/1" do
    test "returns true if a feature exists" do
      Legacy.Feature.init "feat-store-3"
      assert Legacy.Feature.Store.exists("feat-store-3") == true
    end

    test "returns false if a feature doesn't exist" do
      assert Legacy.Feature.Store.exists("feat-store-4") == false
    end
  end

  describe "Legacy.Feature.Store.show/1" do
    test "returns nil when the feature does not exist" do
      assert Legacy.Feature.Store.show("feat-store-4") == nil
    end

    test "returns an initialized Feature record with the feature's attributes" do
      Legacy.Feature.init "feat-store-5"
      feature = Legacy.Feature.Store.show("feat-store-5")

      assert feature.__struct__ == Legacy.Feature
      assert feature.description == "feat-store-5"
      assert feature.name == "feat-store-5"
      assert feature.expire_period == 30
      assert feature.notified == false
      assert feature.alert_endpoint == nil
      assert feature.alert_email == nil
      assert_date_approx feature.created_at, DateTime.utc_now
      assert_date_approx feature.updated_at, DateTime.utc_now
    end
  end

  describe "Legacy.Feature.Store.set_missing/2" do
    test "sets all the given values for a non-existing feature", %{redis: redis} do
      Legacy.Feature.Store.set_missing("feat-store-6", description: "a-feat", expire_period: 30)
      assert Redix.command!(redis, ~w(HGETALL features:feat-store-6:feature)) ==
        ["description", "a-feat", "expire_period", "30"]
    end

    test "sets only the given values when they're not set", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat-store-7:feature description a-feat name else)

      Legacy.Feature.Store.set_missing("feat-store-7", name: "this-name!", expire_period: 30)

      assert Redix.command!(redis, ~w(HGETALL features:feat-store-7:feature)) ==
        ["description", "a-feat", "name", "else", "expire_period", "30"]
    end

    test "handles values with spaces", %{redis: redis} do
      Legacy.Feature.Store.set_missing("feat-store-9", description: "a feat")
      assert Redix.command!(redis, ~w(HGET features:feat-store-9:feature description)) == "a feat"
    end
  end

  describe "Legacy.Feature.Store.update_stats/2" do
    test "sets all the values for a new feature", %{redis: redis} do
      Legacy.Feature.Store.update_stats("feat-store-10", {2, 3})
      stats = Redix.command! redis, ~w(HGETALL features:feat-store-10:stats)

      assert length(stats) == 8

      stats
      |> Stream.chunk(2)
      |> Enum.each(fn [key, value] ->
        case key do
          "total_new" -> assert value == "2"
          "total_old" -> assert value == "3"
          "first_call_at" -> assert_date_approx value, DateTime.utc_now
          "last_call_at" -> assert_date_approx value, DateTime.utc_now
        end
      end)
    end

    test "increments the total counts with the given values", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat-store-11:stats total_new 1 total_old 2)

      Legacy.Feature.Store.update_stats("feat-store-11", {2, 3})

      assert Redix.command!(redis, ~w(HMGET features:feat-store-11:stats total_new total_old)) == [
        "3", "5"
      ]
    end

    test "updates the last_call_at but not the first_call_at", %{redis: redis} do
      now = DateTime.to_iso8601 DateTime.utc_now
      Redix.command! redis, ~w(HMSET features:feat-store-12:stats first_call_at #{now} last_call_at #{now})

      Legacy.Feature.Store.update_stats("feat-store-12", {2, 3})

      [first_call_at, last_call_at] = Redix.command!(redis, ~w(HMGET features:feat-store-12:stats first_call_at last_call_at))
      assert first_call_at == now
      assert first_call_at != last_call_at
      assert_date_approx last_call_at, DateTime.utc_now
    end

    test "tolerates nil values on the calls", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat-store-13:stats total_new 1 total_old 2)

      Legacy.Feature.Store.update_stats("feat-store-13", {nil, 0})

      assert Redix.command!(redis, ~w(HMGET features:feat-store-13:stats total_new total_old)) == [
        "1", "2"
      ]
    end

    test "accepts an overriding timestamp as the last argument", %{redis: redis} do
      Legacy.Feature.Store.update_stats("feat-store-15", {2, 3}, 1483228799)
      iso_ts = DateTime.to_iso8601 elem(DateTime.from_unix(1483228799), 1)

      [first_call_at, last_call_at] = Redix.command!(redis, ~w(HMGET features:feat-store-15:stats first_call_at last_call_at))
      assert first_call_at == iso_ts
      assert last_call_at == iso_ts
    end
  end

  describe "Legacy.Feature.Store.show_stats/2" do
    test "returns nil when there are no stats for the feature" do
      assert Legacy.Feature.Store.show_stats("feat-store-4") == nil
    end

    test "returns the existing stats with the right types" do
      Legacy.Feature.Store.update_stats("feat-store-14", {1, 2})
      stats = Legacy.Feature.Store.show_stats("feat-store-14")

      assert stats[:total_new] == 1
      assert stats[:total_old] == 2
      assert_date_approx stats[:first_call_at], DateTime.utc_now
      assert_date_approx stats[:last_call_at], DateTime.utc_now
    end
  end
end

defmodule Legacy.Feature.StoreSyncTest do
  use Legacy.RedisCase, async: false

  setup_all context do
    Legacy.Redis.scan("*")
    |> Enum.map(&Redix.command!(context.redis, ~w(DEL #{&1})))

    {:ok, context}
  end

  describe "Legacy.Feature.Store.stream_all_feature_names" do
    test "enumerates all available feature names" do
      Legacy.Feature.init("feat-sync-1")
      Legacy.Feature.init("feat-sync-2")
      Legacy.Feature.init("feat-sync-3")
      Legacy.Feature.Store.update_stats("feat-sync-4", {5, 4})

      keys = Enum.into(Legacy.Feature.Store.stream_all_feature_names, [])

      assert length(keys) == 3
      Enum.each(
        ["feat-sync-1", "feat-sync-2", "feat-sync-3"],
        fn key -> assert Enum.member?(keys, key) end
      )
    end
  end
end
