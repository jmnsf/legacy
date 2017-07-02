defmodule Legacy.Api.Middleware.Authenticate do
  use Maru.Middleware

  def call(conn, _opts) do
    IO.puts("in authenticate")
    with [authorization | _] <- get_req_header(conn, "authorization"),
         ["Bearer", api_key] <- String.split(authorization)
    do
      authenticate_user(conn, api_key)
    else
      _ -> conn
    end
  end

  defp authenticate_user(conn, api_key) do
    assign(conn, :user, Legacy.User.find_by_key(api_key))
  end
end
