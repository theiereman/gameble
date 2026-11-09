# Runs a test as if production ran `version`, read from GAMEBLE_VERSION as the deploy sets it.
module RunningRelease
  def self.included(test_case)
    test_case.setup { @running_release_was = ENV["GAMEBLE_VERSION"] }
    test_case.teardown { ENV["GAMEBLE_VERSION"] = @running_release_was }
  end

  def run_release(version)
    ENV["GAMEBLE_VERSION"] = version
  end

  def write_release_note(version, state: "ready", title_en: "Capsules open at once", body_en: "## New\n- Capsules open at once")
    Accounts::CreateReleaseNote.new.call(staff: accounts_players(:administrator), version:, state:,
      title_fr: "Les capsules s'ouvrent d'un coup", title_en:, body_fr: "## Nouveautés\n- Les capsules s'ouvrent d'un coup", body_en:).value!
  end
end
