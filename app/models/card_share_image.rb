require "digest"

# The image a shared card's link previews with: one per published
# card-season and language, rendered by CardShareImageJob, never in a
# request, and served by token from ShareImagesController.
module CardShareImage
  WIDTH = 1200
  HEIGHT = 630
  CONTENT_TYPE = "image/png".freeze

  # Bumping it renders every image again, as each card page is next opened.
  RENDER_VERSION = 1

  RENDER_THROTTLE = 1.hour
  FAILURE_HOLD_OFF = 1.day

  # What the image shows: the view, and the words it draws in the locale.
  def self.fingerprint(view, locale)
    words = I18n.with_locale(locale) do
      [ CardStrings.new.rarity_name(view.rarity), view.genre && SetLabel.genre(view.genre), view.number && view.number_label ]
    end
    Digest::SHA256.hexdigest([ RENDER_VERSION, locale.to_s, view.to_h.sort, words ].to_json)
  end

  # The token of the card-season's image when it shows the view as it is
  # now; otherwise nil, with its render enqueued at most once an hour.
  def self.current_token(card_season_id:, view:, locale:)
    fingerprint = fingerprint(view, locale)
    stored = Catalog::ShareImageFor.call(card_season_id:, locale:)
    return stored.token if stored&.fingerprint == fingerprint

    render_later(card_season_id, locale, fingerprint)
    nil
  end

  # A render that failed is not enqueued again from the page for a day.
  def self.hold_off(card_season_id, locale, fingerprint)
    Rails.cache.write(throttle_key(card_season_id, locale, fingerprint), true, expires_in: FAILURE_HOLD_OFF)
  end

  def self.render_later(card_season_id, locale, fingerprint)
    written = Rails.cache.write(throttle_key(card_season_id, locale, fingerprint), true, unless_exist: true, expires_in: RENDER_THROTTLE)
    CardShareImageJob.perform_later(card_season_id, locale.to_s) if written
  end
  private_class_method :render_later

  def self.throttle_key(card_season_id, locale, fingerprint)
    [ "card_share_image", card_season_id, locale.to_s, fingerprint ].join("/")
  end
  private_class_method :throttle_key
end
