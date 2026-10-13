# The hub, "Pont de commandement" (EXPERIENCE.md, Hub content): the numbered
# menu, the showcase of the player's latest notable pull (or the invitation
# to sign in), the daily booster panel, the community goal panel and the
# set progress rows, with the goal reward's toast while a contributor's
# reward pack waits unopened. A read only page (AD-11): Catalog answers the
# season, its size and the showcased card, Game the goal, the player's
# reserve, reward, pull, collection, sets and how many of their friends are
# online (menu 04); the LIVE ticker its first items, the latest public
# entries it shows.
class PagesController < ApplicationController
  def home
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    @goal = Game::CurrentGoal.call
    @ticker = LiveStream.ticker_items
    if current_player
      @bank = Game::BankSummary.call(current_player)
      @goal_reward_week = Game::WaitingGoalReward.call(current_player)
      @friends_online = Game::FriendsPresence.online_count(current_player)
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

  def legal
    authorize :page, :show?
    @legal = Rails.configuration.x.legal
  end

  def how_it_works
    authorize :page, :show?
  end

  private
    def public_read?
      action_name == "legal" && (request.get? || request.head?)
    end

    # The card of the player's latest notable pull, as a Catalog::CardView,
    # or nil (the empty showcase); @showcase_repostable while they hold it.
    def showcase
      id = Game::NotablePull.call(current_player, season: @season)
      return if id.nil?

      @showcase_repostable = Game::Quantities.call(current_player, [ id ]).key?(id)
      Catalog::CardViews.call([ id ], locale: I18n.locale)[id]
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
