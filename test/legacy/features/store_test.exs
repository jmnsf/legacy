defmodule Legacy.Features.Store.StoreTest do
  use Legacy.RedisCase, async: true
  import Legacy.ExtraAsserts

  describe "Legacy.Features.Store.update/2" do
    test "sets the given values on a new feature", %{redis: redis} do
      Legacy.Features.Store.update "feat-store-1", description: "something-else", expire_period: "12"

      assert Redix.command!(redis, ~w(HGETALL features:feat-store-1)) ==
        ["description", "something-else", "expire_period", "12"]
    end

    test "updates the given values in an existing feature", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat-store-2 description something name else)

      Legacy.Features.Store.update "feat-store-2", description: "something-else", expire_period: "12"

      assert Redix.command!(redis, ~w(HMGET features:feat-store-2 name description expire_period)) ==
        ["else", "something-else", "12"]
    end

    test "handles values with spaces", %{redis: redis} do
      Legacy.Features.Store.update "feat-store-8", description: "something else"
      assert Redix.command!(redis, ~w(HGET features:feat-store-8 description)) == "something else"
    end
  end

  describe "Legacy.Features.Store.exists/1" do
    test "returns true if a feature exists" do
      Legacy.Features.init "feat-store-3"
      assert Legacy.Features.Store.exists("feat-store-3") == true
    end

    test "returns false if a feature doesn't exist" do
      assert Legacy.Features.Store.exists("feat-store-4") == false
    end
  end

  describe "Legacy.Features.Store.show/1" do
    test "returns nil when the feature does not exist" do
      assert Legacy.Features.Store.show("feat-store-4") == nil
    end

    test "returns an initialized Feature record with the feature's attributes" do
      Legacy.Features.init "feat-store-5"
      feature = Legacy.Features.Store.show("feat-store-5")

      assert feature[:description] == "feat-store-5"
      assert feature[:expire_period] == 30
      assert_date_approx feature[:created_at], DateTime.utc_now
      assert_date_approx feature[:updated_at], DateTime.utc_now
    end
  end

  describe "Legacy.Features.Store.set_missing/2" do
    test "sets all the given values for a non-existing feature", %{redis: redis} do
      Legacy.Features.Store.set_missing("feat-store-6", description: "a-feat", expire_period: 30)
      assert Redix.command!(redis, ~w(HGETALL features:feat-store-6)) ==
        ["description", "a-feat", "expire_period", "30"]
    end

    test "sets only the given values when they're not set", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat-store-7 description a-feat name else)

      Legacy.Features.Store.set_missing("feat-store-7", name: "this-name!", expire_period: 30)

      assert Redix.command!(redis, ~w(HGETALL features:feat-store-7)) ==
        ["description", "a-feat", "name", "else", "expire_period", "30"]
    end

    test "handles values with spaces", %{redis: redis} do
      Legacy.Features.Store.set_missing("feat-store-9", description: "a feat")
      assert Redix.command!(redis, ~w(HGET features:feat-store-9 description)) == "a feat"
    end
  end

  describe "Legacy.Features.Store.update_stats/2" do
    test "sets all the values for a new feature", %{redis: redis} do
      Legacy.Features.Store.update_stats("feat-store-10", {2, 3})
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

      Legacy.Features.Store.update_stats("feat-store-11", {2, 3})

      assert Redix.command!(redis, ~w(HMGET features:feat-store-11:stats total_new total_old)) == [
        "3", "5"
      ]
    end

    test "updates the last_call_at but not the first_call_at", %{redis: redis} do
      now = DateTime.to_iso8601 DateTime.utc_now
      Redix.command! redis, ~w(HMSET features:feat-store-12:stats first_call_at #{now} last_call_at #{now})

      Legacy.Features.Store.update_stats("feat-store-12", {2, 3})

      [first_call_at, last_call_at] = Redix.command!(redis, ~w(HMGET features:feat-store-12:stats first_call_at last_call_at))
      assert first_call_at == now
      assert first_call_at != last_call_at
      assert_date_approx last_call_at, DateTime.utc_now
    end

    test "tolerates nil values on the calls", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat-store-13:stats total_new 1 total_old 2)

      Legacy.Features.Store.update_stats("feat-store-13", {nil, 0})

      assert Redix.command!(redis, ~w(HMGET features:feat-store-13:stats total_new total_old)) == [
        "1", "2"
      ]
    end

    test "accepts an overriding timestamp as the last argument", %{redis: redis} do
      Legacy.Features.Store.update_stats("feat-store-15", {2, 3}, 1483228799)
      iso_ts = DateTime.to_iso8601 elem(DateTime.from_unix(1483228799), 1)

      [first_call_at, last_call_at] = Redix.command!(redis, ~w(HMGET features:feat-store-15:stats first_call_at last_call_at))
      assert first_call_at == iso_ts
      assert last_call_at == iso_ts
    end
  end

  describe "Legacy.Features.Store.show_stats/2" do
    test "returns nil when there are no stats for the feature" do
      assert Legacy.Features.Store.show_stats("feat-store-4") == nil
    end

    test "returns the existing stats with the right types" do
      Legacy.Features.Store.update_stats("feat-store-14", {1, 2})
      stats = Legacy.Features.Store.show_stats("feat-store-14")

      assert stats[:total_new] == 1
      assert stats[:total_old] == 2
      assert_date_approx stats[:first_call_at], DateTime.utc_now
      assert_date_approx stats[:last_call_at], DateTime.utc_now
    end
  end
end
