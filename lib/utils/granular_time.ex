defmodule Utils.GranularTime do
  @moduledoc """
  This module provides utillity functions for dealing with and generating
  timestamp ranges that are normalized to a specific granularity.

  The granularity is expressed in seconds. Eg: 1 day granularity is 86400.
  """

  @granularities %{
    day: 86400,
    week: 604800,   # 7 days
    month: 2592000, # 30 days
    year: 31536000  # 365 days
  }

  @doc """
  Generates a list of timestamps that distance from eachother by `size` times
  the requested `granularity`. Starts generating values from the base of the
  given `from` timestamp, into the past. Values are returned in ascending order.

  ## Examples:

      iex> Utils.GranularTime.periodic_ts(1490742836, 1, :day)
      [1490659200]

      iex> Utils.GranularTime.periodic_ts(1490742836, 2, :day)
      [1490572800, 1490659200]

      iex> Utils.GranularTime.periodic_ts(1490742836, 1, {2, :day})
      [1490572800]

      iex> Utils.GranularTime.periodic_ts(1490742836, 2, {2, :day})
      [1490400000, 1490572800]

      iex> Utils.GranularTime.periodic_ts(1490742836, 2, :month)
      [1485475200, 1488067200]

      iex> Utils.GranularTime.periodic_ts(1490742836, 2, {2, :year})
      [1364515200, 1427587200]
  """
  @spec periodic_ts(non_neg_integer, non_neg_integer, {non_neg_integer, atom}) :: [non_neg_integer]
  def periodic_ts(from, periods, granularity) when is_atom(granularity) do
    periodic_ts(from, periods, {1, granularity})
  end

  def periodic_ts(from, periods, period_size) when periods > 0 do
    expand_periodic_ts(
      [period_start_day(from, period_size)],
      periods - 1,
      period_size
    )
  end

  defp expand_periodic_ts(range, 0, _), do: range
  defp expand_periodic_ts([last | _ ] = range, periods, {size, granularity} = period_size) do
    expand_periodic_ts(
      [base_ts(last - size * @granularities[granularity]) | range],
      periods - 1,
      period_size
    )
  end

  @doc """
  Builds a list of every timestamp between `from` and `to` normalized to the
  given `granularity`.

  Returned values will be sorted in ascending manner, regardless of from/to order.

  No values are returned if no normalized timestamp exists within given range.

  ## Examples:

      iex> Utils.GranularTime.normalized_ts_range(1490397264, 1490742836)
      [1490400000, 1490486400, 1490572800, 1490659200]
      iex> Utils.GranularTime.normalized_ts_range(1490397264, 1490742836, :day)
      [1490400000, 1490486400, 1490572800, 1490659200]

      iex> Utils.GranularTime.normalized_ts_range(1490397264, 1490742836, :year)
      []

      iex> Utils.GranularTime.normalized_ts_range(1490742836, 1490397264)
      [1490400000, 1490486400, 1490572800, 1490659200]

      iex> Utils.GranularTime.normalized_ts_range(1459901866, 1491437866, :year)
      [1482192000]

      iex> Utils.GranularTime.normalized_ts_range(1490313600, 1490742836)
      [1490313600, 1490400000, 1490486400, 1490572800, 1490659200]
  """
  @spec normalized_ts_range(non_neg_integer, non_neg_integer, atom) :: [non_neg_integer]
  def normalized_ts_range(from, to, granularity \\ :day)
  def normalized_ts_range(from, to, granularity) when from > to do
    normalized_ts_range(to, from, granularity)
  end
  def normalized_ts_range(from, to, granularity) when to >= from do
    normalized_ts_range([], from, base_ts(to, granularity), granularity)
  end

  defp normalized_ts_range(acc, from, to, _granularity) when from > to, do: acc
  defp normalized_ts_range(acc, from, to, granularity) do
    normalized_ts_range([to | acc], from, to - int_granularity(granularity), granularity)
  end

  @doc """
  Acts like `normalized_ts_range` except it guarantees that the base timestamp
  at the start exists.

  ## Examples:

    iex> Utils.GranularTime.based_normalized_ts_range(1490397264, 1490742836, :year)
    [1482192000]

    iex> Utils.GranularTime.based_normalized_ts_range(1490400000, 1490742836)
    [1490400000, 1490486400, 1490572800, 1490659200]

    iex> Utils.GranularTime.normalized_ts_range(1490742836, 1490397264)
    [1490400000, 1490486400, 1490572800, 1490659200]
  """
  @spec based_normalized_ts_range(non_neg_integer, non_neg_integer, atom) :: [non_neg_integer, ...]
  def based_normalized_ts_range(from, to, granularity \\ :day) do
    base_from = base_ts from, granularity
    range = normalized_ts_range from, to, granularity

    case range do
      [h | _] when h == base_from -> range
      [_ | _] -> [base_from | range]
      [] -> [base_from]
    end
  end

  @doc """
  Given a `timestamp`, returns its closest timestamp divisible by `granularity`.

  ## Examples:

      iex> Utils.GranularTime.base_ts(1490397264)
      1490313600

      iex> Utils.GranularTime.base_ts(1490397264, :day)
      1490313600

      iex> Utils.GranularTime.base_ts(1490397264, :week)
      1490227200

      iex> Utils.GranularTime.base_ts(1490397264, :month)
      1487808000

      iex> Utils.GranularTime.base_ts(1490397264, :year)
      1482192000
  """
  @spec base_ts(non_neg_integer, atom) :: non_neg_integer
  def base_ts(timestamp, granularity \\ :day) do
    div(timestamp, int_granularity(granularity)) * int_granularity(granularity)
  end

  @doc """
  Given a `timestamp`, returns its closest timestamp divisible by `granularity`,
  `size` granularities behind.

  ## Examples:

      iex> Utils.GranularTime.base_ts(1490397264, 1, :day)
      1490313600

      iex> Utils.GranularTime.base_ts(1490397264, 2, :day)
      1490227200

      iex> Utils.GranularTime.base_ts(1490397264, 3, :month)
      1482624000
  """
  @spec base_ts(non_neg_integer, non_neg_integer, atom) :: non_neg_integer
  def base_ts(timestamp, 1, granularity), do: base_ts(timestamp, granularity)
  def base_ts(timestamp, size, granularity) when size > 1 do
    root = base_ts(timestamp, granularity)
    root - int_granularity(granularity) * (size - 1)
  end

  @doc """
  Given a `timestamp` and a period size (`size` * `granularity`), returns the
  base timestamp of the starting day for that period.

  ## Examples:

      iex> Utils.GranularTime.period_start_day(1490397264, {1, :day})
      1490313600

      iex> Utils.GranularTime.period_start_day(1490397264, {2, :day})
      1490227200

      iex> Utils.GranularTime.period_start_day(1490397264, {2, :month})
      1485129600
  """
  @spec period_start_day(non_neg_integer, {non_neg_integer, atom}) :: non_neg_integer
  def period_start_day(timestamp, {size, granularity}) when size > 0 do
    multiplier = if granularity == :day, do: size - 1, else: size
    base_ts(timestamp) - multiplier * int_granularity(granularity)
  end

  @doc """
  Given a `granularity` atom, converts it to its integer representation.

  ## Examples:

      iex> Utils.GranularTime.int_granularity(:day)
      86400

      iex> Utils.GranularTime.int_granularity(:year)
      31536000
  """
  @spec int_granularity(atom) :: non_neg_integer
  def int_granularity(granularity) do
    if !Map.has_key?(@granularities, granularity), do: raise "No such granularity: #{granularity}"
    @granularities[granularity]
  end

  @doc """
  Given a `granularity`, returns how many days it contains.

  ## Examples:

      iex> Utils.GranularTime.granularity_in_days(:day)
      1

      iex> Utils.GranularTime.granularity_in_days(:month)
      30

      iex> Utils.GranularTime.granularity_in_days(:week)
      7

      iex> Utils.GranularTime.granularity_in_days(:year)
      365
  """
  @spec granularity_in_days(atom) :: non_neg_integer
  def granularity_in_days(granularity) do
    div int_granularity(granularity), int_granularity(:day)
  end

  @doc """
  Whether a granularity is divisible. Currently all supported ones are, do this
  only fails if the granularity is unknown.

  ## Examples:

      iex> Utils.GranularTime.divisible?(:day, :year)
      true
  """
  @spec divisible?(atom, atom) :: true
  def divisible?(target_granularity, source_granularity) do
    if !Map.has_key?(@granularities, target_granularity) do
      raise "No such granularity: #{target_granularity}"
    end

    if !Map.has_key?(@granularities, source_granularity) do
      raise "No such granularity: #{source_granularity}"
    end

    true
  end
end
