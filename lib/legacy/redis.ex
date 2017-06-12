defmodule Legacy.Redis do
  @endpoint Keyword.fetch! Application.get_env(:legacy, Legacy.Redis), :endpoint

  def redis_connection do
    Redix.start_link @endpoint
  end

  @spec scan(String.t) :: %Legacy.Redis.Scan{}
  def scan(match), do: Legacy.Redis.Scan.new(match: match, count: 100)

  def int_or_0(nil), do: 0
  def int_or_0(val), do: String.to_integer val
end
