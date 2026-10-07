module Game
  # The one question every surface that shows a player asks (AD-13, AD-14):
  # may `viewer` (nil for a signed-out visitor) see `owner`'s profile and
  # what is attributed to them? A missing, banned or deleted owner is never
  # visible, not even to themselves. Else the owner sees themselves; anyone
  # sees a public owner; a friends-only owner is seen by their friends (the
  # friendship query, Game::FriendshipBetween, asked only here for
  # visibility); a private owner is seen by no one else.
  #
  #   Game::Visibility.visible?(current_player, owner) # => true | false
  module Visibility
    def self.visible?(viewer, owner)
      return false if owner.nil? || owner.banned? || owner.deleted?
      return true if viewer == owner || owner.visibility_public?

      owner.visibility_friends_only? && FriendshipBetween.call(viewer, owner)
    end
  end
end
