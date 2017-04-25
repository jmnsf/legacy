defmodule Legacy.Redis do
  def redis_connection do
    Redix.start_link "redis://localhost/15"
  end

  def int_or_0(nil), do: 0
  def int_or_0(val), do: String.to_integer val
end
