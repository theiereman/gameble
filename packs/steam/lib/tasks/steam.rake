namespace :steam do
  # Meant for production: run after the deploys that give cards their
  # developers, franchises and themes and card-seasons their review count,
  # so the ones imported before them get them without a new import, and
  # before the draft is published. An app without a review count still
  # gives its card the names and themes.
  desc "Fills every card's developers, franchises and themes, and its card-seasons' missing review counts, " \
    "from the stored Steam apps (Catalog::FillCardSources); idempotent"
  task fill_card_sources: :environment do
    batch_size = 1_000
    apps = Steam::App.where.not(details: nil).select(:id, :appid, :details, :review_count, :tag_ids).order(:appid)
    filled = { cards: 0, card_seasons: 0 }
    last_appid = 0

    loop do
      batch = apps.where("appid > ?", last_appid).limit(batch_size).to_a
      break if batch.empty?

      tag_names = Steam::Tag.where(tagid: batch.flat_map { |app| Array(app.tag_ids) }.uniq).pluck(:tagid, :name).to_h
      result = Catalog::FillCardSources.new.call(rows: batch.map { |app| Steam::CardMapping.sources(app, tag_names:) })
      abort "steam:fill_card_sources: the apps after appid #{last_appid} failed: #{result.failure}" if result.failure?

      filled.merge!(result.value!) { |_key, total, count| total + count }
      last_appid = batch.last.appid
    end

    puts "steam:fill_card_sources: #{filled[:cards]} card(s) and #{filled[:card_seasons]} card-season(s) filled"
  end
end
