module Game
  class SetFeatureFlag < Operation
    def call(player:, key:, enabled:)
      step administrator(player)
      step known_key(key)

      transaction do
        now = Time.current
        FeatureFlag.upsert({ key:, enabled:, created_at: now, updated_at: now }, unique_by: :key, record_timestamps: false,
          on_duplicate: Arel.sql("enabled = excluded.enabled, updated_at = excluded.updated_at"))
        EnabledFeatures.reload
        step publish(FeatureFlagSet.new(data: { key:, enabled:, staff_id: player.id }), stream_name: stream_name(player.id))
        enabled
      end
    end

    private

    def administrator(player)
      Accounts::Player.acting_staff?(player) && player.administrator? ? Success() : Failure(:administrator_required)
    end

    def known_key(key)
      FeatureFlag::KEYS.include?(key) ? Success() : Failure(:unknown_feature)
    end
  end
end
