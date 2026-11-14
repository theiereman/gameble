class AddWantedToGameMarketNotices < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :game_market_notices, "kind ~ '^(outbid|won|sold|unsold|lead_voided|withdrawn)$'",
      name: "game_market_notices_kind_check"
    add_check_constraint :game_market_notices, "kind ~ '^(outbid|won|sold|unsold|lead_voided|withdrawn|wanted)$'",
      name: "game_market_notices_kind_check", validate: false
  end
end
