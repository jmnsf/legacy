defmodule Legacy.Analysis do
  @doc """
  Calculates the average of a set of values.

  ## Examples:
      iex> Legacy.Analysis.average([1, 2, 3, 4], 4)
      2.5

  """
  @spec average([number], non_neg_integer) :: number
  def average(values, size) do
    Enum.sum(values) / size
  end

  @doc """
  Calculates the weighted average of a set of values. By default, values at the
  end of the list have greater weight. Pass `true` in the third argument to
  reverse this.

  ## Examples:
      iex> Legacy.Analysis.weighted_average([1, 2, 3, 4], 4)
      3.0

      iex> Legacy.Analysis.weighted_average([1, 2, 3, 4], 4, true)
      2.0
  """
  @spec weighted_average([number], non_neg_integer, boolean) :: number
  def weighted_average(values, size, reverse \\ false) do
    weight_fn = if reverse do
      fn idx -> size - idx end
    else
      fn idx -> idx + 1 end
    end

    quotient = values
      |> Stream.with_index()
      |> Enum.reduce(0, fn {val, idx}, acc -> acc + val * weight_fn.(idx) end)

    quotient / Enum.sum((size..1))
  end

  @doc """
  Calculate the moving average of a set of values. The result will be shortened
  by `size` - 1 to account for the averaging.

  Currently implements a Weighted Moving Average only.
  """
  @spec moving_average([integer], non_neg_integer, atom) :: [integer]
  def moving_average([], _, __), do: []
  def moving_average(values, 1, _), do: values
  def moving_average(values, size, :weighted) do
    {sample, rest} = take([], values, size, 0)
    moving_average([], sample, rest, size, :weighted)
  end

  defp moving_average(acc, sample, [h | t], size, :weighted) do
    moving_average(
      [weighted_average(sample, size, true) | acc],
      [h | Enum.take(sample, size)],
      t,
      size,
      :weighted
    )
  end

  defp moving_average(acc, sample, [], size, :weighted) do
    Enum.reverse [weighted_average(sample, size, true) | acc]
  end

  @doc """
  Builds a simple_regression_model from a sample of dependent variables and its
  correspondent set of independent variables.

  @see Legacy.Analysis.SimpleLinearRegression.build/3
  """
  def simple_regression_model(xs, ys), do: simple_regression_model(xs, ys, length xs)
  def simple_regression_model(xs, ys, size) do
    Legacy.Analysis.SimpleLinearRegression.build(xs, ys, size)
  end

  defp take(head, rest, count, taken) when count <= taken do
    {head, rest}
  end

  defp take(head, [h | tail], count, taken) do
    take([h | head], tail, count, taken + 1)
  end
end
