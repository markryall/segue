# frozen_string_literal: true

module Segue
  # Tracks are queued from whatever tags ffmpeg could find, and plenty of files
  # have no artist or album - and sometimes no title either. Anything missing is
  # left out by the renderers rather than shown as an empty "by" or "from".
  module Track
    module_function

    def present?(value)
      !value.to_s.strip.empty?
    end

    def title(track)
      return track[:title] if present?(track[:title])

      File.basename(track[:path].to_s, ".*")
    end
  end
end
