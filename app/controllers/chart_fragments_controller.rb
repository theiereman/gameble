class ChartFragmentsController < ApplicationController
  include PublicRead

  CACHE_LIFETIME = 365.days
  KINDS = %w[reactor rarity_prices].freeze

  skip_before_action :set_sentry_user, :note_presence
  # A shared cache refuses to store a response that sets a cookie.
  before_action { request.session_options[:skip] = true }

  def show
    authorize %i[market chart_fragment], :show?
    kind = params[:kind]
    resolver = ChartVersions.for(kind)
    raise ActiveRecord::RecordNotFound unless KINDS.include?(kind) && resolver.current?(params[:version]) && published?(kind)

    expires_in CACHE_LIFETIME, public: true, immutable: true
    render html: cached_fragment(kind, resolver).html_safe, layout: false
  end

  def self.cache_key(locale, kind, version) = [ "chart-fragments", locale.to_s, kind, version ]

  private
    def pundit_user = nil

    def published?(kind) = Game::Market::ChartPublications.published_kinds.include?(kind)

    def cached_fragment(kind, resolver)
      Rails.cache.fetch(self.class.cache_key(I18n.locale, kind, resolver.version), expires_in: CACHE_LIFETIME) do
        render_to_string(template: "chart_fragments/#{kind}", layout: false, locals: { through: resolver.drawn_through })
      end
    end
end
