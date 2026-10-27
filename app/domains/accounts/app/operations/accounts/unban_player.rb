module Accounts
  class UnbanPlayer < ApplicationOperation
    def self.refusal(staff:, player:)
      return :staff_required unless Player.acting_staff?(staff)
      return :player_not_found unless player.is_a?(Player) && player.persisted? && !player.deleted?
      return :outranked unless staff.outranks?(player)

      :not_banned unless player.banned?
    end

    def call(staff:, player:)
      step permitted(staff, player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        staff = Player.lock("FOR SHARE").find_by(id: staff.id)
        step permitted(staff, player)
        step publish(PlayerUnbanned.new(data: { player_id: player.id, staff_id: staff.id }), stream_name: "Accounts::Player$#{player.id}")
        player.update!(banned_at: nil)
        ModerationAction.create!(kind: :unban, player:, staff:)
        player
      end
    end

    private

    def permitted(staff, player)
      code = self.class.refusal(staff:, player:)
      code ? Failure(code) : Success()
    end
  end
end
