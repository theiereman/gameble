# A card's detail page: the large face and what only the detail tells,
# its sets and the viewer's copies and editions of its game, in the
# viewer's language; open to a visitor. The card is addressed by
# its slug, and by its season's number for a card-season other than the
# published season's; Catalog answers the card, its sets, its place in one
# of them and the collection grid, Game the copies and editions, the
# opened pack and the grid's states.
#
# The page browses one context, ◀ ▶ stepping through it and the phone's
# way back leading to it: the first one the query names that holds the
# card, else the card's first set (its main theme's set first).
#
# - `pack` (and `slot`, the card's place in it from 1, as a pack can hold a
#   card twice): the viewer's own opened pack, in drawn order, back to the
#   booster showing it ("◀ Booster");
# - `grid`: the collection grid as shown (its filters and search, and
#   the watermark its new cards were judged against, CollectionGridLoading),
#   in its order across its pages, back to the page of that grid holding
#   the card ("◀ Grille");
# - `set_kind` and `set_key`: one of the card's sets, back to its album;
#   with `brother`, a player's token, back to that player's album of it
#   when their profile may be shown;
# - `brother` alone: that player's profile showcase, when their profile
#   may be shown, browsing the card's first set as that player's album
#   does, back to their profile ("◀ Profil"), the card showing its face.
#
# A signed-in viewer who holds this card-season can put it in their
# profile showcase, or take it out when it is there (`@showcase`).
#
# A pack of another player, not opened or not holding the card, a grid or a
# set that does not hold it, is ignored. The detail always shows the card's
# face, held or not. Anyone can share it: the link is this card-season's own
# page, which carries the preview tags; it shows only the card, never who
# shared or holds it. A visitor who opens that page, without a context in
# the query, gets the public card page: the card, its facts, the
# invitation to play and the LIVE strip of the latest public feed entries, with no app chrome.
# A signed-in viewer, or a visitor browsing a context, gets the detail
# panel. Read from shared links, it is open to any browser and link-preview
# crawler (PublicRead).
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
  # The pioneer row: the day of the first discovery, and the player's
  # profile `token` and `name`, both nil when the viewer may not see them.
  PioneerLine = Data.define(:discovered_on, :token, :name)

  # GET /:locale/cards/:slug and /:locale/cards/:slug/seasons/:number. An
  # unknown slug, or a card the season asked (the published one by default)
  # does not hold, is not found. A context the query names that does not
  # hold the card is ignored.
  def show
    authorize :page, :show?
    load_card_detail
    @editions = Game::HeldEditions.call(current_player, card_id: @detail.card_id)
    @copies = @editions.sum(&:last).nonzero?
    @share_url = share_url
    named = pack_browse || grid_browse || named_set_browse
    profile = profile_browse unless named
    @public = current_player.nil? && named.nil? && profile.nil?
    @live_strip = LiveStream.strip_items if @public
    @browse = named || profile || set_browse(@detail.sets.first) unless @public
    @showcase = showcase_state
    @pioneer = pioneer_line
  end

  private
    # Who first discovered this card's published edition, named when the
    # viewer may see their profile, whatever the season shown; nil without a
    # recorded discovery.
    def pioneer_line
      pioneer = Game::PioneerOf.call(@detail.card_id)
      return if pioneer.nil?

      day = pioneer.discovered_at.in_time_zone.to_date
      player = pioneer.player
      return PioneerLine.new(discovered_on: day, token: nil, name: nil) unless Game::Visibility.visible?(current_player, player, staff_sees_all: false)

      name = Accounts::PersonaName.clean(player.persona_name) || t("shell.player.fallback_name")
      PioneerLine.new(discovered_on: day, token: player.token, name:)
    end

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

    # The collection grid the query's `grid` names, as it was shown, when
    # one of its tiles is this card-season.
    def grid_browse
      source = params[:grid]
      return unless source.is_a?(ActionController::Parameters)

      grid = collection_grid(Catalog::PublishedSeason.call, source)
      seen = grid_seen(source)
      ids = grid_cards(grid, grid_states_asked(source), seen_up_to: seen).pluck(:id)
      index = ids.index(@detail.card_season_id)
      return if index.nil?

      context = grid_context(source, seen:)
      back = Back.new(label: t("cards.show.grid"), path: grid_page_path(context, (index / GRID_SIZE) + 1))
      neighbours(ids, index, back:) { { grid: context } }
    end

    # The page `page` of the grid of `context`, with its filters and search.
    def grid_page_path(context, page)
      library_cards_path({ **context.except(:seen), page: (page if page > 1) }.compact_blank)
    end

    # The set the query names, when its kind is a library kind and it is one
    # of the card's sets.
    def named_set_browse
      kind = params[:set_kind]
      key = params[:set_key]
      return unless kind.is_a?(String) && key.is_a?(String) && Catalog::SetKind::ALL.include?(kind)

      set_browse(@detail.sets.find { it.kind == kind && it.key == key }, owner: album_owner)
    end

    # The player whose album the query's `brother` names, when their profile
    # may be shown to the viewer.
    def album_owner
      return @album_owner if defined?(@album_owner)

      owner = Accounts::PlayerByToken.call(params[:brother]) if params[:brother].is_a?(String)
      @album_owner = owner if owner && Game::Visibility.visible?(current_player, owner)
    end

    # The profile showcase of the player the query's `brother` names, with
    # no set named: the card's first set, as their album browses it, back
    # to their profile.
    def profile_browse
      return if params.key?(:set_kind) || album_owner.nil?

      back = Back.new(label: t("cards.show.profile"), path: brother_path(album_owner.token))
      browse = set_browse(@detail.sets.first, owner: album_owner)
      browse ? browse.with(back:) : Browse.new(position: 1, total: 1, previous: nil, next: nil, back:)
    end

    # What the viewer may do with this card-season and their profile
    # showcase: :remove when it is there, else, when they hold it, :add, or
    # :full when the showcase has no room left; nil otherwise.
    def showcase_state
      return unless @editions.any? { |_, season_number, _| season_number == @detail.view.season_number }

      chosen = Game::ChosenShowcase.call(current_player)
      if chosen.include?(@detail.card_season_id) then :remove
      elsif Game::ChosenShowcase.full?(chosen) then :full
      else :add
      end
    end

    # The card's place in `set` (Catalog::SetNeighbours), back to the page of
    # the set's album holding it, `owner`'s when given, when the library
    # shows it (a visitor's own albums are closed: no way back without an
    # owner); nil without a set.
    def set_browse(set, owner: nil)
      return if set.nil?

      place = Catalog::SetNeighbours.call(card_season_id: @detail.card_season_id, kind: set.kind, key: set.key, locale: I18n.locale)
      return if place.nil?

      context = { set_kind: set.kind, set_key: set.key, brother: owner&.token }.compact
      path = ->(slug) { slug && helpers.card_detail_path(slug, @detail.view.season_number, context) }
      back = Back.new(label: t("cards.show.grid"), path: album_page_path(set, place.position, owner:)) if album_back?(owner)
      Browse.new(position: place.position, total: place.total, previous: path.(place.previous), next: path.(place.next), back:)
    end

    def album_back?(owner)
      @detail.current_season && (owner || current_player)
    end

    def album_page_path(set, position, owner:)
      page = ((position - 1) / SetAlbumLoading::ALBUM_SIZE) + 1
      return brother_set_path(owner.token, kind: set.kind, key: set.key, page: (page if page > 1)) if owner

      library_set_path(kind: set.kind, key: set.key, page: (page if page > 1))
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
