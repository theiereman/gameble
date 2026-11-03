class OwnProfilesController < ApplicationController
  include ProfileLoading

  def show
    authorize :own_profile, :show?
    load_profile(current_player)
    @card_backs = Game::CardBackShelf.call(current_player)
    @titles = Game::ProfileTitles.call(current_player)
    @owner_title = Game::ActiveProfileTitle.call(current_player, titles: @titles)
  end
end
