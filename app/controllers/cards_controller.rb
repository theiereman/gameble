# A card's detail page (CAP-7, story 4.3; DESIGN.md, Card detail "FICHE DE
# LA CARTE"; epic 10 R2, R6): the large face and what only the detail
# tells, its sets and the viewer's copies, in the viewer's language; open
# to a visitor (CAP-18). The card is addressed by its slug, and by its
# season's number for a card-season other than the published season's;
# Catalog answers the card, its sets, its place in one of them and
# the collection grid, Game the copies, the opened pack, the grid's states
# and the viewer's card back.
#
# The page browses one context, ◀ ▶ stepping through it and the phone's
# way back leading to it: the first one the query names that holds the
# card, else the card's first set (its main theme's set first).
#
# - `pack` (and `slot`, the card's place in it from 1, as a pack can hold a
#   card twice): the viewer's own opened pack, in drawn order, back to the
#   booster showing it ("◀ Booster");
# - `grid`: the collection grid as shown (its filters, search and set, and
#   the watermark its new cards were judged against, CollectionGridLoading),
#   in its order across its pages, back to the page of that grid holding
#   the card ("◀ Grille");
# - `set_kind` and `set_key`: one of the card's sets, back to its grid.
#
# A pack of another player, not opened or not holding the card, a grid or a
# set that does not hold it, is ignored. Within a context the query names,
# a card the viewer does not hold shows their active card back, faded; the
# card's own page, without one (a share link, the showcase), shows the face
# to everyone. A viewer who holds the card can share it: the link is this
# card-season's own page, which carries the preview tags; it shows only the
# card, never who shared or holds it. A visitor who opens that page,
# without a context in the query, gets the public card page: the card, its
# facts, the invitation to play and the LIVE strip of the latest public
# feed entries, with no app chrome. A signed-in viewer,
# or a visitor browsing a context, gets the detail panel. Read from shared
# links, it is open to any browser and link-preview crawler (PublicRead).
class CardsController < ApplicationController
  include PublicRead
  include CardDetailLoading
  include CollectionGridLoading

  # What the detail browses: the card's `position` among `total` cards, the
  # paths of the cards before and after it (nil at an end), and the way
  # back to where they are shown (nil for a set of a season the library
  # does not show).
  Browse = Data.define(:position, :total, :previous, :next, :back)
  # A way back: its words and its path.
  Back = Data.define(:label, :path)

  # GET /:locale/cards/:slug and /:locale/cards/:slug/seasons/:number. An
  # unknown slug, or a card the season asked (the published one by default)
  # does not hold, is not found. A context the query names that does not
  # hold the card is ignored.
  def show
    authorize :page, :show?
    load_card_detail
    id = @detail.card_season_id
    @copies = Game::Quantities.call(current_player, [ id ]).fetch(id, nil)
    @share_url = share_url if @copies && current_player
    named = pack_browse || grid_browse || named_set_browse
    @public = current_player.nil? && named.nil?
    @live_strip = LiveStream.strip_items if @public
    @browse = named || set_browse(@detail.sets.first) unless @public
    @faded = !named.nil? && @copies.nil?
    @back_key = Game::CardBacks.active_key(current_player)
  end

  private
    # The absolute link to this card-season's page, always season-qualified,
    # on the configured public base; nothing in it names the viewer.
    def share_url
      helpers.card_public_url(@detail.view)
    end

    # The viewer's opened pack the query names, when it holds the card: its
    # cards in drawn order. The card's place is the `slot` asked when the
    # card is there, else its first place in the pack.
    def pack_browse
      pack = Game::OpenedPackByToken.call(current_player, params[:pack])
      return if pack.nil?

      ids = pack.card_season_ids
      index = pack_index(ids, params[:slot])
      return if index.nil?

      back = Back.new(label: t("cards.show.booster"), path: booster_path(pack: pack.token))
      neighbours(ids, index, back:) { |at| { pack: pack.token, slot: at + 1 } }
    end

    def pack_index(ids, slot)
      asked = slot.to_s.to_i - 1
      return asked if asked >= 0 && ids[asked] == @detail.card_season_id

      ids.index(@detail.card_season_id)
    end

    # The collection grid the query's `grid` names, as it was shown, when it
    # holds the card; only for a card of the published season, the one the
    # library shows. The state shown without one asked costs the viewer's
    # count of cards held.
    def grid_browse
      source = params[:grid]
      return unless source.is_a?(ActionController::Parameters) && @detail.current_season

      season = Catalog::PublishedSeason.call
      grid = named_grid(season, source)
      return if grid.nil?

      asked = grid_states_asked(source)
      states = asked.any? ? asked : [ grid_default_state(Game::CollectionSummary.distinct_cards(current_player, season:)) ]
      seen = grid_seen(source)
      ids = grid_cards(grid, states, seen_up_to: seen).pluck(:id)
      index = ids.index(@detail.card_season_id)
      return if index.nil?

      context = grid_context(source, grid.set, seen:)
      back = Back.new(label: t("cards.show.grid"), path: grid_page_path(context, (index / GRID_SIZE) + 1))
      neighbours(ids, index, back:) { { grid: context } }
    end

    # The whole season's grid, or the set's when `source` names a library
    # kind and a key; nil for a set the season does not hold, or a set
    # named in part.
    def named_grid(season, source)
      kind = source[:kind]
      key = source[:key]
      return collection_grid(season, source) if kind.nil? && key.nil?
      return unless kind.is_a?(String) && key.is_a?(String) && ShelfLoading::KINDS.include?(kind)

      collection_grid(season, source, kind:, key:)
    end

    # The page `page` of the grid of `context` (its set's, or the whole
    # season's), with its filters and search.
    def grid_page_path(context, page)
      filters = { **context.except(:kind, :key, :seen), page: (page if page > 1) }.compact_blank
      context[:kind] ? library_set_path(kind: context[:kind], key: context[:key], **filters) : library_path(**filters)
    end

    # The set the query names, when its kind is a library kind and it is one
    # of the card's sets.
    def named_set_browse
      kind = params[:set_kind]
      key = params[:set_key]
      return unless kind.is_a?(String) && key.is_a?(String) && ShelfLoading::KINDS.include?(kind)

      set_browse(@detail.sets.find { it.kind == kind && it.key == key })
    end

    # The card's place in `set` (Catalog::SetNeighbours), back to the set's
    # grid when the library shows it; nil without a set.
    def set_browse(set)
      return if set.nil?

      place = Catalog::SetNeighbours.call(card_season_id: @detail.card_season_id, kind: set.kind, key: set.key, locale: I18n.locale)
      return if place.nil?

      context = { set_kind: set.kind, set_key: set.key }
      path = ->(slug) { slug && helpers.card_detail_path(slug, @detail.view.season_number, context) }
      back = Back.new(label: t("cards.show.grid"), path: library_set_path(kind: set.kind, key: set.key)) if @detail.current_season
      Browse.new(position: place.position, total: place.total, previous: path.(place.previous), next: path.(place.next), back:)
    end

    # The card at `index` among the card-seasons `ids`: the paths of its
    # neighbours, each carrying the context the block gives for its index,
    # read in one query.
    def neighbours(ids, index, back:)
      sides = { previous: (index - 1 if index.positive?), next: (index + 1 if index + 1 < ids.size) }.compact
      views = Catalog::CardViews.call(sides.values.map { ids[it] }, locale: I18n.locale)
      paths = sides.to_h do |side, at|
        view = views[ids[at]]
        [ side, view && helpers.card_detail_path(view.id, view.season_number, yield(at)) ]
      end
      Browse.new(position: index + 1, total: ids.size, previous: paths[:previous], next: paths[:next], back:)
    end
end
