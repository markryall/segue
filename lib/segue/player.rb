# frozen_string_literal: true

require "fileutils"
require_relative "mpv"
require_relative "paths"

module Segue
  # Drives a pair of mpv instances so one can fade up while the other fades
  # down - mpv has no crossfade of its own.
  class Player
    MAX_VOLUME = 100
    FADE_STEPS = 10
    FADE_STEP_SECONDS = 0.5
    QUIT_TIMEOUT = 2

    def initialize(executable: ENV.fetch("SEGUE_MPV", "mpv"))
      @executable = executable
      @processes = []
      @current = spawn_mpv("a")
      @other = spawn_mpv("b")
      @stopped = nil
    end

    def playing?
      loaded? && @current.get("pause") == false
    end

    def time
      (@current.get("time-pos") || 0).round
    end

    def remaining
      duration = @current.get("duration")
      return 0 unless duration

      [(duration - (@current.get("time-pos") || 0)).round, 0].max
    end

    # True while a ramp is still running on its own thread. The caller is
    # expected to leave the player alone until it finishes.
    def fading?
      @fade&.alive? || false
    end

    def await_fade
      @fade&.join
      @fade = nil
    end

    # Ramps down and then runs the block, if given, on the fade thread - that
    # keeps "fade out and then pause" in order without the caller waiting.
    def fadeout(&)
      start_fade([@current, MAX_VOLUME, 0], &)
    end

    def fadein
      @current.set("volume", 0)
      play
      start_fade([@current, 0, MAX_VOLUME])
    end

    # Loading is done up front and the instances swapped straight away, so the
    # incoming track is what time/remaining/playing? report while it fades up.
    def crossfade(path)
      outgoing = @current
      incoming = @other
      incoming.set("volume", 0)
      incoming.load(path)
      @current = incoming
      @other = outgoing
      @stopped = nil

      start_fade([outgoing, MAX_VOLUME, 0], [incoming, 0, MAX_VOLUME]) { outgoing.command("stop") }
    end

    def play(path = nil)
      if path
        @current.set("volume", MAX_VOLUME)
        @current.load(path)
      elsif @stopped
        @current.load(@stopped[:path], start: @stopped[:time])
      else
        @current.set("pause", false)
      end
      @stopped = nil
    end

    def pause
      @current.set("pause", true)
    end

    # mpv unloads the file on stop, so remember where we were to let play resume.
    def stop
      @stopped = { path: @current.get("path"), time: @current.get("time-pos") }
      @current.command("stop")
    end

    def cleanup
      await_fade
      [@current, @other].compact.each(&:close)
      @current = @other = nil
      @processes.each do |pid, socket_path|
        terminate pid
        FileUtils.rm_f socket_path
      end
      @processes = []
    end

    private

    def loaded?
      @current.get("idle-active") == false
    end

    def spawn_mpv(name)
      socket_path = Segue::Paths.socket(name)
      FileUtils.rm_f socket_path
      pid = Process.spawn(
        @executable,
        "--idle=yes",
        "--no-video",
        "--no-terminal",
        "--volume=#{MAX_VOLUME}",
        "--input-ipc-server=#{socket_path}",
        %i[out err] => File::NULL
      )
      @processes << [pid, socket_path]
      Mpv.new(socket_path).connect
    end

    # Each ramp is [mpv, from, to] and they all step together, which is what
    # makes a crossfade a crossfade rather than two sequential fades. Runs off
    # the main thread so the display keeps redrawing and keys keep responding
    # for the five and a half seconds this takes.
    def start_fade(*ramps, &after)
      await_fade
      @fade = Thread.new do
        (0..FADE_STEPS).each do |step|
          ramps.each { |mpv, from, to| mpv.set("volume", level(from, to, step)) }
          sleep FADE_STEP_SECONDS
        end
        after&.call
      end
    end

    def level(from, to, step)
      from + (((to - from) * step) / FADE_STEPS)
    end

    def terminate(pid)
      deadline = Time.now + QUIT_TIMEOUT
      while Time.now < deadline
        return if Process.waitpid(pid, Process::WNOHANG)

        sleep Mpv::POLL_INTERVAL
      end
      Process.kill "TERM", pid
      Process.waitpid pid
    rescue Errno::ECHILD, Errno::ESRCH
      nil
    end
  end
end
