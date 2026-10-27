class ToastComponent < ViewComponent::Base
  TONES = %i[notice alert].freeze

  def initialize(message:, title: nil, tone: :notice, once: nil, after_reveal: false, action: nil)
    raise ArgumentError, "unknown toast tone: #{tone.inspect}" unless TONES.include?(tone)

    @message = message
    @title = title
    @tone = tone
    @once = once
    @after_reveal = after_reveal
    @action = action
  end
end
