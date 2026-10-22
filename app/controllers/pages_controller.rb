# The root of every locale: the landing for a visitor, the hub for a player.
# The hub, "Pont de commandement", is the numbered menu, the showcase of the first card the player chose, else the latest
# Epic-or-better card they hold, the daily booster panel, the community goal panel with a
# contributor's reward claim slot, the set progress rows and, once, a new
# player's welcome panel. A read only page: Catalog answers the season, its
# size and the showcased card, Game the goal, the player's reserve, goal
# reward, showcased card, collection, sets, how many of their friends are
# online (menu 05) and the achievements they earned (menu 07); the LIVE
# ticker its first items, the latest public entries it shows.
class PagesController < ApplicationController
  def home
    return show_landing if visitor_landing?

    authorize :page, :play?
    @season = Catalog::PublishedSeason.call
    @goal = Game::CurrentGoal.call
    @ticker = LiveStream.ticker_items
    @bank = Game::BankSummary.call(current_player)
    @goal_reward = Game::GoalRewardStatus.call(current_player)
    @friends_online = Game::FriendsPresence.online_count(current_player)
    @achievements = Game::AchievementBoard.summary(current_player)
    load_showcase if @season
    @welcome = current_player.welcome_pending
    Accounts::CloseWelcomeJob.perform_later(current_player.id) if @welcome
    @collection = collection if @season
    @sets = @season ? set_rows : []
  end

  # GET /:locale/more: the phone's PLUS tab, the
  # rows of the screens that are not tabs. Nothing is read.
  def more
    authorize :page, :play?
  end

  def legal
    authorize :page, :show?
    @legal = Rails.configuration.x.legal
  end

  def how_it_works
    authorize :page, :show?
  end

  def credits
    authorize :page, :show?
  end

  private
    def public_read?
      return false unless request.get? || request.head?

      %w[legal credits].include?(action_name) || (action_name == "home" && visitor_landing?)
    end

    # Only a visitor's request that accepts HTML (or anything) meets the
    # landing; any other request for the root is the hub's, refused to a
    # visitor. Not `Mime::Type#html?`: false for `*/*`, true for turbo-stream.
    def visitor_landing?
      current_player.nil? && request.formats.any? { it == Mime[:html] || it == Mime::ALL }
    end

    # A visitor's root: the landing, whose data blocks each fall back to a
    # placeholder when unreadable.
    def show_landing
      authorize :landing, :show?
      @samples = Catalog::LandingSampleCards.call(locale: I18n.locale)
      @roadmap = Catalog::LandingRoadmap.call(locale: I18n.locale)
      @season_facts = readable { Game::LandingSeasonFacts.call(locale: I18n.locale) }
      @goal = readable { Game::LandingGoal.call(locale: I18n.locale) }
      render "landings/show", formats: :html
    end

    def readable
      yield
    rescue ActiveRecord::ActiveRecordError => error
      Rails.logger.error("landing block unreadable: #{error.class}")
      nil
    end

    # The first card the player chose for their profile showcase, else the
    # latest Epic-or-better card they hold, as a Catalog::CardView, or nil
    # (the empty showcase); `@showcase_chosen` tells which.
    def load_showcase
      chosen = Game::ChosenShowcase.call(current_player).first
      @showcase_chosen = !chosen.nil?
      id = chosen || Game::LatestNotableCard.call(current_player, season: @season)
      @showcase = Catalog::CardViews.call([ id ], locale: I18n.locale)[id] if id
    end

    # Menu 02's meta: the games held, in any edition, out of the season's cards.
    def collection
      { owned: Game::HeldGames.count(current_player),
        total: Catalog::CardCount.call(@season) }
    end

    # "Sets in progress": the player's four sets closest to their next tier
    # (Game::SetBoard.hub), with the sets that name them.
    def set_rows
      standings = Game::SetBoard.hub(current_player, season: @season)
      sets = Catalog::SetsById.call(standings.map(&:set_id))
      standings.filter_map { |standing| SetBoardLoading::SetRow.new(set: sets[standing.set_id], standing:) if sets.key?(standing.set_id) }
    end
end
