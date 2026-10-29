module Accounts
  module HandleGenerator
    WORDS = %w[
      Brother Sister Captain Pilgrim Wanderer Gambler Keeper Dealer Rookie Veteran Ranger Wizard
      Knight Pixel Comet Rocket Falcon Otter Badger Lynx Panda Raven Tiger Walrus
    ].freeze
    SUFFIX_ALPHABET = ("A".."Z").to_a.excluding("I", "O") + ("2".."9").to_a
    SUFFIX_LENGTH = 6

    def self.call
      loop do
        handle = "#{WORDS.sample(random: SecureRandom)}-#{suffix}"
        return handle unless Player.exists?(persona_name: handle)
      end
    end

    def self.suffix
      Array.new(SUFFIX_LENGTH) { SUFFIX_ALPHABET.sample(random: SecureRandom) }.join
    end
    private_class_method :suffix
  end
end
