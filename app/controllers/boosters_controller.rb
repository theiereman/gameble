# The booster screen, "Ouverture de booster" (EXPERIENCE.md: Booster,
# Opening protocol; DESIGN.md, Booster information panel): the Booster
# island, which opens packs through the opening exchange (packs#create in
# JSON, AD-23) and reveals them. A read-only page (AD-11): Game answers the
# player's reserve (which the top bar's reserve chip reuses) and the size of
# the next pack, Catalog the published season.
class BoostersController < ApplicationController
  # GET /:locale/booster
  def show
    authorize :booster, :show?
    @bank = Game::BankSummary.reserve(current_player)
    @next_pack_size = Game::NextPackSize.call(current_player)
    @season = Catalog::PublishedSeason.call
  end
end
