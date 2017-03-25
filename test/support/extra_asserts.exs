defmodule Legacy.ExtraAsserts do
  import ExUnit.Assertions, only: [assert_in_delta: 3]

  def assert_date_approx(date1, date2, ms_delta \\ 100)

  def assert_date_approx(date1, date2, ms_delta) when is_bitstring(date1) do
    assert_date_approx elem(DateTime.from_iso8601(date1), 1), date2, ms_delta
  end

  def assert_date_approx(date1, date2, ms_delta) when is_bitstring(date2) do
    assert_date_approx date1, elem(DateTime.from_iso8601(date2), 1), ms_delta
  end

  def assert_date_approx(date1, date2, ms_delta) do
    date1_ms = DateTime.to_unix(date1, :millisecond)
    date2_ms = DateTime.to_unix(date2, :millisecond)

    assert_in_delta(date1_ms, date2_ms, ms_delta)
  end
end
