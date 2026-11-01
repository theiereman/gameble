class SyncSteamLibrariesJob < ApplicationJob
  queue_as :default

  def perform
    due = Game::LibrarySetsDue.call(limit: Rails.configuration.x.steam.library_daily_syncs)
    ActiveJob.perform_all_later(due.map { |player_id, token| SyncSteamLibraryJob.new(player_id, token) })
  end
end
