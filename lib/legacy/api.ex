defmodule Legacy.Api do
  require Logger
  use Maru.Router

  plug Plug.Parsers,
    pass: ["*/*"],
    json_decoder: Poison,
    parsers: [:json] # add here :urlencoded or :multipart as needed

  namespace :features, do: mount Legacy.Api.Features

  rescue_from Maru.Exceptions.NotFound do
    conn
    |> put_status(404)
    |> text("Not Found")
  end

  rescue_from :all, as: e do
    Logger.error "[Router] Caught Server Error #{inspect e}. Returning 500."

    conn
    |> put_status(500)
    |> text("Server Error")
  end
end
