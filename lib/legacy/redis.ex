defmodule Legacy.Redis do
  @endpoint Keyword.fetch! Application.get_env(:legacy, Legacy.Redis), :endpoint

  def redis_connection do
    Redix.start_link @endpoint
  end

  @spec scan(String.t) :: %Legacy.Redis.Scan{}
  def scan(match), do: Legacy.Redis.Scan.new(match: match, count: 100)

  def int_or_0(nil), do: 0
  def int_or_0(val), do: String.to_integer val

  @doc """
  Helper for both pipelining & expiring keys on write ops.

  When the return matters, keep in mind this will leak the return from EXPIRE.
  The reason for this is that the EXPIRE call must be the last (since it doesn't
  make sense to expire a non-existing key) and it's not very optimal to remove
  the last element from a list. Maybe this will change in the future...
  Meanwhile just pattern match or `take` as many values as required.
  """
  def expired_write(redis, key, [[_ | _] | _] = commands) do
    expire_cmd = ~w(EXPIRE #{key} #{Utils.GranularTime.int_granularity(:day) * 30})
    Redix.pipeline! redis, commands ++ [expire_cmd]
  end

  # Single command, extracts result to non-array
  def expired_write(redis, key, commands) do
    [res | _] = expired_write(redis, key, [commands])
    res
  end

  def expired_write(key, commands) do
    {:ok, redis} = redis_connection()
    expired_write(redis, key, commands)
  end

  @doc """
  Quick run a pipeline of commands
  """
  def redis([[_ | _] | _] = commands) do
    {:ok, redis} = redis_connection()
    Redix.pipeline! redis, commands
  end

  @doc """
  Quick run a redis command
  """
  def redis(command) do
    {:ok, redis} = redis_connection()
    Redix.command! redis, command
  end

  @doc """
  Helpers for building Redis commands from keys & args in different data
  structures.
  """
  @spec make_cmd(atom, String.t, any) :: [String.t]
  def make_cmd(:hmset, key, attrs) when is_map(attrs), do: make_cmd(:hmset, key, Map.to_list(attrs))
  def make_cmd(:hmset, key, attrs) do
    params = Stream.filter(attrs, fn { key, _ } -> key != :__struct__ end)
    |> Enum.flat_map(fn { key, value } -> [key, value] end)

    ["HMSET" | [key | params]]
  end

  @doc """
  Gets an HashMap from redis as an Elixir map, optionally fixing the types of
  the retrieved values.
  """
  def redis_map(key, value_fixer \\ nil) do
    redis(~w(HGETALL #{key}))
    |> Stream.chunk(2)
    |> Enum.reduce(%{}, fn [key, value], map ->
      atom_key = String.to_atom key

      value = if value_fixer do
        value_fixer.(atom_key, value)
      else
        value
      end

      Map.put map, atom_key, value
    end)
  end
end
