module Game
  # Counts a signed-in player's view of another player's profile, at most once an hour per pair.
  class MarkProfileVisited < Operation
    ONE_VISIT_PER = 1.hour

    def call(player:, owner_token:, now: Time.current)
      viewer = step require_player(player)
      owner = step visible_owner(viewer, owner_token)

      transaction do
        step lock_bank(viewer)
        step not_visited_recently(viewer, owner, now)
        ProfileVisit.create!(viewer_id: viewer.id, visited_id: owner.id, created_at: now)
        step publish(ProfileVisited.new(data: { viewer_id: viewer.id, visited_id: owner.id }), stream_name: stream_name(viewer.id))
        owner
      end
    end

    private

    def visible_owner(viewer, token)
      owner = Accounts::PlayerByToken.call(token)
      owner && owner != viewer && Visibility.visible?(viewer, owner, staff_sees_all: false) ? Success(owner) : Failure(:profile_not_found)
    end

    def not_visited_recently(viewer, owner, now)
      recent = ProfileVisit.where(viewer_id: viewer.id, visited_id: owner.id, created_at: (now - ONE_VISIT_PER)..)
      recent.exists? ? Failure(:recently_visited) : Success()
    end
  end
end
