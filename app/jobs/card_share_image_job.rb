require "vips"

class CardShareImageJob < ApplicationJob
  class NotStored < StandardError; end

  queue_as :share_images

  def perform(card_season_id, locale)
    return unless I18n.available_locales.map(&:to_s).include?(locale.to_s)

    I18n.with_locale(locale) { render_and_store(card_season_id, locale.to_s) }
  end

  private

  def render_and_store(card_season_id, locale)
    view = Catalog::CardViews.call([ card_season_id ], locale:)[card_season_id]
    return if view.nil?

    fingerprint = CardShareImage.fingerprint(view, locale)
    return if Catalog::ShareImageFor.call(card_season_id:, locale:)&.fingerprint == fingerprint

    store(card_season_id, locale, fingerprint, view)
  rescue CardShareImage::Art::Unusable, Vips::Error => error
    report(error, card_season_id, locale, fingerprint)
  end

  def store(card_season_id, locale, fingerprint, view)
    png = CardShareImage::Composition.new(view, CardShareImage::Art.new(view.image_url).pixels).png
    result = Catalog::StoreShareImage.new.call(card_season_id:, locale:, fingerprint:, png:,
      width: CardShareImage::WIDTH, height: CardShareImage::HEIGHT,
      current_fingerprint: -> { CardShareImage.fingerprint_of(card_season_id, locale) })
    report(NotStored.new(result.failure.to_s), card_season_id, locale, fingerprint) if result.failure? && result.failure != :stale_render
  end

  def report(error, card_season_id, locale, fingerprint)
    Rails.error.report(error, handled: true, context: { card_season_id:, locale: })
    CardShareImage.hold_off(card_season_id, locale, fingerprint) if fingerprint
  end
end
