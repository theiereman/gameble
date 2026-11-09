module Accounts
  class SeeReleaseNote < ApplicationOperation
    def call(player_id:, release_note_id:)
      transaction do
        next false unless Player.in_good_standing.exists?(id: player_id)

        seen = ReleaseNoteRead.insert_all(
          [ { release_note_id:, player_id:, created_at: Time.current } ],
          unique_by: %i[release_note_id player_id], returning: :id
        )
        if seen.any?
          step publish(ReleaseNoteSeen.new(data: { release_note_id:, player_id: }), stream_name: "Accounts::Player$#{player_id}")
        end
        seen.any?
      end
    end
  end
end
