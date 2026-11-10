class MarketsController < ApplicationController
  include PublicRead

  MAX_PAGE = 100_000

  def show
    authorize :market, :show?
    return unless Game::Market::MarketState.call.first_opened?

    @sort = params[:sort].presence_in(helpers.sort_options) || Game::Market::OpenListings::DEFAULT_SORT
    @page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    @listings = Game::Market::OpenListings.call(sort: @sort, page: @page, locale: I18n.locale)
    respond_to do |format|
      format.html { render :screen }
      format.turbo_stream { render :screen }
    end
  end
end
