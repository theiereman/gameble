# A friend's profile (EXPERIENCE.md, Friend profile; DESIGN.md, Friend
# profile): the body of the dialog a friend row of the Friends screen opens,
# loaded into its frame when the dialog opens, or read as a page. Their
# avatar, name, card count, "VITRINE" of three cards, "PROPOSER UN ÉCHANGE"
# and "SIGNALER" (the report dialog of story 7.4). A read only page (AD-11):
# Accounts answers the owner, Game the friendship, whether the profile may
# be shown (Game::Visibility, the one question) and the cards, Catalog their
# faces.
#
# Only a friend of the owner opens it. An unknown token, a player who is not
# a friend (or no longer one), a banned one and a friend whose visibility
# hides them (private) render the same "not available" frame with a 404. A
# visitor is refused and sent home to sign in.
class FriendProfilesController < ApplicationController
  # GET /:locale/friends/:token
  def show
    authorize :friend, :show?

    @owner = Accounts::PlayerByToken.call(params[:token])
    unless Game::FriendshipBetween.call(current_player, @owner) && Game::Visibility.visible?(current_player, @owner)
      return render :unavailable, status: :not_found
    end

    season = Catalog::PublishedSeason.call
    @distinct_cards = Game::CollectionSummary.distinct_cards(@owner, season:)
    ids = Game::ShowcaseCards.call(@owner, season:)
    views = Catalog::CardViews.call(ids, locale: I18n.locale)
    @showcase = ids.filter_map { |id| views[id] }
  end
end
