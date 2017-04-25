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
end
