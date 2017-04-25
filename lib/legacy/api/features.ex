defmodule Legacy.Api.Features do
  use Maru.Router

  helpers Legacy.Api.SharedParams

  params do
    use :feature_name
    optional :description, type: String
    optional :expire_period, type: Integer
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
    params do
      use :feature_name
    end

    desc "gets the feature with the given name"
    get do
      feature = Legacy.Features.Store.show params[:feature_name]

      case feature do
        nil -> put_status conn, 404
        _ -> json conn, feature
      end
    end

    namespace :calls, do: mount Legacy.Api.Calls
  end
end
