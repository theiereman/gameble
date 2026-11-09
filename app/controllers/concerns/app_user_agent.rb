module AppUserAgent
  extend ActiveSupport::Concern

  # Android's web view sends its service worker's requests with the plain web view user agent instead of the app's.
  APP_AGENT_COOKIE = :app_agent
  NATIVE_AGENT = /(Turbo|Hotwire) Native/
  ANDROID_WEB_VIEW = /; wv\)/

  included do
    before_action :remember_app_agent
    helper_method :app_user_agent
  end

  def hotwire_native_app?
    NATIVE_AGENT.match?(app_user_agent)
  end

  private
    def app_user_agent
      @app_user_agent ||= sent_by_app_service_worker? ? cookies[APP_AGENT_COOKIE].to_s : request.user_agent.to_s
    end

    def sent_by_app?
      NATIVE_AGENT.match?(request.user_agent.to_s)
    end

    def sent_by_app_service_worker?
      !sent_by_app? && ANDROID_WEB_VIEW.match?(request.user_agent.to_s) && cookies[APP_AGENT_COOKIE].present?
    end

    def remember_app_agent
      return unless sent_by_app? && cookies[APP_AGENT_COOKIE] != request.user_agent

      cookies[APP_AGENT_COOKIE] = { value: request.user_agent, expires: 1.year.from_now, httponly: true, same_site: :lax }
    end
end
