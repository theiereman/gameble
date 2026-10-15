# The hub, "Pont de commandement": the numbered menu, the showcase of the
# player's latest notable pull (or the invitation to sign in), the daily
# booster panel, the community goal panel with a contributor's reward claim
# slot, the set progress rows and, once, a new player's welcome panel. A
# read only page: Catalog answers the season, its size and the showcased
# card, Game the goal, the player's reserve, goal reward, pull, collection,
# sets, how many of their friends are online (menu 04) and the achievements
# they earned (menu 06); the LIVE ticker its first items, the latest public
# entries it shows.
class PagesController < ApplicationController
  def home
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    @goal = Game::CurrentGoal.call
    @ticker = LiveStream.ticker_items
    if current_player
      @bank = Game::BankSummary.call(current_player)
      @goal_reward = Game::GoalRewardStatus.call(current_player)
      @friends_online = Game::FriendsPresence.online_count(current_player)
      @achievements = Game::AchievementBoard.summary(current_player)
      @showcase = showcase if @season
      @welcome = current_player.welcome_pending
      close_welcome_once_shown if @welcome
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

    # The welcome panel shows once: this render closes it for the next
    # visit, unless Turbo is only prefetching the hub behind a hovered link.
    def close_welcome_once_shown
      Accounts::CloseWelcomeJob.perform_later(current_player.id) unless request.headers["X-Sec-Purpose"] == "prefetch"
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
