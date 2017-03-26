defmodule Legacy.CallsTest do
  use Legacy.RedisCase, async: true

  describe "Legacy.Calls.incr/3" do
    test "creates counters for new & old at the timestamp's base, with day granularity", %{redis: redis} do
      now = DateTime.to_unix DateTime.utc_now
      base = div(now, 86400) * 86400

      Legacy.Calls.incr "call-1", now , {2, 3}

      assert Redix.command!(redis, ~w(EXISTS calls:call-1:86400:#{base}:new)) == 1
      assert Redix.command!(redis, ~w(EXISTS calls:call-1:86400:#{base}:old)) == 1
    end

    test "sets both new and old counts to values provided", %{redis: redis} do
      Legacy.Calls.incr "call-2", 1506816000, {2, 3}

      new_key = "calls:call-2:86400:1506816000:new"
      old_key = "calls:call-2:86400:1506816000:old"
      assert Redix.command!(redis, ~w(MGET #{new_key} #{old_key})) == ["2", "3"]
    end

    test "increments by values if counts existed before", %{redis: redis} do
      new_key = "calls:call-3:86400:1506816000:new"
      old_key = "calls:call-3:86400:1506816000:old"
      Redix.command! redis, ~w(MSET #{new_key} 2 #{old_key} 3)

      Legacy.Calls.incr "call-3", 1506816000, {3, 4}

      assert Redix.command!(redis, ~w(MGET #{new_key} #{old_key})) == ["5", "7"]
    end

    test "returns the new values" do
      assert Legacy.Calls.incr("call-12", 1506816000, {2, 3}) == {2, 3}
    end
  end

  describe "Legacy.Calls.incr_new" do
    test "creates counters for new at the timestamp's base, with day granularity", %{redis: redis} do
      now = DateTime.to_unix DateTime.utc_now
      base = div(now, 86400) * 86400

      Legacy.Calls.incr_new "call-4", now, 2

      assert Redix.command!(redis, ~w(EXISTS calls:call-4:86400:#{base}:new)) == 1
    end

    test "sets new count to the value provided", %{redis: redis} do
      Legacy.Calls.incr_new "call-5", 1506816000, 2
      assert Redix.command!(redis, ~w(GET calls:call-5:86400:1506816000:new)) == "2"
    end

    test "increments by value if count existed before", %{redis: redis} do
      Redix.command! redis, ~w(SET calls:call-6:86400:1506816000:new 2)

      Legacy.Calls.incr_new "call-6", 1506816000, 3

      assert Redix.command!(redis, ~w(GET calls:call-6:86400:1506816000:new)) == "5"
    end

    test "defauts to value 1 when given none", %{redis: redis} do
      Legacy.Calls.incr_new "call-7", 1506816000
      assert Redix.command!(redis, ~w(GET calls:call-7:86400:1506816000:new)) == "1"
    end

    test "returns the new value" do
      assert Legacy.Calls.incr_new("call-13", 1506816000, 80) == 80
    end
  end

  describe "Legacy.Calls.incr_old" do
    test "creates counters for old at the timestamp's base, with day granularity", %{redis: redis} do
      now = DateTime.to_unix DateTime.utc_now
      base = div(now, 86400) * 86400

      Legacy.Calls.incr_old "call-8", now, 2

      assert Redix.command!(redis, ~w(EXISTS calls:call-8:86400:#{base}:old)) == 1
    end

    test "sets old count to the value provided", %{redis: redis} do
      Legacy.Calls.incr_old "call-9", 1506816000, 2
      assert Redix.command!(redis, ~w(GET calls:call-9:86400:1506816000:old)) == "2"
    end

    test "increments by value if count existed before", %{redis: redis} do
      Redix.command! redis, ~w(SET calls:call-10:86400:1506816000:old 2)

      Legacy.Calls.incr_old "call-10", 1506816000, 3

      assert Redix.command!(redis, ~w(GET calls:call-10:86400:1506816000:old)) == "5"
    end

    test "defauts to value 1 when given none", %{redis: redis} do
      Legacy.Calls.incr_old "call-11", 1506816000
      assert Redix.command!(redis, ~w(GET calls:call-11:86400:1506816000:old)) == "1"
    end

    test "returns the new value" do
      assert Legacy.Calls.incr_old("call-14", 1506816000, 77) == 77
    end
  end
end
