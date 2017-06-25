defmodule Legacy.Api.Users do
  use Maru.Router

  desc "registers a new user"

  post do
    new_user = Legacy.User.register()

    conn
    |> put_status(201)
    |> json(%{data: new_user})
  end
end
