class FriendsController < ApplicationController
  def show
    authorize :friend, :show?
    @friend_code = Game::FriendCodeOf.call(current_player)
    @friends = Game::FriendsPresence.call(current_player)
    @invitations = Game::InvitationsOf.call(current_player)
    @open_trades = Game::OpenTradesByFriend.call(current_player)
  end
end
