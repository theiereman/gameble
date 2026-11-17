module Game
  class NoteDuelPresence < ApplicationOperation
    LEASE = 20.seconds

    Presence = Data.define(:duel_id, :lapsed)

    def call(stream_key:, at: Time.current)
      seat = DuelSeat.find_by(stream_key:) if stream_key.is_a?(String)
      return unless seat

      held = seat.status == "seated"
      lapsed = held && (seat.present_until.nil? || seat.present_until <= at)
      DuelSeat.where(id: seat.id).update_all(present_until: at + LEASE) if held
      Presence.new(duel_id: seat.duel_id, lapsed:)
    end
  end
end
