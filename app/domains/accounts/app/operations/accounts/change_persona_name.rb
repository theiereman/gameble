module Accounts
  class ChangePersonaName < ApplicationOperation
    def call(player:, name:)
      player = step require_player(player)
      name = step clean(name)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player)
        step refuse_steam_name(player)
        next player if player.persona_name == name

        step publish(PersonaNameChanged.new(data: { player_id: player.id }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(persona_name: name)
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.removed? ? Success(player) : Failure(:player_required)
    end

    def clean(name)
      cleaned = PersonaName.clean(name)
      cleaned ? Success(cleaned) : Failure(:invalid_name)
    end

    def refuse_steam_name(player)
      player.identities.exists?(provider: "steam") ? Failure(:name_from_steam) : Success(player)
    end
  end
end
