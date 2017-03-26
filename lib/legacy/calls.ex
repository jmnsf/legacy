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

  @day_granularity 86400

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
  @spec incr(String.t, non_neg_integer(), {integer(), integer()}) :: {integer(), integer()}
  def incr(feature_name, timestamp, { new, old }) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp, @day_granularity

    now_new = Redix.command! redis, ~w(INCRBY #{key}:new #{new})
    now_old = Redix.command! redis, ~w(INCRBY #{key}:old #{old})

    {now_new, now_old}
  end

  @doc """
  Increments the old count for feature `feature_name` by `count`, defaulting to
  1.
  """
  @spec incr_old(String.t, non_neg_integer(), integer()) :: integer()
  def incr_old(feature_name, timestamp, count \\ 1) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp, @day_granularity

    Redix.command! redis, ~w(INCRBY #{key}:old #{count})
  end

  @doc """
  Increments the new count for feature `feature_name` by `count`, defaulting to
  1.
  """
  @spec incr_new(String.t, non_neg_integer(), integer()) :: integer()
  def incr_new(feature_name, timestamp, count \\ 1) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp, @day_granularity

    Redix.command! redis, ~w(INCRBY #{key}:new #{count})
  end

  defp redis_connection do
    Redix.start_link "redis://localhost/15"
  end

  defp call_key(feature_name, timestamp, granularity) do
    ts = base_timestamp granularity, timestamp
    "calls:#{feature_name}:#{granularity}:#{ts}"
  end

  defp base_timestamp(granularity, timestamp) do
    div(timestamp, granularity) * granularity
  end
end
