# A card's detail page (CAP-7, story 4.3): the large face and what only the
# detail tells, its sets and the viewer's copies, in the viewer's language;
# open to a visitor (CAP-18). The card is addressed by its slug, and by its
# season's number for a card-season other than the published season's
# (AD-15); Catalog answers the card and its sets, Game the copies. A viewer
# who holds the card can share it (CAP-9): the link is this card-season's
# own page, which carries the preview tags and, for a visitor, an
# invitation to play; it shows only the card, never who shared or holds it
# (spec CAP-9, 2026-10-03). Read from shared links, it is open to any
# browser and link-preview crawler (PublicRead).
class CardsController < ApplicationController
  include PublicRead
  include CardDetailLoading

  # GET /:locale/cards/:slug and /:locale/cards/:slug/seasons/:number. An
  # unknown slug, or a card the season asked (the published one by default)
  # does not hold, is not found.
  def show
    authorize :page, :show?
    load_card_detail
    id = @detail.card_season_id
    @copies = Game::Quantities.call(current_player, [ id ]).fetch(id, nil)
    @share_url = share_url if @copies && current_player
  end

  private
    # The absolute link to this card-season's page, always season-qualified,
    # on the configured public base; nothing in it names the viewer.
    def share_url
      helpers.card_public_url(@detail.view)
    end
end
