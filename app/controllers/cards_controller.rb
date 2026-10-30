class CardsController < ApplicationController
  include PublicRead
  include CardDetailLoading
  include CollectionGridLoading

  Browse = Data.define(:position, :total, :previous, :next, :back)
  Back = Data.define(:label, :path)
  PioneerLine = Data.define(:discovered_on, :token, :name)
  Showcase = Data.define(:action, :season_number, :another_edition)

  def show
    authorize :page, :show?
    load_card_detail
    @editions = Game::HeldEditions.call(current_player, card_id: @detail.card_id)
    @copies = @editions.sum(&:last).nonzero?
    @share_url = share_url
    @share_image_token = CardShareImage.current_token(card_season_id: @detail.card_season_id, view: @detail.view, locale: I18n.locale)
    named = pack_browse || grid_browse || named_set_browse
    profile = profile_browse || personalization_browse unless named
    @public = current_player.nil? && named.nil? && profile.nil?
    @live_strip = LiveStream.strip_items if @public
    @browse = named || profile || set_browse(@detail.sets.first) unless @public
    @showcase = showcase_state
    @pioneer = pioneer_line
    @set_url = set_url
  end

  private
    def pioneer_line
      pioneer = Game::PioneerOf.call(@detail.card_season_id)
      return if pioneer.nil?

      day = pioneer.discovered_at.in_time_zone.to_date
      player = pioneer.player
      return PioneerLine.new(discovered_on: day, token: nil, name: nil) unless Game::Visibility.visible?(current_player, player, staff_sees_all: false)

      name = Accounts::PersonaName.clean(player.persona_name) || t("shell.player.fallback_name")
      PioneerLine.new(discovered_on: day, token: player.token, name:)
    end

    def share_url
      helpers.card_public_url(@detail.view)
    end

    def set_url
      owner = album_owner
      return ->(set) { brother_set_path(owner.token, kind: set.kind, key: set.key) } if owner

      ->(set) { library_set_path(kind: set.kind, key: set.key) } if current_player
    end

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

    def grid_browse
      source = params[:grid]
      return unless source.is_a?(ActionController::Parameters)

      if source[:brother].present?
        @grid_owner = visible_player(source[:brother])
        return if @grid_owner.nil?
      end

      grid = collection_grid(Catalog::PublishedSeason.call, source)
      seen = grid_seen(source) unless grid_another?
      ids = grid_cards(grid, grid_states_asked(source), seen_up_to: seen).pluck(:id)
      index = ids.index(@detail.card_season_id)
      return if index.nil?

      context = grid_context(source, seen:)
      back = Back.new(label: t("cards.show.grid"), path: grid_page_path(context, (index / GRID_SIZE) + 1))
      neighbours(ids, index, back:) { { grid: context } }
    end

    def grid_page_path(context, page)
      query = { **context.except(:seen, :brother), page: (page if page > 1) }.compact_blank
      grid_another? ? brother_collection_path(grid_owner.token, query) : library_cards_path(query)
    end

    def grid_owner
      @grid_owner || current_player
    end

    def grid_another?
      @grid_owner.present?
    end

    def named_set_browse
      kind = params[:set_kind]
      key = params[:set_key]
      return unless kind.is_a?(String) && key.is_a?(String) && Catalog::SetKind::ALL.include?(kind)

      set_browse(@detail.sets.find { it.kind == kind && it.key == key }, owner: album_owner)
    end

    def album_owner
      return @album_owner if defined?(@album_owner)

      @album_owner = visible_player(params[:brother])
    end

    def visible_player(token)
      return unless token.is_a?(String)

      player = Accounts::PlayerByToken.call(token)
      player if player && Game::Visibility.visible?(current_player, player)
    end

    def profile_browse
      return if params.key?(:set_kind) || album_owner.nil?

      back = Back.new(label: t("cards.show.profile"), path: brother_path(album_owner.token))
      browse = set_browse(@detail.sets.first, owner: album_owner)
      browse ? browse.with(back:) : Browse.new(position: 1, total: 1, previous: nil, next: nil, back:)
    end

    def personalization_browse
      return unless current_player && params[:from] == "personalization"

      back = Back.new(label: t("shell.player.personalization"), path: personalization_path)
      Browse.new(position: 1, total: 1, previous: nil, next: nil, back:)
    end

    def showcase_state
      edition = showcase_edition
      return if edition.nil?

      season_number = edition.second
      another_edition = season_number != @detail.view.season_number
      card_season_id = another_edition ? Catalog::PublishedCardSeasonId.call(slug: @detail.view.id, season_number:) : @detail.card_season_id
      return if card_season_id.nil?

      chosen = Game::ChosenShowcase.call(current_player)
      action = if chosen.include?(card_season_id) then :remove
      elsif Game::ChosenShowcase.full?(chosen) then :full
      else :add
      end
      Showcase.new(action:, season_number:, another_edition:)
    end

    def showcase_edition
      @editions.find { |_, season_number, _| season_number == @detail.view.season_number } || @editions.first
    end

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
