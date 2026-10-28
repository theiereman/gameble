class PersonalizationsController < ApplicationController
  include ChosenCards

  def show
    authorize :personalization, :show?
    @showcase = chosen_cards(current_player)
  end
end
