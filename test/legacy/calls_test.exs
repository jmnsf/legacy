defmodule Legacy.CallsTest do
  use Legacy.RedisCase, async: true

  describe "Legacy.Calls.incr_old/2" do
    test "sets the old count to 1", %{redis: redis} do
      Legacy.Calls.incr_old "feat1", 12345
      assert Redix.command!(redis, ~w(HGET features:feat1:calls:12345 old)) == "1"
    end

    test "increments by one if count existed before", %{redis: redis} do
      Redix.command! redis, ~w(HSET features:feat2:calls:12345 old 2)
      Legacy.Calls.incr_old "feat2", 12345
      assert Redix.command!(redis, ~w(HGET features:feat2:calls:12345 old)) == "3"
    end
  end

  describe "Legacy.Calls.incr_old/3" do
    test "sets the old count by the given value", %{redis: redis} do
      Legacy.Calls.incr_old "feat3", 12345, 5
      assert Redix.command!(redis, ~w(HGET features:feat3:calls:12345 old)) == "5"
    end

    test "increments by value if count existed before", %{redis: redis} do
      Redix.command! redis, ~w(HSET features:feat4:calls:12345 old 2)
      Legacy.Calls.incr_old "feat4", 12345, 5
      assert Redix.command!(redis, ~w(HGET features:feat4:calls:12345 old)) == "7"
    end
  end

  describe "Legacy.Calls.incr_new/2" do
    test "sets the new count to 1", %{redis: redis} do
      Legacy.Calls.incr_new "feat5", 12345
      assert Redix.command!(redis, ~w(HGET features:feat5:calls:12345 new)) == "1"
    end

    test "increments by one if count existed before", %{redis: redis} do
      Redix.command! redis, ~w(HSET features:feat6:calls:12345 new 2)
      Legacy.Calls.incr_new "feat6", 12345
      assert Redix.command!(redis, ~w(HGET features:feat6:calls:12345 new)) == "3"
    end
  end

  describe "Legacy.Calls.incr_new/3" do
    test "sets the new count by the given value", %{redis: redis} do
      Legacy.Calls.incr_new "feat7", 12345, 5
      assert Redix.command!(redis, ~w(HGET features:feat7:calls:12345 new)) == "5"
    end

    test "increments by value if count existed before", %{redis: redis} do
      Redix.command! redis, ~w(HSET features:feat8:calls:12345 new 2)
      Legacy.Calls.incr_new "feat8", 12345, 5
      assert Redix.command!(redis, ~w(HGET features:feat8:calls:12345 new)) == "7"
    end
  end

  describe "Legacy.Calls.incr/2" do
    test "sets both new and old counts to 1", %{redis: redis} do
      Legacy.Calls.incr "feat9", 12345
      assert Redix.command!(redis, ~w(HMGET features:feat9:calls:12345 new old)) == ["1", "1"]
    end

    test "increments both counts if they existed before", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat10:calls:12345 new 2 old 3)
      Legacy.Calls.incr "feat10", 12345
      assert Redix.command!(redis, ~w(HMGET features:feat10:calls:12345 new old)) == ["3", "4"]
    end
  end

  describe "Legacy.Calls.incr/3" do
    test "sets both new and old counts to values provided", %{redis: redis} do
      Legacy.Calls.incr "feat11", 12345, {2, 3}
      assert Redix.command!(redis, ~w(HMGET features:feat11:calls:12345 new old)) == ["2", "3"]
    end

    test "increments by values if counts existed before", %{redis: redis} do
      Redix.command! redis, ~w(HMSET features:feat12:calls:12345 new 2 old 3)
      Legacy.Calls.incr "feat12", 12345, {3, 4}
      assert Redix.command!(redis, ~w(HMGET features:feat12:calls:12345 new old)) == ["5", "7"]
    end
  end
end
