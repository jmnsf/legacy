defmodule Mix.Tasks.Legacy.NotifyThresholds do
  use Mix.Task

  require Logger

  @shortdoc "Sends all notifications for features that reached their thresholds"

  def run(_) do
    {:ok, _started} = Application.ensure_all_started(:httpoison)

    Logger.info "[NotifyThresholds] Starting..."

    Legacy.Feature.Tasks.notify_thresholds()

    Logger.info "[NotifyThresholds] Done."
  end
end
