class BrotherhoodSetsController < ApplicationController
  include PublicRead
  include Pagy::Method

  def show
    authorize :page, :show?
    album = published_album
    @set = album.set
    @current_season = params[:seasons] == "current"
    inventory = Game::GrandInventory.new(seasons: @current_season ? :current : :all)
    @found, @total = inventory.set_progress(@set)
    @filters = BrotherhoodSetFilters.from(params, signed_in: current_player.present?)
    @pagy, @slots = pagy(:offset, shown_slots(album, inventory), limit: SetAlbumLoading::ALBUM_SIZE, page:)
  end

  private
    def published_album
      season = Catalog::PublishedSeason.call
      album = season && Catalog::SetAlbum.call(season:, kind: params[:kind], key: params[:key])
      raise ActiveRecord::RecordNotFound if album.nil?

      album
    end

    def shown_slots(album, inventory)
      views = Catalog::CardViews.call(album.members.map(&:first), locale: I18n.locale)
      pioneers = inventory.pioneers_of(album.members.map(&:last))
      album.members.filter_map do |card_season_id, card_id|
        card = views[card_season_id]
        next if card.nil? || !@filters.shows_card?(card)

        pioneer = pioneers[card_id]
        [ card, pioneer ] if @filters.shows_discovery?(found: pioneer.present?, mine: current_player.present? && pioneer&.player == current_player)
      end
    end

    def page
      params[:page].to_s.to_i.clamp(1, CollectionGridLoading::MAX_PAGE)
    end
end
