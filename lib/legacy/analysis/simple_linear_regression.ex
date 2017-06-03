defmodule Legacy.Analysis.SimpleLinearRegression do
  @moduledoc """
  A module for building a Simple Linear Regression model based off one set
  of independent variables.

  Implements the Regression protocol.

  @see https://en.wikipedia.org/wiki/Ordinary_least_squares (non-robust)
  @see https://en.wikipedia.org/wiki/Ordinary_least_squares#Simple_regression_model
  @see https://en.wikipedia.org/wiki/Theil%E2%80%93Sen_estimator (robust)
  """

  @enforce_keys [:alfa, :beta]
  defstruct [:alfa, :beta]

  alias Legacy.Analysis

  @doc """
  Given a sample of dependent variables, `ys`, and the corresponding set of
  independent variables, `xs`, calculates and returns a SimpleRegressionModel
  that predicts values based off this sample.

  ## Examples:

      iex> Legacy.Analysis.Regression.predict(
        Legacy.Analysis.SimpleRegressionModel.build([1, 2, 3], [4, 5, 6]),
        4
      )
      7.0
  """
  @spec build([number], [number], non_neg_integer) :: __MODULE__
  def build(xs, ys, size) do
    beta = covariance(xs, ys, size) / variance(xs, size)

    %__MODULE__{
      beta: beta,
      alfa: Analysis.average(ys, size) - beta * Analysis.average(xs, size)
    }
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

defimpl Legacy.Analysis.Regression, for: Legacy.Analysis.SimpleLinearRegression do
  alias Legacy.Analysis.SimpleLinearRegression

  def predict(%SimpleLinearRegression{alfa: alfa, beta: beta}, x), do: alfa + beta * x

  def invert(%SimpleLinearRegression{alfa: alfa, beta: beta}, y) do
    if beta == 0 do
      nil
    else
      (y - alfa) / beta
    end
  end
end
