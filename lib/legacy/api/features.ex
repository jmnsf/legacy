defmodule Legacy.Api.Features do
  use Maru.Router

  helpers Legacy.Api.SharedParams

  helpers do
    params :feature_attributes do
      optional :description, type: String
      optional :expire_period, type: Integer
      optional :rate_threshold, type: Float, between: {0, 1}
      optional :alert_endpoint, type: String
      optional :alert_email, type: String
    end
  end

  plug Legacy.Api.Middleware.Authorize

  desc "creates a new feature"
  params do
    use :feature_name
    use :feature_attributes
  end
  post do
    if Legacy.Feature.Store.exists(params[:feature_name]) do
      conn
      |> put_status(409)
      |> json(%{ errors: ["A Feature with this name already exists."] })
    else
      Legacy.Feature.init(
        params[:feature_name],
        Map.to_list(Map.delete(params, :feature_name))
      )

      conn
      |> put_status(201)
      |> json(%{data: Legacy.Feature.Store.show params[:feature_name]})
    end
  end

  route_param :feature_name do
    desc "gets the feature with the given name"
    params do
      use :feature_name
    end
    get do
      feature = Legacy.Feature.Store.show params[:feature_name]

      case feature do
        nil -> put_status conn, 404
        _ -> json conn, feature
      end
    end

    desc "updates an existing feature"
    params do
      use :feature_name
      use :feature_attributes
    end
    patch do
      case Legacy.Feature.Store.exists(params[:feature_name]) do
        false -> put_status conn, 404
        true ->
          Legacy.Feature.update(
            params[:feature_name],
            Map.to_list(Map.delete(params, :feature_name))
          )

          conn
          |> put_status(200)
          |> json(%{data: Legacy.Feature.Store.show params[:feature_name]})
      end
    end

    namespace :breakdown do
      desc "returns a breakdown analysis of this feature"
      params do
        use :feature_name
        use :timeseries_range
      end
      get do
        case Legacy.Feature.Store.exists(params[:feature_name]) do
          false -> put_status conn, 404
          true ->
            data = Legacy.Api.Controllers.Features.breakdown(
              default_breakdown_params params
            )

            conn
            |> put_status(200)
            |> json(%{data: data})
        end
      end
    end

    resources :calls, do: mount Legacy.Api.Calls
  end

  # Returns 7 periods by default, or whatever value is requested. Because we're
  # calculating a 3-step moving average, 2 more "periods" need to be requested.
  defp default_breakdown_params(params) do
    params
    |> Map.put_new(:period_granularity, :day)
    |> Map.update(:periods, 9, &(&1 + 2))
  end
end
