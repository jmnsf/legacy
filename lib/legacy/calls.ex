defmodule Legacy.Calls do
  @moduledoc """
  Interface for storing and incrementing feature calls. Each call is assigned
  to a feature and can be a "new" or an "old" call.

  Currently, calls are aggregated by Day only.

  ### Data Model

  Calls are stored in Redis with arbitrary granularity, down to the second.
  They are stored in the keyset:

    `calls:<feature_name>:<second_granularity>:<base_timestamp>:<[new|old]>`

  For example, a counter that aggregates calls for the day of Oct 1st, 2017
  would be represented by a `second_granularity` of `86400000` and a
  `base_timestamp` of 1506816000000. Thus, it would be stored at the key:

    `calls:<feature_name>:86400000:1506816000000:<[new|old]>`

  The next day would logically be accessible at the same `second_granularity`,
  with the `base_timestamp` incremented by said granularity.
  """

  alias Utils.GranularTime

  @doc """
  Increments both old an new call counts for feature `feature_name` by the given
  values. All calls will be aggregated according to `timestamp`.

  The new values are returned.

  ## Parameters

    - feature_name: The calls' feature name.
    - timestamp: The timestamp with which to aggregate the call increments.
    - new: How much to increment the new calls.
    - old: How much to increment the old calls.
  """
  @spec incr(String.t, non_neg_integer, {integer, integer}) :: {integer, integer}
  def incr(feature_name, timestamp, { new, old }) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp, :day

    now_new = Redix.command! redis, ~w(INCRBY #{key}:new #{new})
    now_old = Redix.command! redis, ~w(INCRBY #{key}:old #{old})

    {now_new, now_old}
  end

  @doc """
  Increments the old count for feature `feature_name` by `count`, defaulting to
  1.
  """
  @spec incr_old(String.t, non_neg_integer, integer) :: integer
  def incr_old(feature_name, timestamp, count \\ 1) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp, :day

    Redix.command! redis, ~w(INCRBY #{key}:old #{count})
  end

  @doc """
  Increments the new count for feature `feature_name` by `count`, defaulting to
  1.
  """
  @spec incr_new(String.t, non_neg_integer, integer) :: integer
  def incr_new(feature_name, timestamp, count \\ 1) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp, :day

    Redix.command! redis, ~w(INCRBY #{key}:new #{count})
  end

  @doc """
  Retrieves the calls stored for a feature at a specified `timestamp`. In
  absense of a particular counter, 0 is returned.
  """
  @spec get(String.t, non_neg_integer) :: {integer, integer}
  def get(feature_name, timestamp) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp, :day

    {
      int_or_0(Redix.command! redis, ~w(GET #{key}:new)),
      int_or_0(Redix.command! redis, ~w(GET #{key}:old))
    }
  end

  @doc """
  Generates a calls timeseries for a feature, from the given `from` timestamp
  to `to`.
  """
  @spec timeseries(String.t, non_neg_integer, non_neg_integer) :: Map.t
  def timeseries(feature_name, from, to \\ nil) do
    # TODO: Limit from -> to range, otherwise it's possible to DoS server
    to = to || DateTime.to_unix(DateTime.utc_now)
    timestamps = GranularTime.normalized_ts_range(from, to)
    calls = get_multiple_calls(feature_name, timestamps)

    calls
    |> Enum.reduce(%{ts: [], new: [], old: []}, fn ([new, old], acc) ->
      acc
      |> Map.update!(:new, fn lst -> [new | lst] end)
      |> Map.update!(:old, fn lst -> [old | lst] end)
    end)
    |> Map.put(:ts, timestamps)
    |> Map.update!(:new, &Enum.reverse(&1))
    |> Map.update!(:old, &Enum.reverse(&1))
  end

  @doc """
  Aggregate a feature's new & old calls from `from` up to `periods` in the past,
  where each aggregated period is sized according to `period_size` and
  `period_granularity`.

  Supports :sum and :avg as `aggregation`, adding by default.

  For example, a call to aggregate the past month and a half's calls in
  2-week buckets, summing all values in-between would be:

  `aggregate("fname", periods: 3, period_size: 2, period_granularity: :week)`
  """
  @spec aggregate(
    String.t,
    [
      periods: non_neg_integer,
      period_size: non_neg_integer,
      period_granularity: atom,
      from: non_neg_integer,
      aggregation: atom
    ]
  ) :: %{ts: [non_neg_integer], new: [non_neg_integer], old: [non_neg_integer]}
  def aggregate(feature_name, opts \\ []) do
    # TODO: limit range requested
    aggregation = Keyword.get opts, :aggregation, :sum
    from = Keyword.get opts, :from, DateTime.to_unix(DateTime.utc_now)
    periods = Keyword.get opts, :periods, 1
    period_size = Keyword.get opts, :period_size, 1
    period_granularity = Keyword.get opts, :period_granularity, :year

    aggregate_ts = GranularTime.periodic_ts from, periods, {period_size, period_granularity}
    calls_timestamps = GranularTime.periodic_ts(
      from,
      GranularTime.granularity_in_days(period_granularity) * period_size * periods,
      :day
    )

    seconds_period_size = period_size * GranularTime.int_granularity(period_granularity)
    bucket_size = div seconds_period_size, GranularTime.int_granularity(:day)

    get_multiple_calls(feature_name, calls_timestamps)
    |> bucketize_calls(bucket_size)
    |> aggregate_buckets(aggregation)
    |> Map.put(:ts, aggregate_ts)
  end

  @doc """
  Performs an aggregation using `aggregate` according to the given bucket opts.
  @see `aggregate` for more param info.

  Applies the given `analysis` to the aggregated values. Supports :rate or
  :diff, returning the rate of new calls to total or the difference between
  old and new calls, respectively.
  """
  @spec analyse(
    String.t,
    [
      periods: non_neg_integer,
      period_size: non_neg_integer,
      period_granularity: atom,
      from: non_neg_integer,
      analysis: atom
    ]
  ) :: %{ts: [non_neg_integer], analysis: [float | integer]}
  def analyse(feature_name, opts \\ []) do
    # TODO: limit range requested
    # TODO: stop double-reverse (in aggregation and here)
    analysis = Keyword.get opts, :analysis, :rate

    aggregated = aggregate(feature_name, Keyword.drop(opts, [:analysis]))

    analysed = analyse(aggregated[:new], aggregated[:old], analysis)

    Map.put(aggregated, :analysis, analysed)
    |> Map.drop([:new, :old])
  end

  defp analyse(new, old, analysis) do
    analyser = case analysis do
      :rate -> fn {a, b} -> a / (a + b) end
      :diff -> fn {a, b} -> a - b end
    end

    Stream.zip(new, old)
    |> Enum.map(&analyser.(&1))
  end

  defp bucketize_calls(calls, bucket_size) do
    bucketize_calls(%{new: [], old: []}, calls, bucket_size)
  end

  defp bucketize_calls(acc, [], _) do
    acc
    |> Map.update!(:new, &Enum.reverse(&1))
    |> Map.update!(:old, &Enum.reverse(&1))
  end

  defp bucketize_calls(acc, calls, bucket_size) do
    {bucket, rest} = Enum.split calls, bucket_size

    [new | [old | []]] = zip_to_list bucket

    acc
    |> Map.update!(:new, fn lst -> [new | lst] end)
    |> Map.update!(:old, fn lst -> [old | lst] end)
    |> bucketize_calls(rest, bucket_size)
  end

  defp aggregate_buckets(call_buckets, aggregation) when aggregation in [:sum, :avg] do
    call_buckets
    |> Map.update!(:new, &Enum.map(&1, fn bucket -> apply(Utils.Reducers, aggregation, [bucket]) end))
    |> Map.update!(:old, &Enum.map(&1, fn bucket -> apply(Utils.Reducers, aggregation, [bucket]) end))
  end

  @doc """
  Grabs calls from redis for the given feature and list of timestamps. Results
  are returned as an enumerable of [new_count, old_count] pairs.
  """
  @spec get_multiple_calls(String.t, [non_neg_integer]) :: Stream.t
  defp get_multiple_calls(_, []), do: []
  defp get_multiple_calls(feature_name, timestamps) do
    {:ok, redis} = redis_connection()

    keys = timestamps
    |> Stream.map(fn ts -> call_key(feature_name, ts, :day) end)
    |> Stream.flat_map(fn key -> [key <> ":new", key <> ":old"] end)
    |> Enum.join(" ")

    Redix.command!(redis, ~w(MGET #{keys}))
    |> Stream.map(&int_or_0(&1))
    |> Stream.chunk(2)
  end

  defp redis_connection do
    Redix.start_link "redis://localhost/15"
  end

  defp call_key(feature_name, timestamp, granularity) do
    ts = GranularTime.base_ts timestamp, granularity
    int_gran = GranularTime.int_granularity granularity
    "calls:#{feature_name}:#{int_gran}:#{ts}"
  end

  defp int_or_0(nil), do: 0
  defp int_or_0(val), do: String.to_integer val

  # Zips enumerables into 2 lists. Does not respect original order. Do a reverse
  # on each if that's important.
  defp zip_to_list([]), do: []
  defp zip_to_list(enum), do: zip_to_list([[], []], enum)
  defp zip_to_list(acc, []), do: acc
  defp zip_to_list([left, right], [[first | [last | []]] | tail]) do
    zip_to_list [[first | left], [last | right]], tail
  end
end
