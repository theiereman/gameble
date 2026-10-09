module Game
  module Visibility
    def self.visible?(viewer, owner, staff_sees_all: true)
      return false if owner.nil? || owner.deleted?
      return true if staff_sees_all && Accounts::Player.acting_staff?(viewer)
      return false if owner.banned?
      return true if viewer == owner || owner.visibility_public?

      owner.visibility_friends_only? && FriendshipBetween.call(viewer, owner)
    end
  end
end
