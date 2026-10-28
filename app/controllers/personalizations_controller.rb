class PersonalizationsController < ApplicationController
  include ChosenCards

  def show
    authorize :personalization, :show?
    @showcase = chosen_cards(current_player)
    @titles = Game::ProfileTitles.call(current_player)
    @active_title = Game::ActiveProfileTitle.call(current_player, titles: @titles)
  end
end
