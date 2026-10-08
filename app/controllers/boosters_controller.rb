# The booster screen, "Ouverture de booster" (EXPERIENCE.md: Booster,
# Opening protocol; DESIGN.md, Booster information panel): the Booster
# island, which opens packs through the opening exchange (packs#create in
# JSON, AD-23) and reveals them. A read-only page (AD-11): Game answers the
# player's reserve (which the top bar's reserve chip reuses) and the size of
# the next pack, Catalog the published season.
#
# Given `pack`, the token of one of the player's opened packs, the island
# shows that pack dealt, every card face up: the way back from one of its
# cards' details (the island writes the token into its history entry
# before leaving for a card). Another player's pack, one not opened or an
# unknown token is ignored: the canister, sealed or empty, as without one.
class BoostersController < ApplicationController
  include PackCards

  # GET /:locale/booster
  def show
    authorize :booster, :show?
    @bank = Game::BankSummary.reserve(current_player)
    @next_pack_size = Game::NextPackSize.call(current_player)
    @season = Catalog::PublishedSeason.call
    @opened = opened_pack
  end

  private
    # The opening exchange's answer for the opened pack `pack` names, or nil.
    def opened_pack
      pack = Game::OpenedPackByToken.call(current_player, params[:pack])
      pack && helpers.pack_opening_json(pack, cards: cards_of(pack), player: current_player, now: Time.current)
    end
end
