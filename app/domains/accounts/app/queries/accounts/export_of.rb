module Accounts
  module ExportOf
    Profile = Data.define(:steam_id, :persona_name, :visibility, :reduced_motion, :created_at, :last_seen_at, :last_exported_at)
    ReportFiled = Data.define(:reason, :created_at)
    ReportReceived = Data.define(:reason, :created_at, :handled_at)
    Decision = Data.define(:kind, :created_at, :reason)
    IdentityEntry = Data.define(:provider, :created_at)
    Result = Data.define(:profile, :identities, :reports_filed, :reports_received, :decisions)

    def self.call(player)
      Result.new(
        profile: profile(player),
        identities: Identity.where(player_id: player.id).order(:created_at, :id)
          .pluck(:provider, :created_at).map { |provider, created_at| IdentityEntry.new(provider:, created_at:) },
        reports_filed: Report.where(reporter_id: player.id).order(:created_at, :id)
          .pluck(:reason, :created_at).map { |reason, created_at| ReportFiled.new(reason:, created_at:) },
        reports_received: Report.where(reported_id: player.id).order(:created_at, :id)
          .pluck(:reason, :created_at, :handled_at)
          .map { |reason, created_at, handled_at| ReportReceived.new(reason:, created_at:, handled_at:) },
        decisions: ModerationAction.where(player_id: player.id).order(:created_at, :id)
          .pluck(:kind, :created_at, :reason).map { |kind, created_at, reason| Decision.new(kind:, created_at:, reason:) }
      )
    end

    def self.profile(player)
      Profile.new(steam_id: player.steam_id, persona_name: player.persona_name, visibility: player.visibility,
        reduced_motion: player.reduced_motion, created_at: player.created_at, last_seen_at: player.last_seen_at,
        last_exported_at: player.last_exported_at)
    end
    private_class_method :profile
  end
end
