# The Content-Security-Policy, enforced in every environment; violations are
# reported to Sentry where SENTRY_DSN is set.
#
# No inline script: script-src is 'self'. Nonces cover styles (Turbo's
# progress bar style reads its nonce from csp_meta_tag); scripts are nonced
# only for Mission Control Jobs, whose importmap is inline
# (BackOffice::JobsBaseController). Card images come from Steam's CDN, read
# by the pixel-art filter with crossOrigin, hence the Steam hosts in img-src
# and connect-src; the cable connects to the public origin over ws(s). Vite
# may inline small assets as data: URIs; fonts are allowed as data: URIs too.
#
# Clerk's Frontend API and its bot protection (Cloudflare's captcha, Clerk's
# script and probes) are allowed on every page, not only where Clerk signs
# in: a Turbo visit keeps the CSP of the document it started from. The
# probes load a script from a per-visitor subdomain and connect to it on
# several ports (443, 992, 2082, 8443, 18443), hence the port wildcard.
#
# Cloudflare, in front of the app, injects its Web Analytics beacon: a script
# from static.cloudflareinsights.com that reports to cloudflareinsights.com.
#
# Sources that read app code or configuration are procs, resolved per
# request: nothing is autoloaded at boot, and config.x.public_url is read as
# it stands.
#
# Development adds the Vite dev server: its module scripts (no inline
# script there either), its styles (inline, injected by Vite, hence no nonce
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
  dev_scripts = vite ? [ "http://#{vite}" ] : []
  dev_styles = vite ? [ :unsafe_inline, "http://#{vite}" ] : []
  dev_connections = vite ? [ "ws://#{vite}", "http://#{vite}" ] : []
  clerk_api = -> { Rails.configuration.x.clerk.frontend_api&.then { "https://#{it}" } }
  clerk_bot_protection = [ "https://challenges.cloudflare.com", "https://cdn.protect.clerk.com" ]
  clerk_probe_scripts = "https://*.client.protect.clerk.com"
  clerk_probes = "https://*.client.protect.clerk.com:*"
  cloudflare_beacon = "https://static.cloudflareinsights.com"
  cloudflare_analytics = "https://cloudflareinsights.com"

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.script_src :self, *clerk_bot_protection, clerk_probe_scripts, cloudflare_beacon, *dev_scripts
    policy.style_src :self, *dev_styles
    policy.img_src :self, :data, steam_images
    policy.font_src :self, :data
    policy.worker_src :self, :blob
    policy.connect_src :self, steam_images, cable, clerk_api, *clerk_bot_protection, clerk_probes, cloudflare_analytics, *dev_connections
    policy.frame_src :self, *clerk_bot_protection

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
  # Development nonces scripts, not styles: web-console's in-view console is
  # an inline script tagged with the nonce, and Vite's styles are inline.
  config.content_security_policy_nonce_directives = Rails.env.development? ? %w[script-src] : %w[style-src]
end
