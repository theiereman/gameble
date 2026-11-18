module Accounts
  class UpdateSettings < ApplicationOperation
    UNSET = Object.new.freeze
    private_constant :UNSET

    def call(player:, reduced_motion: UNSET, rarity_aura: UNSET)
      player = step require_player(player)
      attributes = step check(reduced_motion:, rarity_aura:)

      transaction do
        player.update!(attributes)
        player
      end
    end

    private

    def require_player(player)
      player.is_a?(Player) && player.persisted? && !player.banned? ? Success(player) : Failure(:player_required)
    end

    def check(reduced_motion:, rarity_aura:)
      attributes = {}
      attributes[:reduced_motion] = reduced_motion unless UNSET.equal?(reduced_motion)
      attributes[:rarity_aura] = rarity_aura unless UNSET.equal?(rarity_aura)

      valid = [ true, false, nil ].include?(attributes.fetch(:reduced_motion, nil)) && [ true, false ].include?(attributes.fetch(:rarity_aura, true))
      valid ? Success(attributes) : Failure(:invalid_setting)
    end
  end
end
