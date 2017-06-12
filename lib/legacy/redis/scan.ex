defmodule Legacy.Redis.Scan do
  @moduledoc """
  A struct that represents a Redis SCAN command. Has several functions that help
  with managing this command, including implementing the Enumerable protocol,
  which iterates all the scanned keys.
  """

  alias Legacy.Redis.Scan

  defstruct [:match, :count]

  @doc """
  Builds a new Scan struct.

      iex> Scan.new(match: "some:key:*", count: 15)
      %Scan{match: "some:key:*", count: 15}
  """
  @spec new([match: String.t, count: non_neg_integer]) :: %Scan{}
  def new(match: match, count: count), do: %Scan{match: match, count: count}

  @doc """
  Builds a SCAN command with the given options

      iex> Scan.command %Scan{}
      ~w(SCAN 0)

      iex> Scan.command %Scan{}, 2
      ~w(SCAN 2)

      iex> Scan.command %Scan{match: "lel:*:coise"}, 3
      ~w(SCAN 3 MATCH lel:*:coise)

      iex> Scan.command %Scan{match: "lel:*:coise", count: 100}
      ~w(SCAN 0 MATCH lel:*:coise COUNT 100)
  """
  def command(%Scan{match: match, count: count}, cursor \\ 0) do
    cmd = []
    cmd = if count, do: (~w(COUNT #{count}) ++ cmd), else: cmd
    cmd = if match, do: (~w(MATCH #{match}) ++ cmd), else: cmd
    ~w(SCAN #{cursor}) ++ cmd
  end
end

defmodule Legacy.Redis.ScanCursor do
  @moduledoc """
  Helper module for iterating a SCAN command. Keeps state related to the current
  cursor and whether we've reached the end of the SCAN.
  """

  import Legacy.Redis

  alias Legacy.Redis.Scan
  alias Legacy.Redis.ScanCursor

  @enforce_keys [:scan]
  defstruct [:scan, :cursor, keys: []]

  @doc """
  Grabs the next value on this scan. This may or may not call Redis, since it
  might have a few cached keys.

  Returns `nil` when the cursor has no more keys.
  """
  @spec next_value(%ScanCursor{}) :: {:cont, {%ScanCursor{}, any}} | {:done, {%ScanCursor{}, nil}}
  def next_value(%ScanCursor{keys: [], cursor: "0"} = sc), do: {:done, {sc, nil}}
  def next_value(%ScanCursor{keys: [h | t]} = sc), do: {:cont, {struct(sc, keys: t), h}}
  def next_value(%ScanCursor{keys: []} = sc) do
    {new_cursor, keys} = run sc
    sc = struct sc, keys: keys, cursor: new_cursor
    next_value sc
  end

  # Actually calls the SCAN command in redis to fetch more keys
  defp run(%ScanCursor{scan: %Scan{} = scan, cursor: cursor}) do
    {:ok, redis} = redis_connection()
    [new_cursor, keys] = Redix.command! redis, Scan.command(scan, cursor || 0)
    {new_cursor, keys}
  end
end

defimpl Enumerable, for: Legacy.Redis.Scan do
  alias Legacy.Redis.Scan
  alias Legacy.Redis.ScanCursor

  # These both rely on the default algorithm for counting & checking membership
  def count(%Scan{}), do: {:error, __MODULE__}
  def member?(%Scan{}, _value), do: {:error, __MODULE__}

  def reduce(%ScanCursor{} = _, {:halt, acc}, _fun), do: {:halted, acc}

  def reduce(%ScanCursor{} = scan, {:suspend, acc}, fun) do
    {:suspended, acc, &reduce(scan, &1, fun)}
  end

  def reduce(%Scan{} = scan, {:cont, _} = acc, fun) do
    reduce(struct(ScanCursor, scan: scan), acc, fun)
  end

  def reduce(%ScanCursor{cursor: "0", keys: []}, {:cont, acc}, _fun), do: {:done, acc}

  def reduce(%ScanCursor{} = sc, {:cont, acc}, fun) do
    case ScanCursor.next_value sc do
      {:cont, {sc, value}} -> reduce(sc, fun.(value, acc), fun)
      {:done, {sc, _}} -> reduce(sc, {:cont, acc}, fun)
    end
  end
end
