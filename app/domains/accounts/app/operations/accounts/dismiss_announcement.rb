module Accounts
  class DismissAnnouncement < ApplicationOperation
    include AnnouncementWriting

    def call(player:, announcement:)
      announcement = step require_announcement(announcement)
      step require_player(player)

      transaction do
        inserted = AnnouncementDismissal.insert_all(
          [ { announcement_id: announcement.id, player_id: player.id, created_at: Time.current } ],
          unique_by: %i[announcement_id player_id], returning: :id
        )
        if inserted.any?
          step publish(AnnouncementDismissed.new(data: { announcement_id: announcement.id, player_id: player.id }),
            stream_name: "Accounts::Player$#{player.id}")
        end
        announcement
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.deleted? ? Success(player) : Failure(:player_required)
    end
  end
end
