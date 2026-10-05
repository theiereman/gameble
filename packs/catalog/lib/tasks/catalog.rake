namespace :catalog do
  # Meant for production: run once after the deploy that adds
  # catalog_card_seasons.number (AD-28, the expand step), before the
  # migration that makes it NOT NULL for published card-seasons.
  desc "Numbers the cards of every published season that has no numbers yet (Catalog::PublishSeason#number_published); idempotent"
  task number_seasons: :environment do
    Catalog::Season.published.order(:number).pluck(:number).each do |number|
      result = Catalog::PublishSeason.new.number_published(number:)
      if result.success?
        puts "catalog:number_seasons: season #{number} numbered"
      elsif result.failure == :already_numbered
        puts "catalog:number_seasons: season #{number} already numbered"
      else
        abort "catalog:number_seasons: season #{number} failed: #{result.failure}"
      end
    end
  end
end
