class WantedCardNoticeJob < ApplicationJob
  queue_as :default

  def perform(listing_id)
    listed = Game::Market::WantedNoticePlayers.first_in(listing_id, quiet_for: WantedCardNotice::QUIET_FOR)
    return if listed.player_ids.empty?

    devices = Accounts::PushDevicesOf.call(listed.player_ids).select { PushNotices.deliverable?(it) }
    devices.group_by(&:locale).each do |locale, targets|
      WantedCardNotice.notification(listed, locale).deliver_later_to(targets)
    end
  end
end
