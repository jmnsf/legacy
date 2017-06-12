defmodule Legacy.Email do
  require Logger

  def notify_threshold_reached(email_address, feature_name, threshold) do
    html = Legacy.Mailer.deliver_now(
      Legacy.View.Email.threshold_notification email_address, feature_name, threshold
    )
    {:ok, html}
  end
end
