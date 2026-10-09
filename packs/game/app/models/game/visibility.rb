module Game
  module Visibility
    def self.visible?(viewer, owner)
      return false if owner.nil? || owner.banned? || owner.deleted?
      return true if viewer == owner || owner.visibility_public?

      owner.visibility_friends_only? && FriendshipBetween.call(viewer, owner)
    end
  end
end
