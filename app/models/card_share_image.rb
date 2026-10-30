require "digest"

module CardShareImage
  WIDTH = 1200
  HEIGHT = 630
  CONTENT_TYPE = "image/png".freeze
  MAX_BYTES = 300.kilobytes

  RENDER_VERSION = 1

  RENDER_THROTTLE = 1.hour
  FAILURE_HOLD_OFF = 1.day

  def self.fingerprint(view, locale)
    words = I18n.with_locale(locale) do
      [ CardStrings.new.rarity_name(view.rarity), view.genre && SetLabel.genre(view.genre), view.number && view.number_label ]
    end
    Digest::SHA256.hexdigest([ RENDER_VERSION, locale.to_s, view.to_h.sort, words ].to_json)
  end

  def self.fingerprint_of(card_season_id, locale)
    view = Catalog::CardViews.call([ card_season_id ], locale:)[card_season_id]
    view && fingerprint(view, locale)
  end

  def self.current_token(card_season_id:, view:, locale:)
    fingerprint = fingerprint(view, locale)
    stored = Catalog::ShareImageFor.call(card_season_id:, locale:)
    return stored.token if stored&.fingerprint == fingerprint

    render_later(card_season_id, locale, fingerprint)
    nil
  end

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
