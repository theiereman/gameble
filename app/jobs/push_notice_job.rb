class PushNoticeJob < ApplicationJob
  queue_as :default

  def perform(notices)
    devices = Accounts::PushDevicesOf.call(notices.map { it[:player_id] }.uniq).select { PushNotices.deliverable?(it) }.group_by(&:player_id)
    return if devices.empty?

    notices.each do |notice|
      own = devices[notice[:player_id]]
      actor = own && Accounts::PlayerById.call(notice[:actor_id])
      next if actor.nil? || actor.removed?

      actor_name = Accounts::PersonaName.clean(actor.persona_name) || I18n.t("shell.player.fallback_name")
      own.group_by(&:locale).each do |locale, targets|
        PushNotices.notification(notice[:kind], actor_name:, locale:).deliver_later_to(targets)
      end
    end
  end
end
