# The collection: its entry, the search over every set and the player's
# sets in progress, under the top bar's unique cards; the grid of every
# game of the published season and every game the viewer holds, in any
# edition, with its filters, its search and the RAPPORT; and one set's
# album, the player's best edition of each of its games. The entry and the
# albums are a player's pages; a visitor reaches only the grid. A player's
# grid sets the cards they do not hold apart, faded and locked; a visitor
# owns nothing and sees every card's plain face, and no ownership data: no
# state filters, no RAPPORT, no unique cards in the top bar. Sets are addressed by
# kind and key, cards by slug; no id reaches the page. A GET writes
# nothing: a grid that showed new cards posts the latest gain it showed to
# CollectionSeenController. Open to any browser (PublicRead).
class LibraryController < ApplicationController
  include PublicRead
  include CollectionGridLoading
  include SetBoardLoading
  include SetAlbumLoading

  # GET /:locale/library: the entry, the player's sets.
  def show
    authorize :page, :play?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    load_unique_cards
    load_set_board(@season, owner: current_player)
  end

  # GET /:locale/library/cards: the grid of every game.
  def cards
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    @grid = collection_grid(@season, params)
    load_summary if current_player
    load_grid(@grid)
    load_set_filter(@grid)
  end

  # GET /:locale/library/:kind/:key: one set's album.
  def set
    authorize :page, :play?
    @season = Catalog::PublishedSeason.call
    load_set_album(@season, owner: current_player, with_new: true)
    load_unique_cards
  end

  private
    def load_unique_cards
      @unique = Game::HeldGames.count(current_player)
      @season_cards = Catalog::CardCount.call(@season)
    end
end
