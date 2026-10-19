# Read-only. Measures, on the latest published season, the UFOs' share
# without and with an Adventure theme, and with the candidate narrative tags
# added to it. Works before and after the deploy: the base list is
# Catalog::Themes::TAGS without "adventure".
# Run like the spike's probes:
#   ssh ... 'docker exec -i <web container> bin/rails runner -' < bug-the-capsule-reveal-card-shows-no-game-category-probe.rb
ActiveRecord::Base.while_preventing_writes do
  conn = ActiveRecord::Base.connection
  q = ->(sql) { conn.select_rows(sql) }
  pct = ->(n, d) { d.zero? ? "0" : format("%.2f%%", 100.0 * n / d) }
  ints = ->(v) { v.is_a?(Array) ? v.map(&:to_i) : v.to_s.delete("{}").split(",").map(&:to_i) }

  season_id = q.("select id from catalog_seasons where status = 'published' order by number desc limit 1").first&.first
  rows = q.(<<~SQL)
    select a.appid, a.name_en, a.tag_ids
    from catalog_card_seasons cs
    join catalog_cards c on c.id = cs.card_id
    join steam_apps a on 'steam:' || a.appid = c.source_key
    where cs.season_id = #{season_id.to_i}
  SQL
  games = rows.map { |appid, name, tags| { appid: appid.to_i, name: name.to_s, top5: ints.(tags).first(5) } }
  n = games.size
  puts "== season id #{season_id}: #{n} cards"
  total, stored = q.("select count(*), count(*) filter (where main_theme is null) from catalog_card_seasons where season_id = #{season_id.to_i}").first.map(&:to_i)
  puts "stored UFOs of the season (no main theme): #{stored} of #{total} (#{pct.(stored, total)}); the figures below use today's tags"

  ids = q.("select name, tagid from steam_tags").to_h { |name, id| [ name, id.to_i ] }
  base = Catalog::Themes::TAGS.except("adventure")
  candidates = {
    "Adventure" => [ "Adventure" ],
    "Adventure + Action-Adventure" => [ "Adventure", "Action-Adventure" ],
    "Adventure + Story Rich" => [ "Adventure", "Story Rich" ],
    "Adventure + Story Rich + Female Protagonist" => [ "Adventure", "Story Rich", "Female Protagonist" ]
  }
  puts "names not found: #{(base.values.flatten + candidates.values.flatten).uniq.reject { ids[_1] }.inspect}"

  to_ids = ->(themes) { themes.transform_values { |tags| tags.filter_map { ids[_1] } } }
  main_theme = ->(game, themes) { game[:top5].each { |tag| themes.each { |key, tags| return key if tags.include?(tag) } }; nil }
  measure = lambda do |label, themes|
    theme_ids = to_ids.(themes)
    mains = games.map { main_theme.(_1, theme_ids) }
    ufos = mains.count(&:nil?)
    puts "#{label}: UFOs #{ufos} (#{pct.(ufos, n)})"
    mains
  end

  before = measure.("before (#{base.size} themes)", base)
  candidates.each do |label, tags|
    after = measure.("with #{label}", base.merge("adventure" => tags))
    set_size = games.count { |game| (game[:top5] & tags.filter_map { ids[_1] }).any? }
    moved = before.zip(after).select { |was, now| now == "adventure" }.group_by(&:first).transform_values(&:size)
    puts "  adventure set: #{set_size} cards; main theme now adventure: #{moved.values.sum} " \
      "(from UFOs #{moved.fetch(nil, 0)}; from another theme #{moved.except(nil).values.sum}: " +
      moved.except(nil).sort_by { -_2 }.first(10).map { "#{_1} #{_2}" }.join(", ") + ")"
  end

  dreamfall = games.find { _1[:appid] == 6300 }
  names = ids.invert
  puts "Dreamfall (6300): " + (dreamfall ? dreamfall[:top5].map { names[_1] || _1 }.join(", ") : "not in the season")
end
