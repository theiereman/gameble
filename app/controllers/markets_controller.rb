class MarketsController < ApplicationController
  include PublicRead
  include Market::DeskLoading
  include GoalMarksLoading
  include Market::Storefront

  def show
    authorize :market, :show?
    @settings = Game::Market::CurrentSettings.call
    state = Game::Market::MarketState.call(@settings)
    return unless state.first_opened?

    @suspended = state.suspended?
    @buyable = buyable?(state)
    @caps = Game::Market::ArchiveCaps.call(player: current_player, settings: @settings)

    @sort = params[:sort].presence_in(helpers.sort_options) || Game::Market::OpenListings::DEFAULT_SORT
    @page = asked_page
    @options = Game::Market::ListingFilterOptions.call
    @filters = Game::Market::ListingFilters.from(params, genres: @options.genres, seasons: @options.seasons, viewer: current_player,
      wanted_card_ids: wanted_card_ids)
    load_set_choices
    @listings = Game::Market::MarketGrid.call(settings: @settings, sort: @sort, page: @page, locale: I18n.locale, filters: @filters)
    @marks = ListingMarks.for(current_player, @listings.rows, goal_marks, wanted_card_ids)
    @stands = Game::Market::BidStands.call(current_player, tokens: @listings.rows.grep(Game::Market::OpenListings::Row).map(&:token))
    respond_to do |format|
      format.html do
        load_desk
        load_found
        load_wanted_count
        render :screen
      end
      format.turbo_stream { render :screen }
    end
  end

  private
    def load_found
      return unless @filters.any?

      @found = Game::Market::OpenListings.count(locale: I18n.locale, filters: @filters)
      @found_offers = Game::Market::MarketGrid.offers_count(settings: @settings, locale: I18n.locale, filters: @filters)
      load_searched if @found.zero? && @filters.without_query.to_params.empty?
    end

    def load_searched
      card_season_id = @filters.searched_card(I18n.locale)
      @searched = Catalog::CardViews.call([ card_season_id ], locale: I18n.locale)[card_season_id] if card_season_id
    end

    def load_wanted_count
      return if wanted_card_ids.empty?

      @wanted_count = Game::Market::OpenListings.count(locale: I18n.locale, filters: Game::Market::ListingFilters.wanted(wanted_card_ids))
    end

    def load_set_choices
      season = Catalog::PublishedSeason.call
      @set_kinds = Catalog::SetKind::ALL & Catalog::SeasonSets.kinds(season:)
      chosen = Catalog::SetsByKey.sets(season:, keys: @filters.sets.map { [ it.kind, it.key ] })
      @filters = @filters.only_sets(chosen.keys)
      return if @set_kinds.empty?

      @set_kind = @set_kinds.include?(params[:set_kind]) ? params[:set_kind] : @set_kinds.first
      @set_query = SetSearch.clean(params[:set_q].is_a?(String) ? params[:set_q] : "")
      found = SetSearch.in_kind(season:, kind: @set_kind, query: @set_query, locale: I18n.locale, except: chosen.keys)
      @set_options = chosen.values + found.sets
      @set_found = found.count
    end
end
