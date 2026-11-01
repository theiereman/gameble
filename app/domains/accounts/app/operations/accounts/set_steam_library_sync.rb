module Accounts
  class SetSteamLibrarySync < ApplicationOperation
    def call(player:, enabled:)
      player = step require_player(player)
      step check(enabled)
      step steam_identity(player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player)
        next player if player.steam_library_sync == enabled

        step publish(SteamLibrarySyncChanged.new(data: { player_id: player.id, enabled: }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(steam_library_sync: enabled)
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.banned? ? Success(player) : Failure(:player_required)
    end

    def check(enabled)
      [ true, false ].include?(enabled) ? Success() : Failure(:invalid_setting)
    end

    def steam_identity(player)
      SteamIdOf.call(player) ? Success() : Failure(:steam_identity_required)
    end
  end
end
