class AltSignalSentenceComponent < ViewComponent::Base
  def initialize(signal:, facts:)
    @signal = signal
    @facts = facts
  end

  def call
    t("back_office.market_signals.sentences.#{@signal}", **@facts.symbolize_keys.transform_values { helpers.number_with_delimiter(it) })
  end
end
