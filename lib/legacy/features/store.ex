defmodule Legacy.Features.Store do
  @moduledoc """
  Provides a CRUD interface for Features. These are identified by a unique name
  and store such information as their expiry periods and create/update dates.
  """

  import Legacy.Redis

  @doc """
  Update an existing feature. Updates only the given attributes in `opts`.
  """
  @spec update(String.t, [{String.t, any}]) :: String.t
  def update(_name, []), do: nil
  def update(name, opts) do
    {:ok, redis} = redis_connection()

    params = Enum.flat_map(opts, fn { key, value } -> [key, value] end)
    command = ["HMSET" | [feature_key(name) | params]]

    Redix.command! redis, command
  end

  @doc """
  Sets the given values, if they are not set yet. Use this to ensure some
  defaults in the Feature.
  """
  @spec set_missing(String.t, [{String.t, any}]) :: [String.t]
  def set_missing(_name, []), do: nil
  def set_missing(name, values) do
    {:ok, redis} = redis_connection()
    redis_key = feature_key name

    Enum.map values, fn { key, value } ->
      # TODO: optimize this into pipeline
      Redix.command! redis, ["HSETNX", redis_key, key, value]
    end
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
  """
  @spec show(String.t) :: Map.t
  def show(name) do
    {:ok, redis} = redis_connection()

    case Redix.command! redis, ~w(HGETALL #{feature_key(name)}) do
      [] -> nil
      values ->
        Stream.chunk(values, 2)
        |> Enum.reduce(%{}, fn ([key, value], map) ->
          atom_key = String.to_atom(key)
          Map.put(map, atom_key, fix_value_type(atom_key, value))
        end)
    end
  end

  defp feature_key(name), do: "features:#{name}"

  defp fix_value_type(:expire_period, value), do: elem(Integer.parse(value), 0)
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
