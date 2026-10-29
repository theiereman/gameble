class SessionsController < ApplicationController
  include OpensPlayerSession

  SIGN_IN_STARTED = "steam_sign_in_started".freeze

  # rack-openid relabels Steam's GET return as POST, so it carries no authenticity token.
  skip_forgery_protection only: :create
  # OmniAuth's test mode sends the callback as a real GET, and signing in writes.
  skip_around_action :read_only_unless_writing, only: :create

  ORIGIN_PATH = %r{\A/(?:#{I18n.available_locales.join("|")})(?:/[^\\\s]*)?\z}
  INVITE_PATH = %r{\A/(?:#{I18n.available_locales.join("|")})/invite/[1-9A-HJ-NP-Za-km-z]{24}\z}

  def create
    authorize :session
    return fail_sign_in("errors.steam.sign_in_failed") unless sign_in_started_in_this_browser?

    result = Steam::SignInIdentity.steam_id_from(request.env["omniauth.auth"])
    return fail_sign_in(Steam::SignInIdentity.failure_key(result.failure)) if result.failure?

    steam_id = result.value!
    result = sign_in_reporting_failure(steam_id)
    return fail_sign_in(Accounts::SignIn.failure_key(:sign_in_failed)) if result.nil?
    return refuse_banned(steam_id) if result.failure == :banned
    return fail_sign_in(Accounts::SignIn.failure_key(result.failure)) if result.failure?

    player = carry_visitor_motion_switch(result.value!)
    reset_session
    session[:player_id] = player.id
    if (invite = invite_origin)
      redirect_to invite, notice: t(".welcome")
    else
      redirect_to home_path, notice: (t(".welcome") unless player.welcome_pending), flash: { signed_in: true }
    end
  end

  def failure
    authorize :session
    sign_in_started_in_this_browser?
    fail_sign_in("errors.steam.sign_in_failed")
  end

  def destroy
    authorize :session
    write_motion_cookie(current_player.reduced_motion)
    reset_session
    redirect_to home_path, notice: t(".farewell")
  end

  private
    def sign_in_reporting_failure(steam_id)
      Accounts::SignIn.new.call(steam_id:, persona_name: persona_name_or_nil(steam_id))
    rescue StandardError => error
      Rails.error.report(error)
      nil
    end

    def persona_name_or_nil(steam_id)
      Steam::WebApi.new.get_player_summary(steamid: steam_id)
    rescue Steam::WebApi::BrokenKey => error
      Rails.error.report(error)
      nil
    rescue Steam::WebApi::Error => error
      Rails.logger.warn("Steam persona name not read at sign-in: #{error.message}")
      nil
    rescue StandardError => error
      Rails.error.report(error)
      nil
    end

    def sign_in_started_in_this_browser?
      session.delete(SIGN_IN_STARTED).present?
    end

    def fail_sign_in(key)
      redirect_to return_path, alert: t(key)
    end

    def refuse_banned(steam_id)
      @ban_reason = Accounts::CurrentBanReason.call(steam_id)
      render :banned, status: :forbidden
    end

    def requested_locale
      params[:locale] || origin_path&.split("/")&.at(1)
    end

    def invite_origin
      origin = origin_path
      origin if origin && INVITE_PATH.match?(origin)
    end

    def return_path
      origin_path || home_path
    end

    def origin_path
      origin = request.env["omniauth.origin"] || params[:origin]
      return nil unless origin.is_a?(String)

      path = origin.split(/[?#]/, 2).first
      path if ORIGIN_PATH.match?(path)
    end
end
