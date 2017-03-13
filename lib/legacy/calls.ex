defmodule Legacy.Calls do

  @doc """
  Increments both old and new call counts for feature `feature_name` by 1
  """
  def incr(feature_name, timestamp) do
    incr(feature_name, timestamp, {1, 1})
  end

  @doc """
  Increments both old an new call counts for feature `feature_name` by the given
  values.
  """
  def incr(feature_name, timestamp, { new, old }) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp

    Redix.command! redis, ~w(HINCRBY #{key} new #{new})
    Redix.command! redis, ~w(HINCRBY #{key} old #{old})
  end

  @doc """
  Increments the old count for feature `feature_name` by `count`, defaulting to
  1.
  """
  def incr_old(feature_name, timestamp, count \\ 1) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp

    Redix.command! redis, ~w(HINCRBY #{key} old #{count})
  end

  @doc """
  Increments the new count for feature `feature_name` by `count`, defaulting to
  1.
  """
  def incr_new(feature_name, timestamp, count \\ 1) do
    {:ok, redis} = redis_connection()
    key = call_key feature_name, timestamp

    Redix.command! redis, ~w(HINCRBY #{key} new #{count})
  end

  defp redis_connection do
    Redix.start_link "redis://localhost/15"
  end

  defp call_key(feature_name, timestamp) do
    "features:#{feature_name}:calls:#{timestamp}"
  end
end
