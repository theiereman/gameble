namespace :accounts do
  desc "Gives the player with this Steam id a role: player, moderator or administrator"
  task :set_role, %i[steam_id role] => :environment do |_task, args|
    result = Accounts::SetRole.new.call(steam_id: args[:steam_id].to_s, role: args[:role].to_s)
    abort "accounts:set_role: #{Accounts::SetRole.failure_message(result.failure)}" if result.failure?

    puts "accounts:set_role: the player with Steam id #{result.value!.steam_id} is now #{result.value!.role}"
  end
end
