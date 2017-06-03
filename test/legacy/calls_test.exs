defmodule Legacy.CallsTest do
  use Legacy.RedisCase, async: true

  setup_all do
    now = DateTime.to_unix DateTime.utc_now

    Legacy.Calls.Store.incr("call-2", now, {5, 5}) # now
    Legacy.Calls.Store.incr("call-2", now - 86400, {2, 3}) # 1 day
    Legacy.Calls.Store.incr("call-2", now - 2 * 86400, {4, 3}) # 2 day
    Legacy.Calls.Store.incr("call-2", now - 3 * 86400, {1, 4}) # 3 day
    Legacy.Calls.Store.incr("call-2", now - 2592000, {5, 4}) # 1 month
    Legacy.Calls.Store.incr("call-2", now - 86400 - 2592000, {2, 4}) # 1 month & 1 day
    Legacy.Calls.Store.incr("call-2", now - 2 * 2592000, {1, 1}) # 2 month
    Legacy.Calls.Store.incr("call-2", now - 86400 - 2 * 2592000, {3, 1}) # 2 month & 1 day
    Legacy.Calls.Store.incr("call-2", now - 2 * 86400 - 2 * 2592000, {3, 3}) # 2 month & 2 day

    {:ok, now: now}
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
      |> Stream.map(fn {ts, kind, count} -> "calls:call-1:86400:#{ts}:#{kind} #{count}" end)
      |> Enum.join(" ")

      Redix.command! redis, ~w(MSET #{sets})

      assert Legacy.Calls.timeseries("call-1", 1490397264, 1490742836) == %{
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
      assert Legacy.Calls.aggregate("call-2", from: now) == %{
        ts: [Utils.GranularTime.base_ts(now - 31536000)],
        new: [26],
        old: [28]
      }
    end

    test "returns the requested number of periods", %{now: now} do
      assert Legacy.Calls.aggregate("call-2", from: now, periods: 3) == %{
        ts: Utils.GranularTime.periodic_ts(now, 3, :year),
        new: [0, 0, 26],
        old: [0, 0, 28]
      }
    end

    test "returns one period of the given period_size, summed", %{now: now} do
      assert Legacy.Calls.aggregate("call-2", from: now, period_size: 2, period_granularity: :day) == %{
        ts: [Utils.GranularTime.base_ts(now - 86400)],
        new: [7],
        old: [8]
      }
    end

    test "combines periods and period_size", %{now: now} do
      assert Legacy.Calls.aggregate("call-2", from: now, periods: 2) == %{
        ts: [Utils.GranularTime.base_ts(now - 2*31536000), Utils.GranularTime.base_ts(now - 31536000)],
        new: [0, 26],
        old: [0, 28]
      }
    end

    test "takes weeks", %{now: now} do
      assert Legacy.Calls.aggregate("call-2", from: now, periods: 2, period_size: 5, period_granularity: :week) == %{
        ts: Utils.GranularTime.periodic_ts(now, 2, {5, :week}),
        new: [7, 19],
        old: [5, 23]
      }
    end

    test "returns averages", %{now: now} do
      assert Legacy.Calls.aggregate(
        "call-2",
        from: now,
        periods: 2,
        period_granularity: :month,
        aggregation: :avg
      ) == %{
        ts: [Utils.GranularTime.base_ts(now - 2 * 2592000), Utils.GranularTime.base_ts(now - 2592000)],
        new: [(5 + 2) / 30, (5 + 2 + 4 + 1) / 30],
        old: [(4 + 4) / 30, (5 + 3 + 3 + 4) / 30]
      }
    end
  end

  describe "Legacy.Calls.analyse" do
    test "returns last year's old rate by default", %{now: now} do
      assert Legacy.Calls.analyse("call-2", from: now) == %{
        ts: [Utils.GranularTime.base_ts(now - 31536000)],
        analysis: [28 / 54]
      }
    end

    test "supports the same options as `aggregate`", %{now: now} do
      assert Legacy.Calls.analyse("call-2", from: now, periods: 3, period_granularity: :month) == %{
        ts: (for n <- (3..1), do: Utils.GranularTime.base_ts(now - n * 2592000)),
        analysis: [5 / 12, 8 / 15, 15 / 27]
      }
    end

    test "can return a diff analysis", %{now: now} do
      assert Legacy.Calls.analyse("call-2", from: now, analysis: :diff) == %{
        ts: [Utils.GranularTime.base_ts(now - 31536000)],
        analysis: [28 - 26]
      }
    end

    test "can customize the periods fully, hiding datapoins with no calls", %{now: now} do
      assert Legacy.Calls.analyse(
        "call-2",
        from: now,
        periods: 6,
        period_size: 2,
        period_granularity: :week,
        analysis: :diff
      ) == %{
        ts: (for n <- [5, 3, 1], do: Utils.GranularTime.base_ts(now - n * 2 * 604800)),
        analysis: [5 - 7, 8 - 7, 15 - 12]
      }
    end

    test "does not return timestamps for which there are no calls" do
      assert Legacy.Calls.analyse("no-calls") == %{
        ts: [],
        analysis: []
      }
    end
  end
end
