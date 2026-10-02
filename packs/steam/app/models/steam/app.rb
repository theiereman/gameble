module Steam
  # A Steam app as GetAppList lists it, games only (AD-4): raw Steam data,
  # one row per appid. Written by Steam::ImportAppListPage with an upsert on
  # appid, so a page imported twice changes nothing twice.
  class App < ApplicationRecord
    self.table_name = "steam_apps"

    belongs_to :import_run, class_name: "Steam::ImportRun", inverse_of: :apps
  end
end
