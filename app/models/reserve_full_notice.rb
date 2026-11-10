module ReserveFullNotice
  EVENTS = [ Game::PackOpened ].freeze

  SHORTEST_REFILL = 30.minutes

  class << self
    def call(event)
      data = event.data
      return unless Game::Reserve.refilled_by?(data[:pack_id])

      full_at = Game::Reserve.full_at(data[:player_id])
      return if full_at.nil? || full_at < Time.current + SHORTEST_REFILL

      ReserveFullNoticeJob.set(wait_until: full_at).perform_later(data[:player_id], full_at)
    end

    def still_due?(player_id, full_at)
      current = Game::Reserve.full_at(player_id)
      current.present? && (current - full_at).abs < 1.second && current <= Time.current
    end

    def notification(locale)
      I18n.with_locale(locale) do
        ApplicationPushNotification.with_data(path: Rails.application.routes.url_helpers.booster_path(locale:)).new(
          title: I18n.t("push_notices.reserve_full.title"),
          body: I18n.t("push_notices.reserve_full.body", number: Game::Reserve::FULL),
          thread_id: "reserve"
        )
      end
    end
  end
end
