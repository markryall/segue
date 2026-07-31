# frozen_string_literal: true

require "curses"
require "rainbow"
require_relative "segue/version"
require_relative "segue/paths"
require_relative "segue/player"
require_relative "segue/player_controller"
require_relative "segue/preferences"
require_relative "segue/queue"
require_relative "segue/notifiers"
require_relative "segue/scrobbler"

module Segue
  COLOURS = [0, 2, 5, 6, 8, 9, 11].freeze
  KEYS = { " " => :pause, "n" => :skip, "p" => :play, "s" => :stop }.freeze

  def self.autoplay(value)
    Segue::Preferences.new[:autoplay] = value == "on"
  end

  def self.clear
    Segue::Queue.clear
  end

  def self.crossfade(value)
    Segue::Preferences.new[:crossfade] = value == "on"
  end

  def self.history
    path = Segue::Paths.history
    return unless File.exist?(path)

    puts File.read(path)
  end

  def self.list
    started = Segue::Preferences.new[:started]
    offset = 0
    Segue::Queue.to_enum(:each).each_with_index do |track, index|
      puts list_line(track, index, started && Time.at(started + offset))
      offset += track[:length].to_i
    end
  end

  def self.list_line(track, index, start_time)
    parts = [Rainbow(index.to_s).magenta]
    parts << start_time.strftime("%I:%M:%S") if start_time
    parts += [Rainbow(track[:title]).green, "by", Rainbow(track[:artist]).yellow]
    parts += ["from", Rainbow(track[:album]).cyan] unless (track[:album] || "").empty?
    parts << "(#{track[:length] / 60} minutes and #{track[:length] % 60} seconds)" if track[:length]
    parts.join(" ")
  end

  def self.pause
    Segue::Preferences.new[:pause] = true
  end

  def self.play
    Segue::Preferences.new[:play] = true
  end

  def self.player
    # Start the controller before taking over the screen so that a failure to
    # launch mpv is readable rather than swallowed by curses
    player_controller = Segue::PlayerController.new
    window = open_window

    loop do
      render(window, player_controller.next)

      key = window.getch.to_s
      break if key == "q"

      send(KEYS[key]) if KEYS.key?(key)
      sleep 0.2
    end
  ensure
    player_controller&.cleanup
    Curses.close_screen
  end

  def self.open_window
    Curses.init_screen
    Curses.start_color
    Curses.curs_set(0)
    Curses.noecho
    COLOURS.each { |colour| Curses.init_pair(colour, colour, 0) }
    Curses::Window.new(0, 0, 1, 2).tap { |window| window.nodelay = true }
  end

  def self.render(window, lines)
    window.setpos(0, 0)
    lines.each do |colour, text|
      window.attron(Curses.color_pair(colour)) { window << text }
      Curses.clrtoeol
    end
    (window.maxy - window.cury).times { window.deleteln }
    window.refresh
  end

  def self.remove(index)
    Segue::Queue.remove(index) { list }
  end

  def self.queue(paths)
    paths.each do |path|
      if File.file?(path)
        Segue::Queue.add(path)
      else
        Dir.glob("#{path}/**/*.*").each { |child_path| Segue::Queue.add(child_path) }
      end
    end
  end

  def self.scrobble(value)
    preferences = Segue::Preferences.new
    preferences[:scrobble] = value == "on"
    scrobbler = Segue::Scrobbler.load if preferences.scrobble?
    preferences[:scrobble] = false unless scrobbler
  end

  def self.skip
    Segue::Preferences.new[:skip] = true
  end

  def self.stop
    Segue::Preferences.new[:stop] = true
  end

  def self.swap(args)
    a, b = *args
    Segue::Queue.swap(a, b) { list }
  end
end
