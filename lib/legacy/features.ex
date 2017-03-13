defmodule Legacy.Features do
  @doc """
  Initialize a feature structure if it doesn't exist, update it with `opts` if
  it does exist. `opts` will also be used to override defaults when initializing.
  """
  def init(name, opts \\ []) do
    defaults = feature_defaults name
    init_defaults name, Keyword.drop(defaults, Keyword.keys(opts))
    update name, opts
  end

  @doc """
  Update an existing feature. Updates only the given attributes in `opts`.
  """
  def update(_name, []), do: nil
  def update(name, opts) do
    {:ok, redis} = redis_connection()
    params = Enum.map(opts, fn({ key, value }) -> "#{key} #{value}" end)
      |> Enum.join(" ")

    Redix.command! redis, ~w(HMSET #{feature_key(name)} #{params})
  end

  defp init_defaults(_name, []), do: nil
  defp init_defaults(name, defaults) do
    {:ok, redis} = redis_connection()
    redis_key = feature_key name

    Enum.map defaults, fn({ key, value }) ->
      Redix.command! redis, ~w(HSETNX #{redis_key} #{key} #{value})
    end
  end

  defp feature_defaults(name) do
    now = DateTime.to_iso8601 DateTime.utc_now
    [description: name, expire_period: 30, created_at: now, updated_at: now]
  end

  defp redis_connection do
    Redix.start_link "redis://localhost/15"
  end

  defp feature_key(name) do
    "features:#{name}"
  end
end
