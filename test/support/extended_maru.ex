defmodule Legacy.ExtendedMaru do
  @moduledoc """
  Adds a few extra function helpers for testing using the Maru framework. Use
  it as you would Maru.Test, ie:

    `use Legacy.ExtendedMaru, for: An.Api.Module`
  """

  defmacro __using__(opts) do
    quote do
      use Maru.Test, unquote(opts)
      setup_all do
        {:ok, user: Legacy.User.register()}
      end

      def body_conn(body, opts \\ []), do: build_conn() |> add_body(body, opts)

      def add_body(conn, body, opts \\ []) do
        format = opts[:format] || "json"
        add_content(conn, body, format)
      end

      def auth_conn(user) do
        build_conn()
        |> put_req_header("authorization", "Bearer #{user.api_key}")
      end

      defp add_content(conn, body, "json") do
        Plug.Conn.put_req_header(conn, "content-type", "application/json")
        |> put_body_or_params(Poison.encode! body)
      end
    end
  end
end
