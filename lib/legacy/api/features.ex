defmodule Legacy.Api.Features do
  use Maru.Router

  helpers do
    params :feature_name do
      requires :name, type: String, regexp: ~r/^[\w_-]+$/
    end
  end

  params do
    use :feature_name
    optional :description, type: String
    optional :expire_period, type: Integer
  end

  desc "creates a new feature"
  post do
    if Legacy.Features.exists(params[:name]) do
      conn = put_status conn, 409
      json(conn, %{ errors: ["A Feature with this name already exists."] })
    else
      Legacy.Features.init(
        params[:name],
        Map.to_list(Map.delete(params, :name))
      )

      conn
      |> put_status(201)
      |> json(%{data: Legacy.Features.show params[:name]})
    end
  end

  route_param :name do
    desc "gets the feature with the given name"

    params do
      use :feature_name
    end

    get do
      feature = Legacy.Features.show params[:name]

      case feature do
        nil -> put_status conn, 404
        _ -> json conn, feature
      end
    end

    # namespace :calls, do: mount Legacy.Api.Calls
  end
end
