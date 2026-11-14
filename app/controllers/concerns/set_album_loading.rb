module SetAlbumLoading
  extend ActiveSupport::Concern

  include Pagy::Method

  ALBUM_SIZE = CollectionGridLoading::GRID_SIZE

  Slot = Data.define(:card, :copies, :new, :number, :reserved)

  private
    def load_set_album(season, owner:, own:)
      raise ActiveRecord::RecordNotFound if season.nil?

      album = Catalog::SetAlbum.call(season:, kind: params[:kind], key: params[:key])
      raise ActiveRecord::RecordNotFound if album.nil?

      editions = Game::HeldGames.editions(owner, card_ids: album.members.map(&:last), season:)
      @set = album.set
      @standing = Game::SetStanding.measured(set_id: album.set.id, held: album.members.count { editions.key?(it.last) },
        total: album.members.size, tiers: album.tiers)
      load_album_slots(album.members, editions, number: season.number, viewing_owner: (owner if own))
    end

    def load_album_slots(members, editions, viewing_owner:, number: nil)
      @album_filters = SetAlbumFilters.from(params)
      faces, views = filtered_faces(members, editions)
      @album_pagy, page = pagy(:offset, faces, limit: ALBUM_SIZE, page: album_page)
      @album_slots = album_slots(page, views || card_views(page), number:, viewing_owner:)
    end

    def filtered_faces(members, editions)
      faces = members.filter_map do |card_season_id, card_id|
        edition = editions[card_id]
        [ edition&.card_season_id || card_season_id, edition ] if @album_filters.shows_holding?(edition)
      end
      return [ faces, nil ] unless @album_filters.by_card?

      views = card_views(faces)
      [ faces.select { |shown_id, _edition| views.key?(shown_id) && @album_filters.shows_card?(views.fetch(shown_id)) }, views ]
    end

    def card_views(faces)
      Catalog::CardViews.call(faces.map(&:first), locale: I18n.locale)
    end

    def album_slots(faces, views, number:, viewing_owner:)
      reserved = Game::ReservedCopies.call(viewing_owner, card_ids: faces.filter_map { |shown_id, edition| views[shown_id]&.card_id if edition })
      faces.filter_map do |shown_id, edition|
        next unless views.key?(shown_id)

        card = views.fetch(shown_id)
        Slot.new(card:, copies: edition&.copies, new: viewing_owner.present? && edition&.new == true, number: number || card.season_number,
          reserved: reserved[card.card_id])
      end
    end

    def album_page
      params[:page].to_s.to_i.clamp(1, CollectionGridLoading::MAX_PAGE)
    end
end
