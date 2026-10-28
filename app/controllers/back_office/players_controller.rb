module BackOffice
  class PlayersController < BaseController
    include Pagy::Method

    PAGE_SIZE = 50
    MAX_PAGE = 100_000

    rate_limit to: 30, within: 1.minute, only: :destroy

    def index
      authorize [ :back_office, :players ], :index?
      @query = Accounts::PlayerSearch.normalize(params[:q])
      @pagy, @players = pagy(:offset, Accounts::PlayerSearch.call(@query), limit: PAGE_SIZE, page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
    end

    def destroy
      authorize [ :back_office, :players ], :destroy?

      player = Accounts::PlayerByToken.call(params[:token])
      name = helpers.public_profile_title(player) if player
      result = Accounts::EraseBannedPlayer.new.call(staff: current_player, player:)
      if result.success?
        redirect_to players_return_path, notice: t(".erased", name:), status: :see_other
      else
        redirect_refused Accounts::EraseBannedPlayer, result, players_return_path
      end
    end

    private
      def players_return_path
        page = params[:page].to_s.to_i
        back_office_players_path(q: Accounts::PlayerSearch.normalize(params[:q]).presence, page: (page if page > 1))
      end
  end
end
