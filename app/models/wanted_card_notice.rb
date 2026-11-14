module WantedCardNotice
  EVENTS = [ Game::Market::CardListed ].freeze

  QUIET_FOR = 1.hour

  BATCHES = :wanted_card_notice_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |listing_ids| listing_ids.each { WantedCardNoticeJob.perform_later(it) } }

  class << self
    def call(event)
      BATCH.add([ event.data[:listing_id] ])
    end

    def notification(listed, locale)
      I18n.with_locale(locale) do
        title = Game::Market::CardNames.call([ listed.card_season_id ], locale:)[listed.card_season_id]&.title
        ApplicationPushNotification.with_data(path: Rails.application.routes.url_helpers.market_listing_path(locale:, token: listed.token)).new(
          title: I18n.t("push_notices.card_wanted.title"),
          body: I18n.t("push_notices.card_wanted.body", card: title),
          thread_id: "market"
        )
      end
    end
  end
end
