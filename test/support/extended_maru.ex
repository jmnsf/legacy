defmodule Legacy.ExtendedMaru do
  @moduledoc """
  Adds a few extra function helpers for testing using the Maru framework. Use
  it as you would Maru.Test, ie:

    `use Legacy.ExtendedMaru, for: An.Api.Module`
  """

  defmacro __using__(opts) do
    quote do
      use Maru.Test, unquote(opts)
      unquote(add_json_body())
    end
  end

  defp add_json_body() do
    # TODO: DRY this by iterating patch, put, post
    quote do
      @doc """
      Makes a POST request with the given body. Correctly encodes the body in the
      requested format and sets Content-Type headers.

      ## Parameters

        - url: The URL for the POST request
        - body: The body to send on the request
        - opts: For customizing function behaviour:
          - format: What format to send the body in. Defaults to 'json'.

      """
      @spec post_body(String.t, map(), keyword(String.t)) :: Plug.Conn.t
      def post_body(url, body, opts \\ []) do
        sendable_body(body, opts)
        |> post(url)
      end

      @spec patch_body(String.t, map(), keyword(String.t)) :: Plug.Conn.t
      def patch_body(url, body, opts \\ []) do
        sendable_body(body, opts)
        |> patch(url)
      end

      def sendable_body(body, opts) do
        format = opts[:format] || "json"

        build_conn()
        |> add_content(body, format)
      end

      def add_content(conn, body, "json") do
        Plug.Conn.put_req_header(conn, "content-type", "application/json")
        |> put_body_or_params(Poison.encode! body)
      end
    end
  end
end
