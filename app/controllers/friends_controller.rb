# The Friends screen, "Amis" (EXPERIENCE.md, Amis): a player's friends and
# their own friend code. A read only page (AD-11): Game answers both. A
# visitor is refused and sent home to sign in. Invitations come with story 5.2.
class FriendsController < ApplicationController
  # GET /:locale/friends
  def show
    authorize :friend, :show?
    @friend_code = Game::FriendCodeOf.call(current_player)
    @friends = Game::FriendsOf.call(current_player)
  end
end
