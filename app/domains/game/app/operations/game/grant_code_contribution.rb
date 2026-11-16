module Game
  class GrantCodeContribution < Operation
    def self.refusal(staff:, player:)
      return :administrator_required unless Accounts::Player.acting_staff?(staff) && staff.administrator?
      return :player_not_found unless player.is_a?(Accounts::Player) && player.persisted? && !player.removed?

      :code_contribution_already_granted if PlayerState.where(player_id: player.id).where.not(code_contribution_at: nil).exists?
    end

    def call(staff:, player:, now: Time.current)
      step permitted(staff, player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        staff = Accounts::Player.lock("FOR SHARE").find_by(id: staff.id)
        step permitted(staff, player)
        PlayerState.insert({ player_id: player.id }, unique_by: :player_id)
        PlayerState.where(player_id: player.id).update_all(code_contribution_at: now, updated_at: now)
        step publish(CodeContributionGranted.new(data: { player_id: player.id, staff_id: staff.id }), stream_name: stream_name(player.id))
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
