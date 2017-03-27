defmodule Maru.Types.Timestamp do
  use Maru.Type

  @doc """
  Parses some input into a Unix timestamp with seconds precision. Accepts
  ISO8601 or a Unix timestamp in seconds or milliseconds precision.

  ## Examples:

      iex> Maru.Types.Timestamp.parse("2017-03-26T23:29:46.373+00:00", [])
      1490570986

      iex> Maru.Types.Timestamp.parse("2017-03-27T22:11:30.039596Z", [])
      1490652690

      iex> Maru.Types.Timestamp.parse("1490570986", [])
      1490570986

      iex> Maru.Types.Timestamp.parse("1490570986424", [])
      1490570986

      iex> Maru.Types.Timestamp.parse(1490570986424, [])
      1490570986

      iex> Maru.Types.Timestamp.parse(1490570986, [])
      1490570986

  """
  def parse(input, _) do
    case DateTime.from_iso8601 input do
      {:ok, time, _} -> DateTime.to_unix time
      {:error, _} -> parse_unix input
    end
  end

  defp parse_unix(input) when byte_size(input) == 10 do
    String.to_integer input
  end

  defp parse_unix(input) when byte_size(input) == 13 do
    parse_unix String.to_integer(input)
  end

  defp parse_unix(input) when is_integer(input) and input > 1000000000000 do
    round input / 1000
  end

  defp parse_unix(input) when is_integer(input) do
    input
  end
end
