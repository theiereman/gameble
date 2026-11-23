class AltSignalSentenceComponent < ViewComponent::Base
  def initialize(signal:, facts:, tie: false)
    @signal = signal
    @facts = facts
    @sentences = tie ? "tie_sentences" : "sentences"
  end

  def call
    html_escape t("back_office.market_signals.#{@sentences}.#{@signal}", **@facts.symbolize_keys.to_h { |key, value| [ key, fact(key, value) ] })
  end

  private
    def fact(key, value)
      case key
      when :season then value.to_s
      when :deposited_on then day(Date.iso8601(value))
      else value.is_a?(Integer) ? helpers.number_with_delimiter(value) : value
      end
    end

    def day(date) = I18n.l(date, format: date.day == 1 ? :long_day_first : :long_day)
end
