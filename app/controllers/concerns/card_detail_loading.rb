# A card's detail for a controller that shows one (CAP-7): the card's own
# page, which a share link also opens (CAP-9). The card is addressed by its
# slug, and by its season's number for a card-season other than the
# published season's (AD-15).
module CardDetailLoading
  extend ActiveSupport::Concern

  private
    # @detail, the Catalog::CardDetail of `params[:slug]` in the season of
    # the path's number (the published season without one). The number is
    # read from the path only, never from the query string, which the route's
    # constraint does not check. An unknown slug, or a card the season does
    # not hold, is not found.
    def load_card_detail
      number = request.path_parameters[:number]&.to_i
      @detail = Catalog::CardDetail.call(slug: params[:slug], locale: I18n.locale, season_number: number)
      raise ActiveRecord::RecordNotFound if @detail.nil?
    end
end
