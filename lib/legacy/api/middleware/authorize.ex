defmodule Legacy.Api.Middleware.Authorize do
  use Maru.Middleware

  def call(conn, _opts) do
    if conn.assigns[:user] == nil do
      raise Maru.Exceptions.Unauthorized
    else
      conn
    end
  end
end
