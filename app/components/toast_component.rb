# A toast of DESIGN.md and EXPERIENCE.md (Dialogs, toasts, inputs; Toast): a
# small panel with a steady light (accent for a notice, orange for an
# alert), an optional JetBrains Mono title, one JetBrains Mono line and a
# close button. Rendered by the shell's toast region, whose controller
# times, pauses and closes it; `data-turbo-temporary` keeps it out of Turbo's
# cache. Without JavaScript it simply stays.
class ToastComponent < ViewComponent::Base
  TONES = %i[notice alert].freeze

  # `once`: a key for a toast a page brings on every render while its state
  # lasts (the goal reward); a browser shows the toast of a key once
  # (toast_controller.ts).
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
