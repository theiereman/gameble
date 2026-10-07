class FriendProfilesController < ApplicationController
  def show
    authorize :friend, :show?

    @owner = Accounts::PlayerByToken.call(params[:token])
    unless Game::FriendshipBetween.call(current_player, @owner) && Game::Visibility.visible?(current_player, @owner)
      return render :unavailable, status: :not_found
    end

    @presence = Game::FriendsPresence.of(@owner)
    season = Catalog::PublishedSeason.call
    @distinct_cards = Game::CollectionSummary.distinct_cards(@owner, season:)
    ids = Game::ShowcaseCards.call(@owner, season:)
    views = Catalog::CardViews.call(ids, locale: I18n.locale)
    @showcase = ids.filter_map { |id| views[id] }
  end
end
