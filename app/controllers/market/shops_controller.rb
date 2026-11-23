module Market
  class ShopsController < ApplicationController
    include PublicRead
    include GoalMarksLoading

    MAX_PAGE = 100_000
    FILTER_PARAMS = %i[q rarity season wanted].freeze

    def show
      authorize %i[market shop], :show?
      load_market
      load_filters
      @offers = Game::Market::ArchiveOffers.call(settings: @settings, sort: @sort, page: @page, locale: I18n.locale, filters: @filters)
      @marks = ListingMarks.for(current_player, @offers.rows, goal_marks, wanted_card_ids)
      respond_to do |format|
        format.html do
          @counts = Game::Market::ArchiveOffers.count(settings: @settings, locale: I18n.locale, filters: @filters)
          load_wanted_count
        end
        format.turbo_stream
      end
    end

    private
      def load_market
        @settings = Game::Market::CurrentSettings.call
        state = Game::Market::MarketState.call(@settings)
        raise ActiveRecord::RecordNotFound unless state.first_opened?

        @suspended = state.suspended?
        @buyable = current_player.present? && state.open?
      end

      def load_filters
        @sort = params[:sort].presence_in(Game::Market::ArchiveOffers::SORTS.keys) || Game::Market::ArchiveOffers::DEFAULT_SORT
        @page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
        @rarities = Game::Market::ArchiveOffers.priced_rarities(@settings)
        @seasons = Game::Market::ListingFilterOptions.call.seasons
        filters = Game::Market::ListingFilters.from(params.slice(*FILTER_PARAMS), seasons: @seasons, wanted_card_ids:)
        @filters = filters.with(rarities: filters.rarities & @rarities)
      end

      def wanted_card_ids
        @wanted_card_ids ||= Game::Market::WantedCardIds.call(current_player)
      end

      def load_wanted_count
        return if wanted_card_ids.empty?

        @wanted_count = Game::Market::ArchiveOffers.count(settings: @settings, locale: I18n.locale,
          filters: Game::Market::ListingFilters.wanted(wanted_card_ids)).cards
      end
  end
end
