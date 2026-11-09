class PagesController < ApplicationController
  include SeasonAllocationGate
  include MarkdownNegotiation

  negotiates_markdown only: %i[home legal how_it_works credits]
  before_action :lead_to_season_allocation, only: :home

  def home
    return show_landing_markdown if current_player.nil? && markdown_requested?
    return lead_app_visitor_to_sign_in if visitor_landing? && hotwire_native_app?
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
    @goals = Game::GoalNeeds.call(current_player)
    @live_strip = LiveStream.strip_items
    @fortune_panel = Game::FortunePanel.call(current_player, tab: :week)
  end

  def legal
    authorize :page, :show?
    @legal = Rails.configuration.x.legal
    render_markdown if markdown_requested?
  end

  def how_it_works
    authorize :page, :show?
    render_markdown if markdown_requested?
  end

  def credits
    authorize :page, :show?
    render_markdown if markdown_requested?
  end

  private
    def public_read?
      return false unless request.get? || request.head?

      %w[legal credits].include?(action_name) || (action_name == "home" && visitor_landing?)
    end

    # Not Mime::Type#html?: false for */*, true for turbo-stream.
    def visitor_landing?
      current_player.nil? && request.formats.any? { it == Mime[:html] || it == Mime::ALL }
    end

    def lead_app_visitor_to_sign_in
      authorize :landing, :show?
      redirect_to sign_in_path, status: :see_other
    end

    def show_landing
      authorize :landing, :show?
      @samples = Catalog::LandingSampleCards.call(locale: I18n.locale)
      @roadmap = Catalog::LandingRoadmap.call(locale: I18n.locale)
      @season_facts = readable { Game::LandingSeasonFacts.call(locale: I18n.locale) }
      @goal = readable { Game::LandingGoal.call(locale: I18n.locale) }
      render "landings/show", formats: :html
    end

    def show_landing_markdown
      authorize :landing, :show?
      send_markdown(LandingMarkdown.new(
        samples: Catalog::LandingSampleCards.call(locale: I18n.locale),
        odds: helpers.odds_rows(Game::DrawOdds::REGULAR),
        roadmap: Catalog::LandingRoadmap.call(locale: I18n.locale),
        season_facts: readable { Game::LandingSeasonFacts.call(locale: I18n.locale) },
        links: landing_markdown_links
      ).to_s)
    end

    def landing_markdown_links
      [ [ t("landings.show.hero.embark"), sign_in_url ],
        [ t("landings.show.footer.how_it_works"), how_it_works_url ],
        [ t("landings.show.footer.legal"), legal_url ],
        [ t("landings.show.footer.credits"), credits_url ],
        [ t("landings.show.roadmap.all"), roadmap_url ],
        [ t("landings.show.footer.support"), ExternalLinksHelper::DONATION_URL ],
        [ t("landings.show.footer.source"), ExternalLinksHelper::SOURCE_CODE_URL ] ]
    end

    def readable
      yield
    rescue ActiveRecord::ActiveRecordError => error
      Rails.logger.error("landing block unreadable: #{error.class}")
      nil
    end

    def load_showcase
      chosen = Game::ChosenShowcase.call(current_player).first
      @showcase_chosen = !chosen.nil?
      id = chosen || Game::LatestBestCard.call(current_player, season: @season)
      @showcase = Catalog::CardViews.call([ id ], locale: I18n.locale)[id] if id
    end

    def collection
      { owned: Game::HeldGames.count(current_player),
        total: Catalog::CardCount.call(@season) }
    end
end
