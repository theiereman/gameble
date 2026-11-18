module MarketPushNotice
  EVENTS = [ Game::Market::BidPlaced, Game::Market::AuctionSold, Game::Market::AuctionUnsold, Game::Market::ListingWithdrawn,
    Game::Market::LeadVoided ].freeze

  KINDS = %w[outbid won sold unsold lead_voided withdrawn].freeze
  SALES_KINDS = %w[sold unsold lead_voided].freeze

  BATCHES = :market_push_notice_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |notices| MarketPushNoticeJob.perform_later(notices) }

  class << self
    def call(event)
      BATCH.add(notices(event))
    end

    def notices(event)
      data = event.data
      listing_id = data[:listing_id]
      players = case event
      when Game::Market::BidPlaced then data[:outbid_player_id] == data[:bidder_id] ? [] : [ data[:outbid_player_id] ]
      when Game::Market::AuctionSold then data.values_at(:winner_id, :seller_id)
      when Game::Market::AuctionUnsold, Game::Market::LeadVoided then [ data[:seller_id] ]
      when Game::Market::ListingWithdrawn then [ data[:leader_id] ]
      end
      players.compact.map { { player_id: it, listing_id: } }
    end

    def notification(line, locale:)
      I18n.with_locale(locale) do
        ApplicationPushNotification.with_data(path: path(line, locale)).new(
          title: I18n.t("push_notices.market_#{line.kind}.title"),
          body: I18n.t("push_notices.market_#{line.kind}.body", card: line.card, name: name(line.other), amount: amount(line.amount)),
          thread_id: "market"
        )
      end
    end

    private

    def path(line, locale)
      helpers = Rails.application.routes.url_helpers
      SALES_KINDS.include?(line.kind.to_s) ? helpers.market_my_sales_path(locale:) : helpers.market_listing_path(locale:, token: line.token)
    end

    def name(player) = player && Accounts::PersonaName.clean(player.persona_name) || I18n.t("shell.player.fallback_name")

    def amount(picoins) = ApplicationController.helpers.picoins_label(picoins.to_i)
  end
end
