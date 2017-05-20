defmodule Legacy.Analysis do
  @doc """
  Calculate the moving average of a set of values. The result will be shortened
  by `size` to account for the averaging.

  Currently implements a Weighted Moving Average only.
  """
  @spec moving_average([integer], non_neg_integer, atom) :: [integer]
  def moving_average(values, 1, _), do: values
  def moving_average(values, size, :weighted) do
    {sample, rest} = take([], values, size, 0)
    moving_average([], sample, rest, size, :weighted)
  end

  @doc """
  Implements a simple regression model on two sets of variables. Returns a
  function that takes a value of x (the independent variable) and predicts
  the value of y (the dependent variable).

  @see https://en.wikipedia.org/wiki/Ordinary_least_squares (non-robust)
  @see https://en.wikipedia.org/wiki/Ordinary_least_squares#Simple_regression_model
  @see https://en.wikipedia.org/wiki/Theil%E2%80%93Sen_estimator (robust)

  ## Examples:

      iex> Legacy.Analysis.simple_regression_model([1, 2, 3], [4, 5, 6]).(4)
      7.0
  """
  def simple_regression_model(xs, ys), do: simple_regression_model(xs, ys, length xs)
  def simple_regression_model(xs, ys, size) do
    beta = covariance(xs, ys, size) / variance(xs, size)
    alfa = average(ys, size, :simple) - beta * average(xs, size, :simple)

    fn x -> alfa + beta * x end
  end

  defp moving_average(acc, sample, [h | t], size, :weighted) do
    moving_average(
      [average(sample, size, :weighted) | acc],
      [h | Enum.take(sample, size)],
      t,
      size,
      :weighted
    )
  end

  defp moving_average(acc, sample, [], size, :weighted) do
    Enum.reverse [average(sample, size, :weighted) | acc]
  end

  defp take(head, rest, count, taken) when count <= taken do
    {head, rest}
  end

  defp take(head, [h | tail], count, taken) do
    take([h | head], tail, count, taken + 1)
  end

  defp average(values, size, :simple) do
    Enum.sum(values) / size
  end

  defp average(values, size, :weighted) do
    quotient = values
      |> Stream.with_index()
      |> Enum.reduce(0, fn {val, idx}, acc -> acc + val * (size - idx) end)

    quotient / Enum.sum((size..1))
  end

  # @see https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Computing_shifted_data
  defp variance(xs, size) do
    k = List.first xs

    {sum, sum_sqr} = Enum.reduce(xs, {0, 0}, fn x, {sum, sum_sqr} ->
      {sum + x - k, sum_sqr + :math.pow(x - k, 2)}
    end)

    (sum_sqr - (sum * sum) / size) / (size - 1)
  end

  # @see https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Covariance
  defp covariance(xs, ys, size) do
    kx = List.first xs
    ky = List.first ys

    {ex, ey, exy} = Stream.zip(xs, ys)
    |> Enum.reduce({0, 0, 0}, fn {x, y}, {ex, ey, exy} ->
      {ex + x - kx, ey + y - ky, exy + (x - kx) * (y - ky)}
    end)

    (exy - ex * ey / size) / (size - 1)
  end
end
