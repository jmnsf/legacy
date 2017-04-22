defmodule Utils.Reducers do
  @doc """
  Sums all the elements in an enumerable.

  ## Examples:

      iex> Utils.Reducers.sum([1, 2, 3, 4])
      10
  """
  def sum([]), do: 0
  def sum(enum) do
    Enum.reduce(enum, fn val, acc -> acc + val end)
  end

  @doc """
  Calculates the average of all elements in an enumerable.

  ## Examples:

      iex> Utils.Reducers.avg([1, 2, 3, 4])
      2.5
  """
  def avg([]), do: raise "No values for averaging"
  def avg(enum) do
    {count, sum} = Enum.reduce(enum, {0, 0}, fn val, {count, sum} -> {count + 1, sum + val} end)
    sum / count
  end
end
