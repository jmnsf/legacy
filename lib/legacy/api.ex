defmodule Legacy.Api do
  require Logger
  use Maru.Router

  plug Plug.Parsers,
    pass: ["*/*"],
    json_decoder: Poison,
    parsers: [:json] # add here :urlencoded or :multipart as needed

  resources :features, do: mount Legacy.Api.Features
  resources :calls, do: mount Legacy.Api.Calls

  rescue_from Maru.Exceptions.NotFound do
    conn
    |> put_status(404)
    |> text("Not Found")
  end

  rescue_from Maru.Exceptions.InvalidFormat, as: err do
    reason = case err do
      %{reason: :required} -> "is missing"
      _ -> "invalid"
    end

    conn
    |> put_status(400)
    |> json(%{errors: ["Parameter `#{err.param}` #{reason}"]})
  end

  rescue_from Maru.Exceptions.Validation, as: err do
    conn
    |> put_status(400)
    |> json(%{errors: [
      "Parameter `#{err.param}` is invalid. Expected `#{inspect err.option}`, got `#{err.value}`"
    ]})
  end

  rescue_from Plug.Parsers.ParseError, as: err do
    conn
    |> put_status(400)
    |> json(%{errors: ["Error parsing request: #{inspect err}"]})
  end

  rescue_from :all, as: e do
    Logger.error "[Router] Caught Server Error #{Exception.format(:error, e)}. Returning 500."

    conn
    |> put_status(500)
    |> text("Server Error")
  end
end
