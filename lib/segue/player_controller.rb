# frozen_string_literal: true

require_relative "player"
require_relative "track"
require_relative "preferences"
require_relative "queue"
require_relative "notifiers"

module Segue
  class PlayerController
    CROSSFADE_TRIGGER_SECONDS = 5

    def initialize
      @player = Segue::Player.new
      @preferences = Segue::Preferences.new
      @queue = Segue::Queue.new
      @notifiers = Segue::Notifiers.new
      @track = nil
      @suspended = false
    end

    # An ordered chain of guard clauses - the priority between them is the
    # point, so leave it flat rather than nesting it to please the metrics
    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def next
      return when_fading if @player.fading?
      return on_play if @preferences.play? && @suspended
      return on_pause if @preferences.pause? && !@suspended
      return on_stop if @preferences.stop? && !@suspended
      return build if @suspended
      return when_playing if @track && @player.playing?
      return when_auto if @preferences.continue?

      when_manual
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def cleanup
      @notifiers.track_suspended
      @player.fadeout
      @player.cleanup
    end

    private

    def on_pause
      suspend("Now Paused", :pause)
    end

    def on_stop
      suspend("Now Stopped", :stop)
    end

    # The pause or stop happens on the fade thread once the ramp finishes, so
    # the order is preserved without this call waiting for it.
    def suspend(status, method)
      @status = status
      @suspended = true
      @notifiers.track_suspended
      @player.fadeout { @player.send(method) }
      build
    end

    def on_play
      @suspended = false
      @player.fadein
      @notifiers.track_resumed(@track, @player.time)
      when_playing_track(@player.remaining)
    end

    def when_playing
      return on_skip if @preferences.skip?
      return on_crossfade if @preferences.crossfade? && @player.remaining < CROSSFADE_TRIGGER_SECONDS

      when_playing_track(@player.remaining)
    end

    def on_skip
      @notifiers.track_suspended
      advance
    end

    def on_crossfade
      @notifiers.track_finished(@track)
      advance
    end

    def advance
      @track = @queue.next
      unless @track
        @player.fadeout
        return when_empty
      end

      @notifiers.track_started(@track)
      @player.crossfade(@track[:path])
      when_playing_track(@player.remaining)
    end

    def when_auto
      @notifiers.track_finished(@track)
      @track = @queue.next
      return when_empty unless @track

      @notifiers.track_started(@track)
      @player.play(@track[:path])
      when_playing_track(@track[:length])
    end

    # A ramp is running on another thread - keep redrawing, but issue nothing
    # new. A keypress during a fade stays set in preferences and is picked up
    # on the next tick rather than being dropped.
    def when_fading
      return build unless @track

      build(*track_lines(@player.remaining))
    end

    def when_playing_track(remaining)
      @status = "Now Playing"
      build(*track_lines(remaining))
    end

    # Artist and album are left out entirely when the file had no such tag,
    # rather than rendering a dangling "by" or "from".
    def track_lines(remaining)
      remaining = remaining.to_i
      lines = [[2, Segue::Track.title(@track)], [0, "\n"]]
      lines += [[0, "by "], [11, @track[:artist]], [0, "\n"]] if Segue::Track.present?(@track[:artist])
      lines += [[0, "from "], [6, @track[:album]], [0, "\n"]] if Segue::Track.present?(@track[:album])
      lines + [
        [remaining < 30 ? 9 : 5, duration(remaining)],
        [0, " of "],
        [0, duration(@track[:length])],
        [0, " remaining\n"]
      ]
    end

    def when_empty
      @status = "Now Waiting"
      build
    end

    def when_manual
      @status = "Now Waiting"
      build
    end

    def display_time(time)
      time.strftime("%I:%M:%S")
    end

    def duration(seconds)
      seconds = seconds.to_i
      seconds > 60 ? "#{seconds / 60}m and #{seconds % 60}s" : "#{seconds}s"
    end

    def build(*extra)
      autoplay = @preferences[:autoplay] ? "+" : "-"
      crossfade = @preferences[:crossfade] ? "+" : "-"
      scrobble = @preferences[:scrobble] ? "+" : "-"
      [
        [0, display_time(Time.now)],
        [0, "\n"],
        [0, @status],
        [0, "\n"],
        [0, "#{Segue::Queue.length} queued tracks"],
        [0, "\n"],
        [8, "#{autoplay}autoplay #{crossfade}crossfade #{scrobble}scrobble"],
        [0, "\n"]
      ] + extra
    end
  end
end
