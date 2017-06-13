defmodule Legacy.Feature.Tasks do
  @moduledoc """
  Complex tasks related to Features.
  """

  alias Legacy.Feature

  require Logger

  @doc """
  Goes through all the Features in the app and notifies those that have reached
  their configured thresholds and have not been notified yet.
  """
  def notify_thresholds(reference_ts \\ nil) do
    from_ts = (reference_ts || DateTime.to_unix DateTime.utc_now) -
      Utils.GranularTime.int_granularity(:day)

    Feature.stream_all_features()
    |> Stream.filter(&feature_notifiable?(&1))
    |> Stream.map(fn feature -> {feature, day_rate(feature.name, from_ts)} end)
    |> Stream.filter(fn {%Feature{rate_threshold: threshold}, rate} -> rate && rate < threshold end)
    |> Task.async_stream(fn {%Feature{} = feature, rate} ->
      notify_feature_threshold feature, rate
    end, timeout: 10000)
    |> Stream.run()
  end

  defp feature_notifiable?(%Feature{notified_at: notif}) when not is_nil(notif), do: false
  defp feature_notifiable?(%Feature{alert_endpoint: nil, alert_email: nil}), do: false
  defp feature_notifiable?(%Feature{}), do: true

  defp day_rate(feature_name, day_ts) do
    case Legacy.Calls.analyse(feature_name, period_granularity: :day, from: day_ts) do
      %{analysis: []} -> nil
      %{analysis: [rate | []]} -> rate
    end
  end

  defp notify_feature_threshold(%Feature{} = feature, rate) do
    Logger.info(
      "[NotifyThresholds] Notifying on feature #{feature.name} " <>
      "(#{rate} < #{feature.rate_threshold})"
    )

    notified_at = DateTime.to_iso8601 DateTime.utc_now

    case Legacy.Notification.notify_threshold_reached feature do
      {:ok, _} -> Feature.Store.update(feature.name, notified_at: notified_at)
      {:error, err} -> Logger.warn("Error sending notification: #{inspect err}")
    end
  end
end
