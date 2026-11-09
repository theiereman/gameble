class OwnProfilesController < ApplicationController
  include ProfileLoading

  def show
    authorize :own_profile, :show?
    load_profile(current_player)
    @card_backs = Game::CardBackShelf.call(current_player)
    @titles = Game::ProfileTitles.call(current_player)
    @avatars = Game::AvatarShelf.call(current_player)
    @owner_title = Game::ActiveProfileTitle.call(current_player, titles: @titles)
    @fortune = Game::FortuneStanding.call(current_player, period: :week)
    @return_card = card_to_return_to
  end

  private
    def card_to_return_to
      slug = params[:card].to_s
      number = Integer(params[:edition].to_s, 10, exception: false)
      return if slug.empty? || number.nil? || Catalog::PublishedCardSeasonId.call(slug:, season_number: number).nil?

      card_season_path(slug:, number:)
    end
end
