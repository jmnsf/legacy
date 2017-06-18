defmodule Legacy.Redis do
  @endpoint Keyword.fetch! Application.get_env(:legacy, Legacy.Redis), :endpoint

  def redis_connection do
    Redix.start_link @endpoint
  end

  @spec scan(String.t) :: %Legacy.Redis.Scan{}
  def scan(match), do: Legacy.Redis.Scan.new(match: match, count: 100)

  def int_or_0(nil), do: 0
  def int_or_0(val), do: String.to_integer val

  def expire(redis, key) do
    Redix.command! redis, ~w(EXPIRE #{key} )
  end

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
end
