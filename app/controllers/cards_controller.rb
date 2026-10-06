# A card's detail page (CAP-7, story 4.3; DESIGN.md, Card detail "FICHE DE
# LA CARTE"; epic 10 R2, R6): the large face and what only the detail
# tells, its sets and the viewer's copies, in the viewer's language; open
# to a visitor (CAP-18). The card is addressed by its slug, and by its
# season's number for a card-season other than the published season's
# (AD-15); Catalog answers the card, its sets and its place in one of them,
# Game the copies and the viewer's card back.
#
# The page browses one set of the card's season: the one the query names
# (`set_kind` and `set_key`, as a grid's links and ◀ ▶ add them), else the
# card's first set (tomes first). Within a named set, a card the viewer
# does not hold shows their active card back, faded (AD-25); the card's own
# page, without a set (a share link, the showcase), shows the face to
# everyone. A viewer who holds the card can share it (CAP-9): the link is
# this card-season's own page, which carries the preview tags; it shows only
# the card, never who shared or holds it (spec CAP-9, 2026-10-03). A visitor
# who opens that page, without a set in the query, gets the public card page
# (DESIGN.md, Public card page; story 10.3): the card, its facts and the
# invitation to play, with no app chrome. A signed-in viewer, or a visitor
# browsing a set, gets the detail panel. Read from shared links, it is open
# to any browser and link-preview crawler (PublicRead).
class CardsController < ApplicationController
  include PublicRead
  include CardDetailLoading

  # GET /:locale/cards/:slug and /:locale/cards/:slug/seasons/:number. An
  # unknown slug, or a card the season asked (the published one by default)
  # does not hold, is not found. A set the query names that is not one of
  # the card's is ignored.
  def show
    authorize :page, :show?
    load_card_detail
    id = @detail.card_season_id
    @copies = Game::Quantities.call(current_player, [ id ]).fetch(id, nil)
    @share_url = share_url if @copies && current_player
    named = named_set
    @public = current_player.nil? && named.nil?
    @browse = browse(named || @detail.sets.first) unless @public
    @faded = !named.nil? && @copies.nil?
    @back_key = Game::CardBacks.active_key(current_player)
  end

  private
    # The absolute link to this card-season's page, always season-qualified,
    # on the configured public base; nothing in it names the viewer.
    def share_url
      helpers.card_public_url(@detail.view)
    end

    # The set the query names, when its kind is a library kind and it is one
    # of the card's sets; nil otherwise.
    def named_set
      kind = params[:set_kind]
      key = params[:set_key]
      return unless kind.is_a?(String) && key.is_a?(String) && ShelfLoading::KINDS.include?(kind)

      @detail.sets.find { it.kind == kind && it.key == key }
    end

    # The card's place in `set` (Catalog::SetNeighbours), nil without a set.
    def browse(set)
      return if set.nil?

      Catalog::SetNeighbours.call(card_season_id: @detail.card_season_id, kind: set.kind, key: set.key, locale: I18n.locale)
    end
end
