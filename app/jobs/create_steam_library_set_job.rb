class CreateSteamLibrarySetJob < ApplicationJob
  queue_as :default

  def perform(player_id, first_sync: false)
    created = Game::CreateLibrarySet.new.call(player: Accounts::PlayerById.call(player_id))
    SyncSteamLibraryJob.perform_later(player_id, created.value!.token) if first_sync && created.success?
  end
end
