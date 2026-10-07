# The activity feed, "Fil d'activité" (CAP-13, EXPERIENCE.md, Fil d'activité):
# the notable entries, newest first, readable without an account (CAP-18),
# under the type filters TOUT, TIRAGES, DÉCOUVERTES, ÉCHANGES and REPOSTS
# (story 6.2). A read only page (AD-11): Game answers the entries each
# already filtered by Game::Visibility for the viewer, Catalog the cards.
# Only the TOUS tab, pulls and first discoveries (story 6.7) exist yet.
class FeedsController < ApplicationController
  # The `filter` parameter's values and the kind of entry each shows; none,
  # or an unknown one, is TOUT.
  FILTERS = { "pulls" => "pull", "discoveries" => "discovery", "trades" => "trade", "reposts" => "repost" }.freeze

  # GET /:locale/feed(?filter=pulls)
  def show
    authorize :page, :show?
    @filter = params[:filter].presence_in(FILTERS.keys)
    entries = Game::FeedEntries.call(current_player, kind: FILTERS[@filter])
    cards = Catalog::CardViews.call(entries.map { |item| item.entry.card_season_id }, locale: I18n.locale)
    @items = entries.filter_map { |item| [ item, cards[item.entry.card_season_id] ] if cards[item.entry.card_season_id] }
  end
end
