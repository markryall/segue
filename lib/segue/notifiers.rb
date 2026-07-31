# frozen_string_literal: true

require "rainbow"
require "shellwords"
require_relative "paths"
require_relative "preferences"
require_relative "scrobbler"

module Segue
  class Notifiers
    def initialize
      @preferences = Segue::Preferences.new
      @history = Segue::Paths.history
    end

    def track_suspended
      @preferences[:started] = nil
    end

    def track_resumed(track, elapsed)
      return unless track

      track[:start_time] = Time.now - elapsed
      @preferences[:started] = track[:start_time].to_i
    end

    def track_started(track)
      return unless track

      track[:start_time] = Time.now
      @preferences[:started] = track[:start_time].to_i
      scrobbler&.now_playing(track[:artist], track[:title])
      terminal_notify(
        message: "#{track[:title]} by #{track[:artist]}",
        title: "Now Playing"
      )

      File.open(@history, "a") { |file| file.puts history_line(track) }
    end

    def track_finished(track)
      @preferences[:started] = nil

      return unless track

      scrobbler&.scrobble(track[:artist], track[:title], timestamp: track[:start_time].to_i)
    end

    private

    def history_line(track)
      [
        display_time(track[:start_time]),
        Rainbow(track[:title]).green,
        "by",
        Rainbow(track[:artist]).yellow,
        "from",
        Rainbow(track[:album]).cyan,
        "(#{duration(track[:length])})"
      ].join(" ")
    end

    def duration(seconds)
      seconds = seconds.to_i
      seconds > 60 ? "#{seconds / 60}m and #{seconds % 60}s" : "#{seconds}s"
    end

    def display_time(time)
      time.strftime("%I:%M:%S")
    end

    def terminal_notify(message:, title:)
      return if `which terminal-notifier`.empty?

      `terminal-notifier -group segue -message #{Shellwords.escape(message)} -title #{Shellwords.escape(title)}`
    end

    def scrobbler
      Segue::Scrobbler.load if @preferences.scrobble?
    end
  end
end
