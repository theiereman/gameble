namespace :catalog do
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
