module BackOffice
  class BansController < ApplicationController
    rate_limit to: 10, within: 1.minute, only: %i[create destroy]

    def create
      authorize [ :back_office, :bans ], :create?
      moderate(Accounts::BanPlayer, done: t(".banned"))
    end

    def destroy
      authorize [ :back_office, :bans ], :destroy?
      moderate(Accounts::UnbanPlayer, done: t(".unbanned"))
    end

    private
      def moderate(operation, done:)
        result = operation.new.call(actor: current_player, player: Accounts::PlayerByToken.call(params[:token]))
        if result.success?
          redirect_to back_office_reports_path, notice: done, status: :see_other
        else
          redirect_to back_office_reports_path, alert: operation.failure_message(result.failure), status: :see_other
        end
      end
  end
end
