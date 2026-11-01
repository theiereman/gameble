class SyncSteamLibraryJob < ApplicationJob
  queue_as :steam_library

  def perform(player_id, token)
    player = Accounts::PlayerById.call(player_id)
    return if player.nil? || player.banned? || player.deleted?

    steam_id = Accounts::SteamIdOf.call(player)
    return if steam_id.nil?

    sync(player, token, Steam::OwnedGames.call(steam_id:))
  end

  private

  def sync(player, token, owned)
    if owned.success?
      Game::SyncLibrarySet.new.call(player:, token:, card_ids: owned.value!)
    elsif owned.failure == :library_private
      Game::MarkLibraryPrivate.new.call(player:, token:)
    end
  end
end
