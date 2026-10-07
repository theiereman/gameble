# The Friends screen, "Amis" (EXPERIENCE.md, Amis): a player's own friend
# code and invite link, the invitations waiting and sent, and their friends
# with their presence (online, an activity or last seen, AD-24).
# A read only page (AD-11): Game answers it all; invitations are sent and
# answered by InvitationsController. A visitor is refused and sent home to
# sign in.
class FriendsController < ApplicationController
  # GET /:locale/friends
  def show
    authorize :friend, :show?
    @friend_code = Game::FriendCodeOf.call(current_player)
    @friends = Game::FriendsPresence.call(current_player)
    @invitations = Game::InvitationsOf.call(current_player)
  end
end
