module Accounts
  class RegisterPushDevice < ApplicationOperation
    def call(player:, platform:, token:, locale:)
      player = step require_player(player)
      attributes = step check(platform:, token:, locale:)

      transaction do
        device = PushDevice.lock.find_or_initialize_by(token: attributes[:token])
        device.update!(attributes.merge(player:))
        device
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.removed? ? Success(player) : Failure(:player_required)
    end

    def check(platform:, token:, locale:)
      device = PushDevice.new(platform:, token:, locale:)
      device.validate
      %i[platform token locale].any? { device.errors.include?(it) } ? Failure(:invalid_push_device) : Success({ platform:, token:, locale: })
    end
  end
end
