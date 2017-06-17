defmodule Legacy.Feature.Store do
  @moduledoc """
  Provides a CRUD interface for Features. These are identified by a unique name
  and store such information as their expiry periods and create/update dates.
  """

  import Legacy.Redis

  @doc """
  Update an existing feature. Updates only the given attributes in `attrs`.
  """
  @spec update(String.t, [{String.t | atom, any}]) :: String.t
  def update(_name, []), do: nil
  def update(name, attrs) do
    {to_remove, to_update} = Enum.split_with(attrs, fn {_, value} -> is_nil(value) end)

    set_attributes name, to_update
    del_keys name, Enum.map(to_remove, &elem(&1, 0))
  end

  @doc """
  Sets the given values, if they are not set yet. Use this to ensure some
  defaults in the Feature.
  """
  @spec set_missing(String.t, [{String.t, any}]) :: [String.t]
  def set_missing(_name, []), do: nil
  def set_missing(name, values) do
    redis_key = feature_key name

    Stream.map(values, fn {key, value} -> ["HSETNX", redis_key, key, value] end)
    |> Enum.reduce([], fn command, commands -> [command | commands] end)
    |> (&expired_write(redis_key, &1)).() # ew
  end

  @doc """
  Returns whether a feature with the given `name` already exists.
  """
  @spec exists(String.t) :: boolean
  def exists(name) do
    {:ok, redis} = redis_connection()
    Redix.command!(redis, ~w(EXISTS #{feature_key(name)})) == 1
  end

  @doc """
  Returns the current config for a feature with the given `name` or nil if it
  doesn't exist.

  Adds the feature's name for ease of use.
  """
  @spec show(String.t) :: %Legacy.Feature{} | nil
  def show(name) do
    attrs = get_all_fixed(feature_key(name))

    if attrs == nil do
      nil
    else
      struct %Legacy.Feature{}, Map.put(attrs, :name, name)
    end
  end

  @doc """
  Returns the call stats for a feature with the given `name`, or nil if there
  are none to date.
  """
  @spec show_stats(String.t) :: Map.t
  def show_stats(name), do: get_all_fixed(feature_stats_key(name))

  @doc """
  Updates the call stats for the feature with the given `name`. This will
  increment the total new & old calls, as well as set the first_call_at timestamp
  to `ts` if it doesn't exist, and the last_call_at timestamp to `ts`.

  So it's clear: this function expects to be called chronologically.
  """
  @spec update_stats(String.t, {non_neg_integer, non_neg_integer}, non_neg_integer) :: any
  def update_stats(name, {new, old}, ts \\ nil) do
    new = new || 0
    old = old || 0
    ts = DateTime.to_iso8601(ts && elem(DateTime.from_unix(ts), 1) || DateTime.utc_now)

    commands = [
      ~w(HSETNX #{feature_stats_key(name)} first_call_at #{ts}),
      ~w(HSET #{feature_stats_key(name)} last_call_at #{ts})
    ]

    commands = if new > 0 do
      [~w(HINCRBY #{feature_stats_key(name)} total_new #{new}) | commands]
    else
      commands
    end

    commands = if old > 0 do
      [~w(HINCRBY #{feature_stats_key(name)} total_old #{old}) | commands]
    else
      commands
    end

    expired_write(feature_stats_key(name), commands)
  end

  @doc """
  Returns a Stream that yields all feature names that exist in the database.
  This _might_ return the same name twice.
  """
  @spec stream_all_feature_names :: Stream.t
  def stream_all_feature_names do
    scan("features:*:feature")
    |> Stream.map(fn key -> List.first(Regex.run(~r/:([\w-]+):/, key, capture: :all_but_first)) end)
  end

  # sets the given `attrs` in the feature map. `attrs` is a list of {key, value} tuples.
  defp set_attributes(_, []), do: :ok
  defp set_attributes(name, attrs) do
    {:ok, redis} = redis_connection()

    params = Enum.flat_map(attrs, fn { key, value } -> [key, value] end)
    expired_write(redis, feature_key(name), ["HMSET" | [feature_key(name) | params]])
  end

  defp del_keys(_, []), do: :ok
  defp del_keys(name, keys) do
    {:ok, redis} = redis_connection()

    command = ["HDEL" | [feature_key(name) | keys]]
    Redix.command! redis, command
  end

  defp base_feature_key(name), do: "features:#{name}"
  defp feature_key(name), do: "#{base_feature_key(name)}:feature"
  defp feature_stats_key(name), do: "#{base_feature_key(name)}:stats"

  defp get_all_fixed(key) do
    {:ok, redis} = redis_connection()

    case Redix.command! redis, ~w(HGETALL #{key}) do
      [] -> nil
      values ->
        Stream.chunk(values, 2)
        |> Enum.reduce(%{}, fn [key, value], map ->
          atom_key = String.to_atom key
          Map.put(map, atom_key, fix_value_type(atom_key, value))
        end)
    end
  end

  defp fix_value_type(:rate_threshold, value), do: elem(Float.parse(value), 0)
  defp fix_value_type(:expire_period, value), do: elem(Integer.parse(value), 0)
  defp fix_value_type(:created_at, value), do: fix_date_value(value)
  defp fix_value_type(:updated_at, value), do: fix_date_value(value)
  defp fix_value_type(:first_call_at, value), do: fix_date_value(value)
  defp fix_value_type(:last_call_at, value), do: fix_date_value(value)
  defp fix_value_type(:total_new, value), do: elem(Integer.parse(value), 0)
  defp fix_value_type(:total_old, value), do: elem(Integer.parse(value), 0)
  defp fix_value_type(:notified_at, value), do: fix_date_value(value)
  defp fix_value_type(_, value), do: value

  defp fix_date_value(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, date, _offset} -> date
      {:error, err} -> raise "Bad date format. Got #{date_string}, error: #{err}"
    end
  end
end
