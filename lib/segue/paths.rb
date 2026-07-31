# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module Segue
  # Everything segue writes to disk lives under a single directory so that it
  # can run alongside other players without fighting over state.
  module Paths
    module_function

    def home
      File.expand_path(ENV.fetch("SEGUE_HOME", "~/.segue")).tap do |path|
        FileUtils.mkdir_p path
      end
    end

    def preferences
      File.join(home, "preferences.yml")
    end

    def history
      File.join(home, "history")
    end

    def queue
      File.join(home, "queue").tap { |path| FileUtils.mkdir_p path }
    end

    # Sockets are scoped to the running player so a crashed one can't leave a
    # stale path behind that the next player would try to talk to.
    def socket(name)
      File.join(Dir.tmpdir, "segue-#{name}-#{Process.pid}.sock")
    end
  end
end
