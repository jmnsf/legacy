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

  params do
    use :feature_name
    use :feature_attributes
  end

  desc "creates a new feature"
  post do
    if Legacy.Features.Store.exists(params[:feature_name]) do
      conn
      |> put_status(409)
      |> json(%{ errors: ["A Feature with this name already exists."] })
    else
      Legacy.Features.init(
        params[:feature_name],
        Map.to_list(Map.delete(params, :feature_name))
      )

      conn
      |> put_status(201)
      |> json(%{data: Legacy.Features.Store.show params[:feature_name]})
    end
  end

  route_param :feature_name do
    desc "gets the feature with the given name"
    params do
      use :feature_name
    end
    get do
      feature = Legacy.Features.Store.show params[:feature_name]

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
      case Legacy.Features.Store.exists(params[:feature_name]) do
        false -> put_status conn, 404
        true ->
          Legacy.Features.Store.update(
            params[:feature_name],
            Map.to_list(Map.delete(params, :feature_name))
          )

          conn
          |> put_status(200)
          |> json(%{data: Legacy.Features.Store.show params[:feature_name]})
      end
    end

    namespace :calls, do: mount Legacy.Api.Calls
  end
end
