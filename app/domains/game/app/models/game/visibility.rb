module Game
  module Visibility
    def self.visible?(viewer, owner, staff_sees_all: true, friends: nil)
      return false if owner.nil? || owner.deleted?
      return true if staff_sees_all && Accounts::Player.acting_staff?(viewer)
      return false if owner.banned?
      return true if viewer == owner || owner.visibility_public?

      return false unless owner.visibility_friends_only?

      friends ? friends.include?(owner.id) : FriendshipBetween.call(viewer, owner)
    end

    def self.open_to_friends?(player)
      player.present? && !player.removed? && !player.visibility_private?
    end
  end
end
