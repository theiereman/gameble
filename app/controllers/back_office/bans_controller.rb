module BackOffice
  class BansController < ApplicationController
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
      result = Accounts::BanPlayer.new.call(staff: current_player, player:)
      if result.success?
        redirect_to back_office_reports_path, notice: t(".banned", name: helpers.public_profile_title(player)), status: :see_other
      else
        redirect_to back_office_reports_path, alert: Accounts::BanPlayer.failure_message(result.failure), status: :see_other
      end
    end

    def destroy
      authorize [ :back_office, :bans ], :destroy?

      player = Accounts::PlayerByToken.call(params[:token])
      result = Accounts::UnbanPlayer.new.call(staff: current_player, player:)
      if result.success?
        redirect_to back_office_bans_path, notice: t(".unbanned", name: helpers.public_profile_title(player)), status: :see_other
      else
        redirect_to back_office_bans_path, alert: Accounts::UnbanPlayer.failure_message(result.failure), status: :see_other
      end
    end
  end
end
