defmodule Legacy.Api.Controllers.Features do
  def breakdown(params) do
    rate_analysis = Legacy.Calls.analyse(
      params[:feature_name],
      Map.to_list(Map.delete(params, :feature_name))
    )

    case rate_analysis[:analysis] do
      [] -> %{rate: [], trendline: [], ts: []}
      _ ->
        ts = Enum.drop rate_analysis[:ts], 2
        rate = Legacy.Analysis.moving_average rate_analysis[:analysis], 3, :weighted
        regression = Legacy.Analysis.simple_regression_model ts, rate

        %{
          rate: rate,
          trendline: Enum.map(ts, &regression.(&1)),
          ts: ts
        }
    end
  end
end
