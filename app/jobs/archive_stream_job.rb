class ArchiveStreamJob < ApplicationJob
  queue_as :default

  def perform(card_season_ids)
    settings = Game::Market::CurrentSettings.call
    I18n.available_locales.each { |locale| I18n.with_locale(locale) { broadcast(settings, card_season_ids) } }
  end

  private
    def broadcast(settings, card_season_ids)
      stream = ArchiveStream.streamables
      Catalog::CardViews.call(card_season_ids, locale: I18n.locale).each do |card_season_id, card|
        tiles = ApplicationController.helpers.archive_offer_selector(card)
        if (row = Game::Market::ArchiveOffers.find(settings:, card_season_id:, locale: I18n.locale))
          Turbo::StreamsChannel.broadcast_update_to(*stream, targets: "#{tiles} .archive-offer__stock", html: I18n.t("market.shops.offer.stock", count: row.stock))
        else
          Turbo::StreamsChannel.broadcast_remove_to(*stream, targets: tiles)
          Turbo::StreamsChannel.broadcast_action_to(*stream, action: "gameble-reload", target: ArchiveStream::PANEL)
        end
      end
    end
end
