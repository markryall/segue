# frozen_string_literal: true

require "shellwords"

module Segue
  # Pulls tags out of a file by parsing what ffmpeg prints about it.
  class Ffmpeg
    attr_reader(
      :title,
      :album,
      :artist,
      :albumartist,
      :time,
      :date,
      :track,
      :puid,
      :mbartistid,
      :mbalbumid,
      :mbalbumartistid,
      :asin
    )

    def initialize(path)
      @path = path
      parse

      @title = tag :title, :tit2
      @album = tag :album, :talb
      @artist = tag :artist, :tpe1, :tpe2
      @albumartist = tag :album_artist, :tso2
      @time = to_duration tag :duration
      @date = tag :date, :tdrc, :tyer
      @track = tag :track, :trck
      @puid = tag :"musicip puid"
      @mbartistid = tag :musicbrainz_artistid, :"musicbrainz artist id"
      @mbalbumid = tag :musicbrainz_albumid, :"musicbrainz album id"
      @mbalbumartistid = tag :musicbrainz_albumartistid, :"musicbrainz album artist id"
      @asin = tag :asin
    end

    def tag(*names)
      names.each { |name| return @meta[name] if @meta[name] }
      nil
    end

    private

    def parse
      @meta = {}
      collecting = false
      `ffmpeg -i #{Shellwords.escape(@path)} 2>&1`.each_line do |line|
        if line.chomp == "  Metadata:"
          collecting = true
          next
        end
        next unless collecting

        match = / *: */.match line.chomp
        add_meta match.pre_match.strip.downcase.to_sym, match.post_match.strip if match
      end
    end

    def add_meta(key, value)
      @meta[key] ||= value
    end

    def to_duration(string)
      return nil unless string

      first, = string.split ","
      hours, minutes, seconds = first.split ":"
      seconds.to_i + (minutes.to_i * 60) + (hours.to_i * 60 * 60)
    end
  end
end
