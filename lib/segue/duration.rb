# frozen_string_literal: true

module Segue
  # The player panel shows times as a clock - mm:ss, widening to h:mm:ss for
  # anything an hour or longer.
  module Duration
    module_function

    def clock(seconds)
      seconds = seconds.to_i
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      return format("%<h>d:%<m>02d:%<s>02d", h: hours, m: minutes, s: seconds % 60) if hours.positive?

      format("%<m>02d:%<s>02d", m: minutes, s: seconds % 60)
    end
  end
end
