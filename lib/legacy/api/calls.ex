defmodule Legacy.Api.Calls do
  use Maru.Router

  alias Legacy.Calls.Store
  alias Legacy.Calls

  helpers Legacy.Api.SharedParams

  params do
    use :feature_name
    requires :ts, type: Timestamp
    optional :new, type: Integer
    optional :old, type: Integer
    at_least_one_of [:new, :old]
  end

  desc "registers feature calls"
  post do
    response = case Enum.map([:new, :old], &Map.has_key?(params, &1)) do
      [true, true] ->
        {new, old} = Store.incr(
          params[:feature_name], params[:ts], {params[:new], params[:old]}
        )
        %{new: new, old: old}
      [false, true] ->
        %{old: Store.incr_old(params[:feature_name], params[:ts], params[:old])}
      [true, false] ->
        %{new: Store.incr_new(params[:feature_name], params[:ts], params[:new])}
    end

    conn |> json(%{data: response})
  end

  namespace :aggregate do
    params do
      use :feature_name
      optional :from, type: Timestamp
      optional :aggregation, type: Atom, values: [:sum, :avg]
      optional :periods, type: Integer
      optional :period_size, type: Integer
      optional :period_granularity, type: Atom, values: [:day, :week, :month, :year]
    end

    desc "aggregates and returns feature calls"
    get do
      response = Calls.aggregate(
        params[:feature_name],
        params |> Map.drop([:feature_name]) |> Map.to_list()
      )

      conn |> json(%{data: response})
    end
  end
end
