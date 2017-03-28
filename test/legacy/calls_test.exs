defmodule Legacy.CallsTest do
  use Legacy.RedisCase, async: true

  setup_all do
    now = DateTime.to_unix DateTime.utc_now

    Legacy.Calls.incr("call-16", now, {5, 5}) # now
    Legacy.Calls.incr("call-16", now - 86400, {2, 3}) # 1 day
    Legacy.Calls.incr("call-16", now - 2 * 86400, {4, 3}) # 2 day
    Legacy.Calls.incr("call-16", now - 3 * 86400, {1, 4}) # 3 day
    Legacy.Calls.incr("call-16", now - 2592000, {5, 4}) # 1 month
    Legacy.Calls.incr("call-16", now - 86400 - 2592000, {2, 4}) # 1 month & 1 day
    Legacy.Calls.incr("call-16", now - 2 * 2592000, {1, 1}) # 2 month
    Legacy.Calls.incr("call-16", now - 86400 - 2 * 2592000, {3, 1}) # 2 month & 1 day
    Legacy.Calls.incr("call-16", now - 2 * 86400 - 2 * 2592000, {3, 3}) # 2 month & 2 day

    {:ok, now: now}
  end

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

  describe "Legacy.Calls.timeseries" do
    test "fetches call values for all days between the given timestamps" do
      assert Legacy.Calls.timeseries("inexistant", 1490397264, 1490742836) == %{
        ts: [1490400000, 1490486400, 1490572800, 1490659200],
        new: [0, 0, 0, 0],
        old: [0, 0, 0, 0]
      }
    end

    test "tolerates reversed timestamps" do
      assert Legacy.Calls.timeseries("inexistant", 1490742836, 1490397264) == %{
        ts: [1490400000, 1490486400, 1490572800, 1490659200],
        new: [0, 0, 0, 0],
        old: [0, 0, 0, 0]
      }
    end

    test "returns ordered calls by timestamp for the given feature", %{redis: redis} do
      sets = [
        {1490400000, "old", 6},
        {1490486400, "old", 4}, {1490486400, "new", 3},
        {1490572800, "old", 2}, {1490572800, "new", 6},
        {1490659200, "new", 8}
      ]
      |> Stream.map(fn {ts, kind, count} -> "calls:call-15:86400:#{ts}:#{kind} #{count}" end)
      |> Enum.join(" ")

      Redix.command! redis, ~w(MSET #{sets})

      assert Legacy.Calls.timeseries("call-15", 1490397264, 1490742836) == %{
        ts: [1490400000, 1490486400, 1490572800, 1490659200],
        new: [0, 3, 6, 8],
        old: [6, 4, 2, 0]
      }
    end

    test "returns nothing when given a bad range" do
      # same TS
      assert Legacy.Calls.timeseries("inexistant", 1490397264, 1490397264) == %{
        ts: [],
        new: [],
        old: []
      }

      # too close
      assert Legacy.Calls.timeseries("inexistant", 1490397264, 1490399999) == %{
        ts: [],
        new: [],
        old: []
      }
    end
  end

  describe "Legacy.Calls.aggregate" do
    test "returns a summed aggregate of the past year by default", %{now: now} do
      assert Legacy.Calls.aggregate("call-16", from: now) == %{
        ts: [Utils.GranularTime.base_ts(now - 31536000)],
        new: [26],
        old: [28]
      }
    end

    test "returns the requested number of periods", %{now: now} do
      assert Legacy.Calls.aggregate("call-16", from: now, periods: 3) == %{
        ts: Utils.GranularTime.periodic_ts(now, 3, :year),
        new: [0, 0, 26],
        old: [0, 0, 28]
      }
    end

    test "returns one period of the given period_size, summed", %{now: now} do
      assert Legacy.Calls.aggregate("call-16", from: now, period_size: {2, :day}) == %{
        ts: [Utils.GranularTime.base_ts(now - 86400)],
        new: [7],
        old: [8]
      }
    end

    test "combines period and period_size", %{now: now} do
      assert Legacy.Calls.aggregate("call-16", from: now, periods: 2, period_size: {1, :year}) == %{
        ts: [Utils.GranularTime.base_ts(now - 2*31536000), Utils.GranularTime.base_ts(now - 31536000)],
        new: [0, 26],
        old: [0, 28]
      }
    end

    test "takes weeks", %{now: now} do
      assert Legacy.Calls.aggregate("call-16", from: now, periods: 2, period_size: {5, :week}) == %{
        ts: Utils.GranularTime.periodic_ts(now, 2, {5, :week}),
        new: [7, 19],
        old: [5, 23]
      }
    end

    test "returns averages", %{now: now} do
      assert Legacy.Calls.aggregate(
        "call-16",
        from: now,
        periods: 2,
        period_size: {1, :month},
        aggregation: :avg
      ) == %{
        ts: [Utils.GranularTime.base_ts(now - 2 * 2592000), Utils.GranularTime.base_ts(now - 2592000)],
        new: [(5 + 2) / 30, (5 + 2 + 4 + 1) / 30],
        old: [(4 + 4) / 30, (5 + 3 + 3 + 4) / 30]
      }
    end
  end
end
