# The Content-Security-Policy (AD-27). It runs report-only in every
# environment for one release: violations are reported (to Sentry where
# SENTRY_DSN is set), nothing is blocked. Enforcement is a later step.
#
# No inline script anywhere: script-src is 'self'. Nonces cover styles only
# (Turbo's progress bar style reads its nonce from csp_meta_tag). Card images
# come from Steam's CDN, read by the pixel-art filter with crossOrigin, hence
# the Steam hosts in img-src and connect-src; the cable connects to the
# public origin over ws(s). Vite may inline small assets as data: URIs.
#
# Sources that read app code or configuration are procs, resolved per
# request: nothing is autoloaded at boot, and config.x.public_url is read as
# it stands.
#
# Development adds the Vite dev server: its scripts (and React refresh's
# inline preamble), its styles (inline, injected by Vite, hence no nonce
# there: a nonce would make browsers ignore 'unsafe-inline') and its
# websocket.
#
# See the Securing Rails Applications Guide:
# https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  steam_images = -> { Steam::Cdn::IMAGE_SOURCES }
  # The cable's origin: the public base with http(s) turned into ws(s); none
  # when PUBLIC_URL is unset (then 'self' covers same-origin in recent
  # browsers).
  cable = -> { Rails.configuration.x.public_url&.sub(/\Ahttp/, "ws") }
  # The Vite dev server, in development only.
  vite = ViteRuby.config.host_with_port if Rails.env.development?
  dev_scripts = vite ? [ :unsafe_inline, :unsafe_eval, "http://#{vite}" ] : []
  dev_styles = vite ? [ :unsafe_inline, "http://#{vite}" ] : []
  dev_connections = vite ? [ "ws://#{vite}", "http://#{vite}" ] : []

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.script_src :self, *dev_scripts
    policy.style_src :self, *dev_styles
    policy.img_src :self, :data, steam_images
    policy.font_src :self
    policy.worker_src :self, :blob
    policy.connect_src :self, steam_images, cable, *dev_connections

    # Sentry is initialised after this file (config/initializers/sentry.rb):
    # the report URI is read per request.
    policy.report_uri -> { Sentry.csp_report_uri } if ENV["SENTRY_DSN"].present?
  end

  # The session id: stable across Turbo visits, so a page Turbo swaps in
  # keeps a valid nonce (the Rails default). A page's csrf_meta_tags comes
  # before csp_meta_tag in the layout and gives a visitor's new session its
  # id first; a response that never loaded the session (or the test
  # environment, without CSRF tags) gets a random nonce for that request
  # rather than an empty, invalid one.
  config.content_security_policy_nonce_generator = lambda do |request|
    request.session.id.to_s.presence || SecureRandom.base64(16)
  end
  config.content_security_policy_nonce_directives = Rails.env.development? ? [] : %w[style-src]

  config.content_security_policy_report_only = true
end
