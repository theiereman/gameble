# The activity feed, "Fil d'activité" (CAP-13, EXPERIENCE.md, Fil d'activité):
# the notable pulls, newest first, readable without an account (CAP-18). A
# read only page (AD-11): Game answers the entries each already filtered by
# Game::Visibility for the viewer, Catalog the cards. Only the TOUS tab and
# pulls exist yet.
class FeedsController < ApplicationController
  # GET /:locale/feed
  def show
    authorize :page, :show?
    entries = Game::FeedEntries.call(current_player)
    cards = Catalog::CardViews.call(entries.map { |item| item.entry.card_season_id }, locale: I18n.locale)
    @items = entries.filter_map { |item| [ item, cards[item.entry.card_season_id] ] if cards[item.entry.card_season_id] }
  end
end
