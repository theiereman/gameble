namespace :game do
  desc "Runs Game::HealBanksJob now: ten packs for players who never had one, short banks topped up to ten; idempotent"
  task top_up_banks: :environment do
    abort "game:top_up_banks heals development data only" if Rails.env.production?

    # The job's walker: one transaction per player, a failing player reported
    # and skipped.
    Game::HealBanksJob.perform_now
  end

  # Meant for production: run once after the deploy that creates
  # game_player_states (AD-28).
  desc "Runs Game::BackfillPlayerStatesJob now: a game_player_states row for every player without one, banned included; idempotent"
  task backfill_player_states: :environment do
    # One transaction per player, a failing player reported and skipped:
    # the operator is told how many are left, and the task fails if any.
    Game::BackfillPlayerStatesJob.perform_now
    missing = Game::BackfillPlayerStatesJob.players_without_a_row
    if missing.positive?
      abort "game:backfill_player_states: #{missing} player(s) still without a game_player_states row " \
        "(failures reported to the error tracker); fix them and rerun"
    end

    puts "game:backfill_player_states: every player has their game_player_states row"
  end
end
