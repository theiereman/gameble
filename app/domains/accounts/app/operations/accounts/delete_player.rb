module Accounts
  class DeletePlayer < ApplicationOperation
    def call(player:, allow_banned: false)
      player = step require_player(player, allow_banned:)

      transaction do
        # Locked before the delete event: its handlers take the bank lock, so this order cannot deadlock with an opening.
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player, allow_banned:)
        step publish(PlayerDeleted.new(data: { player_id: player.id }), stream_name: "Accounts::Player$#{player.id}")
        DataExport.where(player_id: player.id).delete_all
        player.update!(steam_id: nil, persona_name: nil, last_seen_at: nil, last_exported_at: nil, token: Player.generate_unique_secure_token,
          deleted_at: Time.current)
        player
      end
    end

    private

    def require_player(player, allow_banned:)
      player.is_a?(Player) && player.persisted? && (allow_banned || !player.banned?) && !player.deleted? ? Success(player) : Failure(:player_required)
    end
  end
end
