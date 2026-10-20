module SetAlbumLoading
  extend ActiveSupport::Concern

  include Pagy::Method

  ALBUM_SIZE = CollectionGridLoading::GRID_SIZE

  # A slot shows the owner's best edition of its game (`card`) and leads to
  # the set's own card-season, of season `number`, where the set is browsed.
  Slot = Data.define(:card, :copies, :new, :number)

  private
    def load_set_album(season, owner:, with_new:)
      raise ActiveRecord::RecordNotFound if season.nil?

      album = Catalog::SetAlbum.call(season:, kind: params[:kind], key: params[:key])
      raise ActiveRecord::RecordNotFound if album.nil?

      editions = Game::HeldGames.editions(owner, card_ids: album.members.map(&:last), season:)
      @set = album.set
      @standing = Game::SetStanding.measured(set_id: album.set.id, held: album.members.count { editions.key?(it.last) },
        total: album.members.size, tiers: album.tiers)
      @album_pagy, page = pagy(:offset, album.members, limit: ALBUM_SIZE, page: album_page)
      @album_slots = album_slots(page, editions, number: season.number, with_new:)
    end

    def album_slots(members, editions, number:, with_new:)
      shown = members.map { |card_season_id, card_id| editions[card_id]&.card_season_id || card_season_id }
      views = Catalog::CardViews.call(shown, locale: I18n.locale)
      members.zip(shown).filter_map do |(_card_season_id, card_id), shown_id|
        edition = editions[card_id]
        next unless views.key?(shown_id)

        Slot.new(card: views.fetch(shown_id), copies: edition&.copies, new: with_new && edition&.new == true, number:)
      end
    end

    def album_page
      params[:page].to_s.to_i.clamp(1, CollectionGridLoading::MAX_PAGE)
    end
end
