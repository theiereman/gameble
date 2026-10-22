# Pages read from a shared link (CAP-9, CAP-18): a public profile, a card's
# page (the form a share link takes), the grid of every card and a visitor's
# root, the landing.
# Any browser and link-preview crawler (Discordbot, Twitterbot, WhatsApp, an
# older Safari or Firefox) may read them, so ApplicationController's
# modern-browser check (allow_browser) skips their GET and HEAD requests;
# every other request, and every other page, stays modern-only.
module PublicRead
  extend ActiveSupport::Concern

  private
    def public_read?
      request.get? || request.head?
    end
end
