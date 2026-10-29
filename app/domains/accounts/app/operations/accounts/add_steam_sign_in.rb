module Accounts
  class AddSteamSignIn < ApplicationOperation
    PROVIDER = "steam".freeze

    def call(player:, steam_id:, persona_name: nil)
      player = step require_player(player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player)
        step refuse_taken(player, steam_id)
        link(player, steam_id, persona_name) unless player.identities.exists?(provider: PROVIDER, uid: steam_id)
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.removed? ? Success(player) : Failure(:player_required)
    end

    def refuse_taken(player, steam_id)
      taken = Identity.where(provider: PROVIDER, uid: steam_id).where.not(player_id: player.id).exists? ||
        Player.where(steam_id:).where.not(id: player.id).exists?
      return Failure(:steam_taken) if taken
      return Failure(:identity_taken) if player.steam_id && player.steam_id != steam_id

      Success(player)
    end

    def link(player, steam_id, persona_name)
      step AddIdentity.new.call(player:, provider: PROVIDER, uid: steam_id)
      store_persona_name(player, persona_name)
    end

    def store_persona_name(player, persona_name)
      name = PersonaName.clean(persona_name)
      player.update!(persona_name: name) if name && name != player.persona_name
    end
  end
end
