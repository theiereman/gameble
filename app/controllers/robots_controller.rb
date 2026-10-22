class RobotsController < ApplicationController
  include PublicRead

  PRIVATE_SCREENS = %w[
    back-office settings booster packs packs-chip daily-bonus goal-rewards welcome account
    friends invite trades achievements more
  ].freeze

  def show
    authorize :page, :show?
    expires_in 1.hour, public: true
    render plain: robots
  end

  private
    def robots
      lines = [ "User-agent: *", "Disallow: /back-office", "Disallow: /auth/", "Disallow: /session" ]
      lines.concat(PRIVATE_SCREENS.map { "Disallow: /*/#{it}" })
      lines.push("", "Sitemap: #{helpers.public_url_for('/sitemap.xml')}").join("\n") + "\n"
    end
end
