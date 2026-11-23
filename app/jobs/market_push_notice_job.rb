class MarketPushNoticeJob < ApplicationJob
  queue_as :default

  def perform(notices)
    devices = Accounts::PushDevicesOf.call(notices.map { it[:player_id] }.uniq).select { PushNotices.deliverable?(it) }.group_by(&:player_id)

    notices.group_by { it[:player_id] }.each do |player_id, own|
      next unless devices.key?(player_id)

      devices[player_id].group_by(&:locale).each do |locale, targets|
        lines = Game::Market::MarketNotices.of_kinds(player_id:, listing_ids: own.filter_map { it[:listing_id] }, kinds: MarketPushNotice::KINDS, locale:) +
          Game::Market::OrderNoticeLines.of_orders(player_id:, order_ids: own.filter_map { it[:order_id] }, kinds: MarketPushNotice::ORDER_KINDS, locale:)
        lines.each { MarketPushNotice.notification(it, locale:).deliver_later_to(targets) }
      end
    end
  end
end
