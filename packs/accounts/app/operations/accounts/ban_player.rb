module Accounts
  class BanPlayer < ApplicationOperation
    include ModerationSteps

    def call(actor:, player:)
      actor = step require_staff(actor)
      player = step require_target(player)

      transaction do
        actor = step reread_staff(actor)
        step lock_target(player)
        step may_ban(actor, player)
        step publish(PlayerBanned.new(data: { player_id: player.id }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(banned_at: Time.current)
        player
      end
    end

    private

    def may_ban(actor, player)
      return Failure(:cannot_ban_self) if actor == player
      return Failure(:cannot_ban_administrator) if player.administrator?
      return Failure(:already_banned) if player.banned?

      Success(player)
    end
  end
end
