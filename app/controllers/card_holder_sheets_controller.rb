class CardHolderSheetsController < ApplicationController
  include CardDetailLoading

  layout "sheet"

  def show
    authorize :trade, :new?
    load_card_detail
    @holders = Game::FriendsHolding.call(current_player, card_id: @detail.card_id, card_season_id: @detail.card_season_id)
  end
end
