module Accounts
  # Deletes a player's account (CAP-14, AD-14). The record stays, as the
  # target of the rows that name it, but is anonymised: the Steam id is
  # released (the same Steam account signs up again as a new player), the
  # persona name, the last-seen and last-export times are erased, the public token is
  # replaced (every link that named the player leads nowhere) and
  # `deleted_at` is set, which also rotates the private stream key.
  #
  # In one transaction: the player row is locked FOR NO KEY UPDATE, which
  # serialises two deletions of one player (the second finds the record
  # deleted and is refused) without blocking an opening in flight, whose
  # inserts only take FOR KEY SHARE on the row. Then Accounts::PlayerDeleted
  # is published and Game releases what the player holds
  # (Game::Handlers::PlayerDeleted), taking the bank lock first as AD-10's
  # lock order asks. Only then is the record anonymised: that UPDATE changes
  # unique columns, so it locks the row FOR UPDATE, which an opening holding
  # the bank lock would have waited on while the deletion waited on its bank
  # lock.
  #
  # The typed confirmation word is the web layer's.
  #
  #   Accounts::DeletePlayer.new.call(player:)
  #   # => Success(player) | Failure(:player_required)
  class DeletePlayer < ApplicationOperation
    def call(player:)
      player = step require_player(player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step require_player(player)
        step publish(PlayerDeleted.new(data: { player_id: player.id }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(steam_id: nil, persona_name: nil, last_seen_at: nil, last_exported_at: nil, token: Player.generate_unique_secure_token,
          deleted_at: Time.current)
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.banned? && !player.deleted? ? Success(player) : Failure(:player_required)
    end
  end
end
