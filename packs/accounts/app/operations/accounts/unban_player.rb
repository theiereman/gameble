module Accounts
  class UnbanPlayer < ApplicationOperation
    include ModerationSteps

    def call(actor:, player:)
      actor = step require_staff(actor)
      player = step require_target(player)

      transaction do
        step reread_staff(actor)
        step lock_target(player)
        step banned(player)
        step publish(PlayerUnbanned.new(data: { player_id: player.id }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(banned_at: nil)
        player
      end
    end

    private

    def banned(player)
      player.banned? ? Success(player) : Failure(:not_banned)
    end
  end
end
