require "test_helper"

class Catalog::CardSlugTest < ActiveSupport::TestCase
  def card(title:, source_key:, release_date: Date.new(2011, 4, 18))
    card = Catalog::Card.new(source_key:, release_date:, image_url: "https://images.example.test/#{source_key}.jpg",
      store_url: "https://store.example.test/#{source_key}", genres: [], tags: [])
    card.texts.build(locale: "en", title:)
    card.save!
    card
  end

  test "a five-thousand character title saves with a short slug" do
    card = card(title: "A malformed store title " * 210, source_key: "src:long")

    assert_operator card.slug.length, :<=, 120
  end

  test "two long titles sharing their first hundred characters get different slugs" do
    prefix = "An absurdly long store title " * 10
    first = card(title: "#{prefix} one", source_key: "src:long-1")
    second = card(title: "#{prefix} two", source_key: "src:long-2")

    assert_not_equal first.slug, second.slug
  end

  test "an ordinary title keeps the slug it had" do
    assert_equal "hades", card(title: "Hades", source_key: "src:hades").slug
  end

  test "the cut keeps whole words and never leaves a trailing dash" do
    card = card(title: "Spaceship " * 400, source_key: "src:words")

    assert_operator card.slug.length, :<=, 120
    assert_not card.slug.end_with?("-")
    assert_equal "spaceship", card.slug.split("-").last
  end
end
