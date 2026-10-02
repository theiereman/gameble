namespace :game do
  desc "Runs Game::HealBanksJob now: ten packs for players who never had one, short banks topped up to ten; idempotent"
  task top_up_banks: :environment do
    abort "game:top_up_banks heals development data only" if Rails.env.production?

    # The job's walker: one transaction per player, a failing player reported
    # and skipped.
    Game::HealBanksJob.perform_now
  end
end
