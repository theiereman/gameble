class FriendsController < ApplicationController
  throttle_player to: 20, only: :remove, path: -> { friends_path }, alert: "friends.throttled"

  def show
    authorize :friend, :show?
    @friend_code = Game::FriendCodeOf.call(current_player)
    @friends = Game::FriendsPresence.call(current_player)
    @invitations = Game::InvitationsOf.call(current_player)
    @open_trade_tokens = Game::OpenTradesByFriend.call(current_player)
  end

  def remove
    authorize :friend, :remove?

    result = Game::RemoveFriend.new.call(player: current_player, friend: Accounts::PlayerByToken.call(params[:token]))
    if result.success?
      flash[:toast_title] = t("friends.removed.title")
      flash[:notice] = t("friends.removed.text", name: helpers.friend_name(result.value!))
    else
      flash[:alert] = Game::RemoveFriend.failure_message(result.failure)
    end
    redirect_to friends_path, status: :see_other
  end
end
