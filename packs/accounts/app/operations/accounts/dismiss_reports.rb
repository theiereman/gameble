module Accounts
  # A moderator or an administrator classes the open reports of a player
  # they outrank without acting on the player: they leave the staff's queue.
  # A report from a player who had not reported them yet brings the player
  # back. No one classes the reports against themselves.
  #
  # The player's row is locked FOR NO KEY UPDATE before the reports, the
  # order Accounts::BanPlayer takes, and the refusal is read again from the
  # locked row: a dismissal waiting on a ban finds the reports handled.
  #
  #   Accounts::DismissReports.new.call(staff:, player:)
  #   # => Success(count) | Failure(:staff_required | :player_not_found |
  #   #    :cannot_dismiss_self | :outranked | :no_open_reports)
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
