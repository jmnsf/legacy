defmodule Legacy.Webhook do
  @moduledoc """
  Module that handles outgoing webhook notifications.
  """

  require Logger

  @doc """
  Notifies the saved endpoint that a certain old/new threshold has been reached
  by `feature_name`.
  """
  @spec notify_threshold_reached(String.t, String.t, number) :: {atom, String.t | nil}
  def notify_threshold_reached(endpoint, feature_name, threshold) do
    payload = Poison.encode! %{
      meta: %{
        topic: "threshold.reached"
      },
      data: %{
        feature_name: feature_name,
        threshold: threshold
      }
    }

    case HTTPoison.post endpoint, payload, headers() do
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        cond do
          status >= 200 and status < 300 -> {:ok, nil}
          true -> {:error, "Non 200 status returned from endpoint: #{status} - #{inspect body}"}
        end
      {:error, %HTTPoison.Error{id: id, reason: reason}} ->
        {:error, "HTTP error during request: id - #{id}, reason - #{reason}"}
      {:error, err} -> {:error, "Error doing request: #{inspect err}"}
    end
  end

  @doc """
  Same as `notify_threshold_reached` but raises on error.
  """
  @spec notify_threshold_reached!(String.t, String.t, number) :: {atom, String.t | nil}
  def notify_threshold_reached!(endpoint, feature_name, threshold) do
    case notify_threshold_reached(endpoint, feature_name, threshold) do
      {:ok, ret} -> ret
      {:error, error} -> raise error
    end
  end

  defp headers, do: [{"Content-Type", "application/json"}]
end
