module BackOffice
  class BansController < BaseController
    include Pagy::Method

    PAGE_SIZE = 50
    MAX_PAGE = 100_000

    rate_limit to: 30, within: 1.minute, only: %i[create destroy]

    def index
      authorize [ :back_office, :bans ], :index?
      @pagy, @players = pagy(:offset, Accounts::BannedPlayers.call, limit: PAGE_SIZE, page: params[:page].to_s.to_i.clamp(1, MAX_PAGE))
    end

    def create
      authorize [ :back_office, :bans ], :create?

      player = Accounts::PlayerByToken.call(params[:token])
      result = Accounts::BanPlayer.new.call(staff: current_player, player:, reason: params[:reason])
      if result.success?
        redirect_to return_path(back_office_reports_path), notice: t(".banned", name: helpers.public_profile_title(player)), status: :see_other
      else
        redirect_refused Accounts::BanPlayer, result, return_path(back_office_reports_path)
      end
    end

    def destroy
      authorize [ :back_office, :bans ], :destroy?

      player = Accounts::PlayerByToken.call(params[:token])
      result = Accounts::UnbanPlayer.new.call(staff: current_player, player:)
      if result.success?
        redirect_to return_path(back_office_bans_path), notice: t(".unbanned", name: helpers.public_profile_title(player)), status: :see_other
      else
        redirect_refused Accounts::UnbanPlayer, result, return_path(back_office_bans_path)
      end
    end

    private
      def return_path(default)
        return default unless params[:return_to] == "players"

        page = params[:page].to_s.to_i
        back_office_players_path(q: Accounts::PlayerSearch.normalize(params[:q]).presence, page: (page if page > 1))
      end
  end
end
