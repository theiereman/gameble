# The hub, "Pont de commandement" (EXPERIENCE.md, Hub content): the numbered
# menu, the showcase of the player's latest notable pull (or the invitation
# to sign in), the daily booster panel and the set progress rows. A read
# only page (AD-11): Catalog answers the season, its size and the showcased
# card, Game the player's reserve, pull, collection and sets.
class PagesController < ApplicationController
  def home
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    @goal = Game::CurrentGoal.call
    if current_player
      @bank = Game::BankSummary.call(current_player)
      @showcase = showcase if @season
    end
    @collection = collection if @season
    @sets = @season ? set_rows : []
  end

  # GET /:locale/more: the phone's PLUS tab (EXPERIENCE.md, PLUS rows), the
  # rows of the screens that are not tabs. Nothing is read.
  def more
    authorize :page, :show?
  end

  private
    # The card of the player's latest notable pull, as a Catalog::CardView,
    # or nil (the empty showcase).
    def showcase
      id = Game::NotablePull.call(current_player, season: @season)
      Catalog::CardViews.call([ id ], locale: I18n.locale)[id] if id
    end

    # Menu 02's meta: distinct cards held in the season, out of its cards.
    def collection
      { owned: Game::CollectionSummary.distinct_cards(current_player, season: @season),
        total: Catalog::CardCount.call(@season) }
    end

    # The set progress rows, named in the current locale; a set is reached by
    # its kind and key (AD-15).
    def set_rows
      Game::HubSets.call(current_player, season: @season).map do |row|
        { label: SetLabel.for(row.set), kind: row.set.kind, key: row.set.key, owned: row.owned, total: row.total }
      end
    end
end
