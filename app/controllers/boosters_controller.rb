# The booster screen: its `booster` controller opens packs through the
# opening exchange (packs#create in JSON) and reveals them. A read-only
# page: Game answers the player's reserve (which the top bar's reserve chip
# reuses) and the size of the next pack, Catalog the published season.
#
# Given `pack`, the token of one of the player's opened packs, the screen
# shows that pack dealt, every card face up: the way back from one of its
# cards' details (the screen writes the token into its history entry
# before leaving for a card). Another player's pack, one not opened or an
# unknown token is ignored: the canister, sealed or empty, as without one.
#
# In JSON the screen answers the player's bank alone, as its root reads it,
# so the screen reads it again without leaving its hand.
class BoostersController < ApplicationController
  include PackCards

  # GET /:locale/booster(.json)
  def show
    authorize :booster, :show?
    @bank = Game::BankSummary.reserve(current_player)
    @next_pack_size = Game::NextPackSize.call(current_player)
    respond_to do |format|
      format.html do
        @season = Catalog::PublishedSeason.call
        @opened_pack = Game::OpenedPackByToken.call(current_player, params[:pack])
        @opened_cards = @opened_pack && cards_of(@opened_pack)
      end
      format.json { render json: { bank: helpers.booster_bank(bank: @bank, next_pack_size: @next_pack_size) } }
    end
  end
end
