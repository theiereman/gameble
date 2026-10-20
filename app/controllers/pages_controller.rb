# The hub, "Pont de commandement": the numbered menu, the showcase of the
# first card the player chose, else the latest Epic-or-better card they
# hold (or the invitation to sign in), the daily booster panel, the community goal panel with a
# contributor's reward claim slot, the set progress rows and, once, a new
# player's welcome panel. A read only page: Catalog answers the season, its
# size and the showcased card, Game the goal, the player's reserve, goal
# reward, showcased card, collection, sets, how many of their friends are
# online (menu 04) and the achievements they earned (menu 06); the LIVE
# ticker its first items, the latest public entries it shows.
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
      load_showcase if @season
      @welcome = current_player.welcome_pending
      Accounts::CloseWelcomeJob.perform_later(current_player.id) if @welcome
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
