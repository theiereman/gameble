# The booster screen, "Ouverture de booster" (EXPERIENCE.md: Booster,
# Opening protocol; DESIGN.md, Booster information panel): the Booster
# island, which opens packs through the opening exchange (packs#create in
# JSON, AD-23) and reveals them. A read-only page (AD-11): Game answers the
# player's reserve, Catalog the published season.
class BoostersController < ApplicationController
  # GET /:locale/booster
  def show
    authorize :booster, :show?
    @bank = Game::BankSummary.call(current_player)
    @season = Catalog::PublishedSeason.call
  end
end
