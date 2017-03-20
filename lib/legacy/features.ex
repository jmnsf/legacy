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

  @doc """
  Returns whether a feature with the given `name` already exists.
  """
  def exists(name) do
    {:ok, redis} = redis_connection()
    Redix.command!(redis, ~w(EXISTS #{feature_key(name)})) == 1
  end

  @doc """
  Returns the current config for a feature with the given `name` or nil if it
  doesn't exist.
  """
  def show(name) do
    {:ok, redis} = redis_connection()

    case Redix.command! redis, ~w(HGETALL #{feature_key(name)}) do
      [] -> nil
      values ->
        Stream.chunk(values, 2)
        |> Enum.reduce(%{ }, fn ([key, value], map) ->
          atom_key = String.to_atom(key)
          Map.put(map, atom_key, fix_value_type(atom_key, value))
        end)
    end
  end

  defp init_defaults(_name, []), do: nil
  defp init_defaults(name, defaults) do
    {:ok, redis} = redis_connection()
    redis_key = feature_key name

    Enum.map defaults, fn({ key, value }) ->
      # TODO: optimize this into pipeline
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

  defp fix_value_type(:expire_period, value) do
    elem(Integer.parse(value), 0)
  end
  defp fix_value_type(:created_at, value), do: fix_date_value(value)
  defp fix_value_type(:updated_at, value), do: fix_date_value(value)
  defp fix_value_type(_, value), do: value

  defp fix_date_value(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, date, _offset} -> date
      {:error, err} -> raise "Bad date format. Got #{date_string}, error: #{err}"
    end
  end
end
