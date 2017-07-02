defmodule Legacy.Api.Middleware.Authorize do
  use Maru.Middleware

  def call(conn, _opts) do
    IO.puts("in authorize #{inspect conn.assigns[:user]}")
    if conn.assigns[:user] == nil do
      raise Maru.Exceptions.Unauthorized
    else
      conn
    end
  end
end
