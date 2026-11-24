module BackOffice
  class CreditDonorsController < BaseController
    rate_limit to: 30, within: 1.minute, only: %i[create destroy]

    def index
      authorize [ :back_office, :credit_donors ], :index?
      @donors = Accounts::CreditDonors.in_order_of_arrival
    end

    def create
      authorize [ :back_office, :credit_donors ], :create?

      result = Accounts::AddCreditDonor.new.call(staff: current_player, name: params[:name])
      respond(result, Accounts::AddCreditDonor, t(".added"))
    end

    def destroy
      authorize [ :back_office, :credit_donors ], :destroy?

      result = Accounts::RemoveCreditDonor.new.call(staff: current_player, donor: Accounts::CreditDonors.by_token(params[:token]))
      respond(result, Accounts::RemoveCreditDonor, t(".removed"))
    end

    private
      def respond(result, operation, notice)
        if result.success?
          redirect_to back_office_credit_donors_path, notice:, status: :see_other
        else
          redirect_refused operation, result, back_office_credit_donors_path
        end
      end
  end
end
