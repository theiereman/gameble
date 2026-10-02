namespace :game do
  desc "Tops up to ten every bank left short by earlier builds (Game::FillEmptyBanksJob, run now); idempotent"
  task top_up_banks: :environment do
    abort "game:top_up_banks heals development data only" if Rails.env.production?

    # The job's walker: one transaction per player, a failing player reported
    # and skipped.
    Game::FillEmptyBanksJob.perform_now
  end
end
