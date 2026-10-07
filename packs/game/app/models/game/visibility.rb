module Game
  # The one question every surface that shows a player asks (AD-13, AD-14):
  # may `viewer` (nil for a signed-out visitor) see `owner`'s profile and
  # what is attributed to them? A missing or banned owner is never visible,
  # not even to themselves. Else the owner sees themselves; anyone sees a
  # public owner; a friends-only owner is seen by their friends, and no one
  # is a friend until epic 5 supplies the friendship query (`friend?`); a
  # private owner is seen by no one else.
  #
  #   Game::Visibility.visible?(current_player, owner) # => true | false
  module Visibility
    def self.visible?(viewer, owner)
      return false if owner.nil? || owner.banned?
      return true if viewer == owner || owner.visibility_public?

      owner.visibility_friends_only? && friend?(viewer, owner)
    end

    # Epic 5 replaces this with the friendship query.
    def self.friend?(_viewer, _owner)
      false
    end
    private_class_method :friend?
  end
end
