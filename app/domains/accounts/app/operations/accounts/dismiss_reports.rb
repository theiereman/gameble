module Accounts
  class DismissReports < ApplicationOperation
    def self.refusal(staff:, player:)
      return :staff_required unless Player.acting_staff?(staff)
      return :player_not_found unless player.is_a?(Player) && player.persisted? && !player.deleted?
      return :cannot_dismiss_self if player.id == staff.id

      :outranked unless staff.outranks?(player)
    end

    def call(staff:, player:)
      step permitted(staff, player)

      transaction do
        player.lock!("FOR NO KEY UPDATE")
        step permitted(staff, player)
        now = Time.current
        handled = Report.unhandled.where(reported: player).update_all(handled_at: now, updated_at: now)
        step any_handled(handled)
        step publish(ReportsDismissed.new(data: { player_id: player.id, staff_id: staff.id }), stream_name: "Accounts::Player$#{player.id}")
        ModerationAction.create!(kind: :dismissal, player:, staff:, created_at: now)
        handled
      end
    end

    private

    def permitted(staff, player)
      code = self.class.refusal(staff:, player:)
      code ? Failure(code) : Success()
    end

    def any_handled(count)
      count.positive? ? Success() : Failure(:no_open_reports)
    end
  end
end
