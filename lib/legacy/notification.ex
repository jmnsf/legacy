defmodule Legacy.Notification do
  @moduledoc """
  Functions for sending notifications, whether email or webhooks.
  """

  alias Legacy.Notification

  @doc """
  Triggers all threshold notifications for the given feature. This function will
  return a successful result `{:ok, _}` if at least one notification is successful.

  The resulting tuple contains both email and notification returns so that they
  can be handled by the caller.
  """
  @spec notify_threshold_reached(Map.t) ::
    {:ok, email: {atom, any}, webhook: {atom, any}} |
    {:error, %Notification.Error{}}
  def notify_threshold_reached(%Legacy.Feature{} = feature) do
    email_task = Task.async(fn -> notify_email(feature) end)
    webhook_task = Task.async(fn -> notify_webhook(feature) end)

    email_result = Task.await email_task
    webhook_result = Task.await webhook_task

    case {email_result, webhook_result} do
      {{:error, email_err}, {:error, webhook_err}} ->
        {:error, struct(%Notification.Error{}, email_msg: email_err, webhook_msg: webhook_err)}
      {_, _} ->
        {:ok, email: email_result, webhook: webhook_result}
    end
  end

  defp notify_email(%Legacy.Feature{alert_email: nil}), do: {:error, "No email to notify."}
  defp notify_email(%Legacy.Feature{} = feature) do
    try do
      Legacy.Email.notify_threshold_reached(
        feature.alert_email, feature.name, feature.rate_threshold
      )
    rescue
      err -> {:error, "Error caught in email notification: #{inspect err}"}
    end
  end

  defp notify_webhook(%Legacy.Feature{alert_endpoint: nil}), do: {:error, "No endpoint to notify."}
  defp notify_webhook(%Legacy.Feature{} = feature) do
    try do
      Legacy.Webhook.notify_threshold_reached(
        feature.alert_endpoint, feature.name, feature.rate_threshold
      )
    rescue
      err -> {:error, "Error caught in webhook notification: #{inspect err}"}
    end
  end
end
