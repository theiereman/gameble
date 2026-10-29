class ClerkSessionsController < ApplicationController
  include OpensPlayerSession

  def create
    authorize :clerk_session, :create?

    result = sign_in_reporting_failure
    return fail_sign_in("errors.accounts.sign_in_failed") if result.nil?
    return refuse_banned if result.failure == :banned
    return fail_sign_in(Accounts::SignInThroughClerk.failure_key(result.failure)) if result.failure?

    player = open_session_for(result.value!)
    redirect_signed_in(player, origin_path)
  end

  private
    def sign_in_reporting_failure
      Accounts::SignInThroughClerk.new.call(session_token: clerk_session_token)
    rescue StandardError => error
      Rails.error.report(error)
      nil
    end

    def fail_sign_in(key)
      key = "errors.accounts.sign_in_failed" unless I18n.exists?(key)
      redirect_to sign_in_path(origin: origin_path), alert: t(key), status: :see_other
    end

    def refuse_banned
      @ban_reason = Accounts::CurrentBanReason.through_clerk(clerk_session_token)
      render "sessions/banned", status: :forbidden
    end

    def origin_path
      safe_origin_path(params[:origin])
    end
end
