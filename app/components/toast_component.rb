# A toast of DESIGN.md and EXPERIENCE.md (Dialogs, toasts, inputs; Toast): a
# small panel with a steady light (accent for a notice, orange for an
# alert), an optional Silkscreen title, one VT323 line and a close button.
# Rendered by the shell's toast region, whose controller times, pauses and
# closes it; `data-turbo-temporary` keeps it out of Turbo's cache. Without
# JavaScript it simply stays.
class ToastComponent < ViewComponent::Base
  TONES = %i[notice alert].freeze

  def initialize(message:, title: nil, tone: :notice)
    raise ArgumentError, "unknown toast tone: #{tone.inspect}" unless TONES.include?(tone)

    @message = message
    @title = title
    @tone = tone
  end
end
