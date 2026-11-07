class OwnProfileSheetsController < ApplicationController
  layout "sheet"

  def show
    authorize :own_profile, :show?
    @sheet = params[:sheet]
    send(:"load_#{@sheet}_sheet")
  end

  private
    def load_title_sheet
      @titles = Game::ProfileTitles.call(current_player)
      @owner_title = Game::ActiveProfileTitle.call(current_player, titles: @titles)
    end

    def load_avatar_sheet
      @avatars = Game::AvatarShelf.call(current_player)
    end

    def load_back_sheet
      @card_backs = Game::CardBackShelf.call(current_player)
    end
end
