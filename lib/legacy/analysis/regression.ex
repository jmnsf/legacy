defprotocol Legacy.Analysis.Regression do
  @doc """
  Given an independent variable `x`, returns the predicted value for the
  dependent variable according to the Regression model.
  """
  def predict(model, x)

  @doc """
  Given a dependent variable `y`, returns the independent `x` value that will
  yield it, if one exists. Returns `nil` if one doesn't.
  """
  def invert(model, y)
end
