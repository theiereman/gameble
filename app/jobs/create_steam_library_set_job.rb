class CreateSteamLibrarySetJob < ApplicationJob
  queue_as :default

  def perform(player_id)
    Game::CreateLibrarySet.new.call(player: Accounts::PlayerById.call(player_id))
  end
end
