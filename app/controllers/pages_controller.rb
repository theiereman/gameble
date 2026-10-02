class PagesController < ApplicationController
  def home
    authorize :page, :show?
    @bank = Game::BankSummary.call(current_player) if current_player
  end
end
