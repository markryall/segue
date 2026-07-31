# frozen_string_literal: true

require "yaml"
require_relative "paths"

module Segue
  class Preferences
    def initialize
      @path = Segue::Paths.preferences
      persist({ autoplay: true, crossfade: true }) unless File.exist?(@path)
    end

    def continue?
      self[:autoplay]
    end

    def crossfade?
      self[:autoplay] && self[:crossfade]
    end

    def scrobble?
      self[:scrobble]
    end

    def pause?
      reset(:pause)
    end

    def stop?
      reset(:stop)
    end

    def play?
      reset(:play)
    end

    def skip?
      reset(:skip)
    end

    def [](key)
      load_preferences[key]
    end

    def []=(key, value)
      preferences = load_preferences
      preferences[key] = value
      persist(preferences)
    end

    def persist(preferences)
      File.open(@path, "w") { |f| f.puts preferences.to_yaml }
    end

    private

    def load_preferences
      YAML.load_file(@path)
    end

    def reset(key)
      result = self[key]
      self[key] = false if result
      result
    end
  end
end
