module BackOffice
  class CodeContributionsController < BaseController
    rate_limit to: 30, within: 1.minute, only: :create

    def create
      authorize [ :back_office, :code_contributions ], :create?

      player = Accounts::PlayerByToken.call(params[:token])
      result = Game::GrantCodeContribution.new.call(staff: current_player, player:)
      if result.success?
        redirect_to players_return_path, notice: t(".granted", name: helpers.public_profile_title(player)), status: :see_other
      else
        redirect_refused Game::GrantCodeContribution, result, players_return_path
      end
    end

    private
      def players_return_path
        page = params[:page].to_s.to_i
        back_office_players_path(q: Accounts::PlayerSearch.normalize(params[:q]).presence, page: (page if page > 1))
      end
  end
end
