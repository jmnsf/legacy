defmodule Legacy.Api.Controllers.Features do
  alias Legacy.Analysis.Regression

  @doc """
  Builds and returns a general breakdown of a Feature's calls. This includes:

  * Last week's old/new call rate & trendline
  * Timestamp prediction for when the threshold will be (or has been) reached (if at all)
  * Global call stats for the Feature
  """
  @spec breakdown(Map.t) :: Map.t
  def breakdown(params) do
    rate_analysis = Legacy.Calls.analyse(
      params[:feature_name],
      Map.to_list(Map.delete(params, :feature_name))
    )

    case rate_analysis[:analysis] do
      [] -> %{rate: [], trendline: [], ts: [], threshold_ts: nil}
      _ ->
        ts = Enum.drop rate_analysis[:ts], 2 # we got 2 extra TS for the weighted average
        rate = Legacy.Analysis.moving_average rate_analysis[:analysis], 3, :weighted
        model = Legacy.Analysis.simple_regression_model ts, rate
        feature = Legacy.Feature.Store.show params[:feature_name]
        predicted_threshold_ts = Regression.invert model, feature.rate_threshold

        %{
          rate: rate,
          trendline: Enum.map(ts, &Regression.predict(model, &1)),
          ts: ts,
          threshold_ts: round(predicted_threshold_ts),
          stats: Legacy.Feature.Store.show_stats(params[:feature_name])
        }
    end
  end
end
