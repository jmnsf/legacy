defmodule Legacy.Api.CallsTest do
  import Legacy.ExtraAsserts
  use Legacy.RedisCase, async: true
  use Legacy.ExtendedMaru

  @moduletag :api

  describe "POST /calls" do
    test "requires authorization" do
      assert post("/calls").status == 401
    end

    test "returns 200 and the new counts", %{user: user} do
      res =
        auth_conn(user)
        |> add_body(%{feature_name: "ft-api-call-1", new: 2, old: 5, ts: 1483228799000})
        |> post("/calls")

      assert res.status == 200
      assert json_response(res) == %{"data" => %{"new" => 2, "old" => 5}}
    end

    test "increments calls for the given timestamp", %{user: user} do
      auth_conn(user)
        |> add_body(%{feature_name: "ft-api-call-2", new: 5, old: 2, ts: 1483228799000})
      |> post("/calls")

      assert Legacy.Calls.Store.get("ft-api-call-2", 1483228799) == {5, 2}
    end

    test "it increments and returns single calls", %{user: user} do
      assert json_response(
        auth_conn(user)
        |> add_body(%{feature_name: "ft-api-call-3", new: 18, ts: 1483228799000})
        |> post("/calls")
      ) == %{"data" => %{"new" => 18}}

      assert json_response(
        auth_conn(user)
        |> add_body(%{feature_name: "ft-api-call-3", old: 12, ts: 1483228799000})
        |> post("/calls")
      ) == %{"data" => %{"old" => 12}}

      assert Legacy.Calls.Store.get("ft-api-call-3", 1483228799) == {18, 12}
    end

    test "updates the feature stats with the given values", %{user: user} do
      auth_conn(user)
      |> add_body(%{feature_name: "ft-api-call-6", new: 12, old: 11, ts: 1483228799000})
      |> post("/calls")

      stats = Legacy.Feature.Store.show_stats("ft-api-call-6")
      datetime_ts = elem(DateTime.from_unix(1483228799), 1)

      assert stats[:total_new] == 12
      assert stats[:total_old] == 11
      assert stats[:first_call_at] == datetime_ts
      assert stats[:last_call_at] == datetime_ts
    end

    test "validates needed parameters", %{user: user} do
      assert (
        auth_conn(user)
        |> add_body(%{new: 15, ts: 1483228799000})
        |> post("/calls")
      ).resp_body =~ ~r/feature_name.+missing/
      assert (
        auth_conn(user)
        |> add_body(%{new: 15, feature_name: 'valid'})
        |> post("/calls")
      ).resp_body =~ ~r/ts.+missing/
      assert (
        auth_conn(user)
        |> add_body(%{ts: 1483228799000, feature_name: 'valid'})
        |> post("/calls")
      ).resp_body =~ ~r/new.+old/
    end
  end

  describe "GET /calls/aggregate" do
    test "requires authorization" do
      assert get("/calls/aggregate").status == 401
    end

    test "returns 200 and no values", %{user: user} do
      res = auth_conn(user) |> get("/calls/aggregate?feature_name=inexistant&period_granularity=day")

      assert res.status == 200
      json = json_response(res)
      assert json["data"]
      assert json["data"]["new"] == [0]
      assert json["data"]["old"] == [0]
      assert_date_approx List.first(json["data"]["ts"]), DateTime.utc_now, 86400000
    end

    test "returns the requested amount of data with values, when they exist", %{user: user} do
      now = DateTime.to_unix DateTime.utc_now
      Legacy.Calls.Store.incr("ft-api-call-5", now, {1, 3})
      Legacy.Calls.Store.incr("ft-api-call-5", now - 86400, {2, 2})
      Legacy.Calls.Store.incr("ft-api-call-5", now - 7 * 86400, {3, 1})
      Legacy.Calls.Store.incr("ft-api-call-5", now - 8 * 86400, {4, 2})

      json =
        auth_conn(user)
        |> put_body_or_params(%{
          feature_name: "ft-api-call-5",
          period_granularity: "week",
          periods: 2,
          from: now,
        })
        |> get("/calls/aggregate")
        |> json_response()

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
    test "works like rooted call, extracting name from route", %{user: user} do
      res =
        auth_conn(user)
        |> add_body(%{new: 2, old: 5, ts: 1483228799000})
        |> post("/features/ft-api-call-4/calls")

      assert res.status == 200
      assert json_response(res) == %{"data" => %{"new" => 2, "old" => 5}}
      assert Legacy.Calls.Store.get("ft-api-call-4", 1483228799) == {2, 5}
    end
  end
end
