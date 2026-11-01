module Game
  class EraseLibrarySet < Operation
    def call(player:)
      player = step require_account(player)

      transaction do
        BankLock.acquire(player.id)
        CustomSet.steam_library.where(player_id: player.id).delete_all
      end
    end
  end
end
