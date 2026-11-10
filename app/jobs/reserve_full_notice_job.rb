class ReserveFullNoticeJob < ApplicationJob
  queue_as :default

  def perform(player_id, full_at)
    return unless ReserveFullNotice.still_due?(player_id, full_at)

    devices = Accounts::PushDevicesOf.call([ player_id ]).select { PushNotices.deliverable?(it) }
    devices.group_by(&:locale).each do |locale, targets|
      ReserveFullNotice.notification(locale).deliver_later_to(targets)
    end
  end
end
