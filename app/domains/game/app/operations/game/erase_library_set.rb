module Game
  class EraseLibrarySet < Operation
    def call(player:)
      player = step require_account(player)

      transaction do
        BankLock.acquire(player.id)
        CustomSet.steam_library.where(player_id: player.id).delete_all
        Market::RefreshWanted.call(player)
      end
    end
  end
end
