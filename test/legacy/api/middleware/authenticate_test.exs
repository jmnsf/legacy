defmodule Legacy.Api.Middleware.AuthenticateTest do
  use ExUnit.Case, async: true

  describe "Legacy.Api.Middleware.Authenticate.call/2" do
    test "assigns user to connection when Authorization is Bearer with API key" do
      user = Legacy.User.register()
      conn =
        struct(%Plug.Conn{}, req_headers: [{"authorization", "Bearer #{user.api_key}"}])
        |> Legacy.Api.Middleware.Authenticate.call(%{})

      assert conn.assigns[:user]
      assert conn.assigns[:user].id == user.id
    end

    # The next tests basically assert that the Middleware won't shit the bed and
    # break the whole request due to some missing or malformed info.

    test "does not assign user when no Authorization header is given" do
      conn =
        struct(%Plug.Conn{})
        |> Legacy.Api.Middleware.Authenticate.call(%{})

      assert conn.assigns[:user] == nil
    end

    test "does not assign user when Authorization is not Bearer type" do
      user = Legacy.User.register()
      conn =
        struct(%Plug.Conn{}, req_headers: [{"authorization", "Basic #{user.api_key}"}])
        |> Legacy.Api.Middleware.Authenticate.call(%{})

      assert conn.assigns[:user] == nil
    end

    test "does not assign user when Authorization is malformed" do
      user = Legacy.User.register()
      conn =
        struct(%Plug.Conn{}, req_headers: [{"authorization", "#{user.api_key}"}])
        |> Legacy.Api.Middleware.Authenticate.call(%{})

      assert conn.assigns[:user] == nil
    end

    test "does not assign user when API key is unknown" do
      conn =
        struct(%Plug.Conn{}, req_headers: [{"authorization", "Bearer lekey"}])
        |> Legacy.Api.Middleware.Authenticate.call(%{})

      assert conn.assigns[:user] == nil
    end
  end
end
