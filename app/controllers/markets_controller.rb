class MarketsController < ApplicationController
  include PublicRead
  include Market::DeskLoading

  MAX_PAGE = 100_000

  def show
    authorize :market, :show?
    state = Game::Market::MarketState.call
    return unless state.first_opened?

    @suspended = state.suspended?

    @sort = params[:sort].presence_in(helpers.sort_options) || Game::Market::OpenListings::DEFAULT_SORT
    @page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    @options = Game::Market::ListingFilterOptions.call
    @filters = Game::Market::ListingFilters.from(params, genres: @options.genres, seasons: @options.seasons, viewer: current_player)
    load_set_choices
    @listings = Game::Market::OpenListings.call(sort: @sort, page: @page, locale: I18n.locale, filters: @filters)
    respond_to do |format|
      format.html do
        load_desk
        load_found
        render :screen
      end
      format.turbo_stream { render :screen }
    end
  end

  private
    def load_found
      @found = Game::Market::OpenListings.count(locale: I18n.locale, filters: @filters) if @filters.any?
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
