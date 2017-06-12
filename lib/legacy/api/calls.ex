defmodule Legacy.Api.Calls do
  use Maru.Router

  alias Legacy.Feature
  alias Legacy.Calls

  helpers Legacy.Api.SharedParams

  desc "registers feature calls"

  params do
    use :feature_name
    requires :ts, type: Timestamp
    optional :new, type: Integer
    optional :old, type: Integer
    at_least_one_of [:new, :old]
  end

  post do
    response = case Enum.map([:new, :old], &Map.has_key?(params, &1)) do
      [true, true] ->
        {new, old} = Calls.Store.incr(
          params[:feature_name], params[:ts], {params[:new], params[:old]}
        )
        %{new: new, old: old}
      [false, true] ->
        %{old: Calls.Store.incr_old(params[:feature_name], params[:ts], params[:old])}
      [true, false] ->
        %{new: Calls.Store.incr_new(params[:feature_name], params[:ts], params[:new])}
    end

    Feature.Store.update_stats(params[:feature_name], {params[:new], params[:old]}, params[:ts])

    conn |> json(%{data: response})
  end

  namespace :aggregate do
    desc "aggregates and returns feature calls"

    params do
      use :feature_name
      use :timeseries_range
      optional :aggregation, type: Atom, values: [:sum, :avg]
    end

    get do
      response = Calls.aggregate(
        params[:feature_name],
        params |> Map.drop([:feature_name]) |> Map.to_list()
      )

      conn |> json(%{data: response})
    end
  end
end
