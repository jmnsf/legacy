defmodule Legacy.Api.CallsTest do
  import Legacy.ExtraAsserts
  use Legacy.RedisCase, async: true
  use Legacy.ExtendedMaru, for: Legacy.Api |> Legacy.Api.Calls

  @moduletag :api

  describe "POST /" do
    test "returns 200 and the new counts" do
      res = post_body "/", %{feature_name: "ft-api-call-1", new: 2, old: 5, ts: 1483228799000}

      assert res.status == 200
      assert json_response(res) == %{"data" => %{"new" => 2, "old" => 5}}
    end

    test "increments calls for the given timestamp" do
      post_body "/", %{feature_name: "ft-api-call-2", new: 5, old: 2, ts: 1483228799000}

      assert Legacy.Calls.Store.get("ft-api-call-2", 1483228799) == {5, 2}
    end

    test "it increments and returns single calls" do
      assert json_response(
        post_body "/", %{feature_name: "ft-api-call-3", new: 18, ts: 1483228799000}
      ) == %{"data" => %{"new" => 18}}

      assert json_response(
        post_body "/", %{feature_name: "ft-api-call-3", old: 12, ts: 1483228799000}
      ) == %{"data" => %{"old" => 12}}

      assert Legacy.Calls.Store.get("ft-api-call-3", 1483228799) == {18, 12}
    end

    test "validates needed parameters" do
      assert_raise Maru.Exceptions.InvalidFormat, ~r/feature_name/, fn ->
        post_body("/", %{new: 15, ts: 1483228799000})
      end

      assert_raise Maru.Exceptions.Validation, ~r/feature_name/, fn ->
        post_body("/", %{new: 15, ts: 1483228799000, feature_name: 'bang!'})
      end

      assert_raise Maru.Exceptions.InvalidFormat, ~r/ts/, fn ->
        post_body("/", %{new: 15, feature_name: 'valid'})
      end

      assert_raise Maru.Exceptions.Validation, ~r/new.+old/, fn ->
        post_body("/", %{ts: 1483228799000, feature_name: 'valid'})
      end
    end
  end

  describe "GET /aggregate" do
    test "returns 200 and no values" do
      res = get "/aggregate?feature_name=inexistant&period_granularity=day"

      assert res.status == 200
      json = json_response(res)
      assert json["data"]
      assert json["data"]["new"] == [0]
      assert json["data"]["old"] == [0]
      assert_date_approx List.first(json["data"]["ts"]), DateTime.utc_now, 86400000
    end

    test "returns the requested amount of data with values, when they exist" do
      now = DateTime.to_unix DateTime.utc_now
      Legacy.Calls.Store.incr("ft-api-call-5", now, {1, 3})
      Legacy.Calls.Store.incr("ft-api-call-5", now - 86400, {2, 2})
      Legacy.Calls.Store.incr("ft-api-call-5", now - 7 * 86400, {3, 1})
      Legacy.Calls.Store.incr("ft-api-call-5", now - 8 * 86400, {4, 2})

      url = "aggregate?feature_name=ft-api-call-5&period_granularity=week&periods=2&from=#{now}"
      json = json_response(get url)

      assert json["data"]
      assert json["data"]["new"] == [7, 3]
      assert json["data"]["old"] == [3, 5]
      assert_date_approx Enum.at(json["data"]["ts"], 0), now - 14 * 86400, 86400000
      assert_date_approx Enum.at(json["data"]["ts"], 1), now - 7 * 86400, 86400000
    end
  end
end

defmodule Legacy.Api.NestedCallsTest do
  use Legacy.RedisCase, async: true
  use Legacy.ExtendedMaru, for: Legacy.Api.Features |> Legacy.Api.Calls

  @moduletag :api

  describe "POST /features/:feature_name/calls" do
    test "works like rooted call, extracting name from route" do
      # REVIEW: There's no way to test route params on nested routers, afaik
      res = post_body "/?feature_name=ft-api-call-4", %{new: 2, old: 5, ts: 1483228799000}

      assert res.status == 200
      assert json_response(res) == %{"data" => %{"new" => 2, "old" => 5}}
      assert Legacy.Calls.Store.get("ft-api-call-4", 1483228799) == {2, 5}
    end
  end
end
