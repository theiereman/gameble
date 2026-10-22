# A friend's profile, from the Friends screen: a friendship surface, so a
# private friend hides here from staff friends too; staff read the public
# profile instead.
class FriendProfilesController < ApplicationController
  def show
    authorize :friend, :show?

    @owner = Accounts::PlayerByToken.call(params[:token])
    unless Game::FriendshipBetween.call(current_player, @owner) && Game::Visibility.visible?(current_player, @owner, staff_sees_all: false)
      return render :unavailable, status: :not_found
    end

    @presence = Game::FriendsPresence.of(@owner)
    @trades_closed = :own_profile_private unless Game::Visibility.open_to_friends?(current_player)
    @open_trade_token = Game::OpenTradesByFriend.call(current_player)[@owner.id]
    @distinct_cards = Game::HeldGames.count(@owner)
  end
end
