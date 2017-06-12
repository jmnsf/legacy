defmodule Legacy.View.Email do
  import Bamboo.Email

  @doc """
  Builds an email for notifying that a threshold has been reached.
  """
  @spec threshold_notification(String.t, String.t, number) :: %Bamboo.Email{}
  def threshold_notification(email_address, feature_name, threshold) do
    {html, text} = render_threshold_reached(feature_name, threshold)

    new_email(
      from: from(),
      to: email_address,
      subject: "Threshold reached for #{feature_name}",
      html_body: html,
      text_body: text
    )
  end

  defp render_threshold_reached(feature_name, threshold) do
    render_context = %{feature_name: feature_name, threshold: threshold}
    {
      Mustache.render(
        File.read!("views/emails/notifyThresholdReached.html.mustache"),
        render_context
      ),
      Mustache.render(
        File.read!("views/emails/notifyThresholdReached.text.mustache"),
        render_context
      )
    }
  end

  defp from do
    Keyword.fetch! Application.fetch_env!(:legacy, Legacy.Email), :from
  end
end
