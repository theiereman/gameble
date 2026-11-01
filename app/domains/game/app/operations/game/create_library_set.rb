module Game
  class CreateLibrarySet < Operation
    include CustomSetSteps

    def call(player:)
      player = step require_player(player)
      step steam_identity(player)

      transaction do
        step lock_bank(player)
        CustomSet.steam_library.find_by(player_id: player.id) || created(player)
      end
    end

    private

    def steam_identity(player)
      Accounts::SteamIdOf.call(player) ? Success() : Failure(:steam_identity_required)
    end

    def created(player)
      library_set = CustomSet.create!(player_id: player.id, kind: CustomSet::STEAM_LIBRARY)
      step published(LibrarySetCreated, player, library_set)
      library_set
    end
  end
end
