# Sells every Archive card at its rarity's reference, so a test reads the back-office price it set; the coefficient has its own tests.
module ArchiveAtReference
  def self.included(base)
    base.setup { ArchiveAtReference.coefficient(1) }
    base.teardown { ArchiveAtReference.coefficient(ArchiveAtReference::STARTING) }
  end

  STARTING = Game::Market::ArchivePrices::STARTING_COEFFICIENT

  def self.coefficient(value)
    Rails.cache.clear
    silence_warnings { Game::Market::ArchivePrices.const_set(:STARTING_COEFFICIENT, value) }
  end
end
