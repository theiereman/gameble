class RobotsController < ApplicationController
  include PublicRead

  PRIVATE_SCREENS = %w[
    back-office settings booster packs packs-chip daily-bonus goal-rewards welcome account
    friends invite trades achievements more
  ].freeze

  def show
    authorize :page, :show?
    expires_in 1.hour, public: true
    render plain: Rails.configuration.x.search_indexing ? robots : closed_robots
  end

  CONTENT_SIGNAL = "Content-Signal: ai-train=no, search=yes, ai-input=yes".freeze
  CLOSED_CONTENT_SIGNAL = "Content-Signal: ai-train=no, search=no, ai-input=no".freeze

  private
    def closed_robots = "User-agent: *\n#{CLOSED_CONTENT_SIGNAL}\nDisallow: /\n"

    def robots
      lines = [ "User-agent: *", CONTENT_SIGNAL, "Disallow: /back-office", "Disallow: /auth/", "Disallow: /session" ]
      lines.concat(PRIVATE_SCREENS.map { "Disallow: /*/#{it}" })
      lines.push("", "Sitemap: #{helpers.public_url_for('/sitemap.xml')}").join("\n") + "\n"
    end
end
