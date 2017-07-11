defmodule Legacy.Api.Middleware.AuthorizeTest do
  use ExUnit.Case, async: true

  describe "Legacy.Api.Middleware.Authorize.call/2" do
    test "Raises when connection has no user assigned" do
      assert_raise Maru.Exceptions.Unauthorized, fn ->
        Legacy.Api.Middleware.Authorize.call(struct(%Plug.Conn{}), %{})
      end
    end

    test "Raises when connection has nil user assigned" do
      assert_raise Maru.Exceptions.Unauthorized, fn ->
        struct(%Plug.Conn{})
        |> Plug.Conn.assign(:user, nil)
        |> Legacy.Api.Middleware.Authorize.call(%{})
      end
    end

    test "Returns the connection when a user is assigned" do
      ret = struct(%Plug.Conn{})
      |> Plug.Conn.assign(:user, struct %Legacy.User{})
      |> Legacy.Api.Middleware.Authorize.call(%{})

      assert ret.__struct__ == Plug.Conn
    end
  end
end
