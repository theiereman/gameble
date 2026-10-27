module Accounts
  module LastExportOf
    LastExport = Data.define(:file, :exported_at)

    def self.call(player)
      file = DataExport.where(player_id: player.id).pick(:file)
      file && player.last_exported_at && LastExport.new(file:, exported_at: player.last_exported_at)
    end
  end
end
