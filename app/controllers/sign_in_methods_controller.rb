class SignInMethodsController < ApplicationController
  include OpensPlayerSession

  def create
    authorize :sign_in_method, :create?

    before = Accounts::IdentitiesOf.call(current_player).size
    result = add_reporting_failure
    if result&.success?
      added = Accounts::IdentitiesOf.call(current_player).size > before
      redirect_to settings_path, notice: (added ? t(".added") : t(".already_added")), status: :see_other
    else
      redirect_to settings_path, alert: refusal_message(result), status: :see_other
    end
  end

  private
    def add_reporting_failure
      Accounts::AddClerkSignIn.new.call(player: current_player, session_token: clerk_session_token)
    rescue StandardError => error
      Rails.error.report(error)
      nil
    end

    def refusal_message(result)
      key = result && Accounts::AddClerkSignIn.failure_key(result.failure)
      I18n.exists?(key.to_s) ? t(key) : t("errors.accounts.sign_in_failed")
    end
end
