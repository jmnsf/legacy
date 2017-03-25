defmodule Legacy.FeaturesTest do
  import Legacy.ExtraAsserts
  use Legacy.RedisCase, async: true

  describe "Legacy.Features.init/1" do
    test "sets the defaults for a new feature", %{redis: redis} do
      Legacy.Features.init "ft-feat-1"

      assert Redix.command!(redis, ~w(HKEYS features:ft-feat-1)) ==
        ["description", "expire_period", "created_at", "updated_at"]
      assert Redix.command!(redis, ~w(HMGET features:ft-feat-1 description expire_period)) ==
        ["ft-feat-1", "30"]

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
        ["description", "expire_period", "created_at", "updated_at"] == []

      assert Redix.command!(redis, ~w(HGET features:ft-feat-3 description)) == "something-else"
    end

    test "overrides existing values by given ones", %{redis: redis} do
      Redix.command! redis, ~w(HSET ft-feat-4 description something-entirely-different)

      Legacy.Features.init "ft-feat-4", description: "something-else"

      assert Redix.command!(redis, ~w(HGET features:ft-feat-4 description)) == "something-else"
    end
  end

  describe "Legacy.Features.update/2" do
    test "sets the given values on a new feature", %{redis: redis} do
      Legacy.Features.update "ft-feat-5", description: "something-else", expire_period: "12"

      assert Redix.command!(redis, ~w(HGETALL features:ft-feat-5)) ==
        ["description", "something-else", "expire_period", "12"]
    end

    test "updates the given values in an existing feature", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:ft-feat-6 description something name else)

      Legacy.Features.update "ft-feat-6", description: "something-else", expire_period: "12"

      assert Redix.command!(redis, ~w(HMGET features:ft-feat-6 name description expire_period)) ==
        ["else", "something-else", "12"]
    end
  end

  describe "Legacy.Features.exists/1" do
    test "returns true if a feature exists" do
      Legacy.Features.init "ft-feat-7"
      assert Legacy.Features.exists("ft-feat-7") == true
    end

    test "returns false if a feature doesn't exist" do
      assert Legacy.Features.exists("ft-feat-8") == false
    end
  end

  describe "Legacy.Features.show/1" do
    test "returns nil when the feature does not exist" do
      assert Legacy.Features.show("ft-test-8") == nil
    end

    test "returns an initialized Feature record with the feature's attributes" do
      Legacy.Features.init "ft-feat-9"
      feature = Legacy.Features.show("ft-feat-9")

      assert feature[:description] == "ft-feat-9"
      assert feature[:expire_period] == 30
      assert_date_approx feature[:created_at], DateTime.utc_now
      assert_date_approx feature[:updated_at], DateTime.utc_now
    end
  end
end
