# A card's detail page (CAP-7, story 4.3): the large face and what only the
# detail tells, its sets and the viewer's copies, in the viewer's language;
# open to a visitor (CAP-18). The card is addressed by its slug, and by its
# season's number for a card-season other than the published season's
# (AD-15); Catalog answers the card and its sets, Game the copies.
class CardsController < ApplicationController
  # GET /:locale/cards/:slug and /:locale/cards/:slug/seasons/:number. An
  # unknown slug, or a card the season asked (the published one by default)
  # does not hold, is not found.
  def show
    authorize :page, :show?
    number = request.path_parameters[:number]&.to_i
    @detail = Catalog::CardDetail.call(slug: params[:slug], locale: I18n.locale, season_number: number)
    raise ActiveRecord::RecordNotFound if @detail.nil?

    id = @detail.card_season_id
    @copies = Game::Quantities.call(current_player, [ id ]).fetch(id, nil)
  end
end
