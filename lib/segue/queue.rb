# frozen_string_literal: true

require "yaml"
require "fileutils"
require_relative "ffmpeg"
require_relative "paths"

module Segue
  # The queue is a directory of yaml files named after the time they were
  # added, so ordering is just sorting by filename.
  class Queue
    EXTENSIONS = %w[.mp3 .m4a .flac .ogg .opus .wav .aac .wma].freeze

    # Handing a track out drops it from the queue immediately, so the count is
    # what is still to come rather than including whatever is already playing.
    def next
      path = Segue::Queue.entries.first
      return unless path

      track = YAML.load_file(path)
      FileUtils.rm_f path
      File.exist?(track[:path]) ? track : self.next
    end

    class << self
      # Dir[] sorts its results, and the filenames are timestamps, so this is
      # the queue in the order tracks were added
      def entries
        Dir[File.join(Segue::Paths.queue, "*.yml")]
      end

      def clear
        FileUtils.rm_rf Segue::Paths.queue
      end

      def length
        entries.length
      end

      def each
        entries.each { |path| yield YAML.load_file(path) }
      end

      def remove(index)
        path = entries[index.to_i]
        if path
          FileUtils.rm_f path
          yield
        else
          puts "Could not find track at position #{index}"
        end
      end

      def swap(index_a, index_b)
        all = entries
        path_a = all[index_a.to_i]
        path_b = all[index_b.to_i]

        if path_a && path_b
          FileUtils.mv path_a, "#{path_a}.tmp"
          FileUtils.mv path_b, path_a
          FileUtils.mv "#{path_a}.tmp", path_b
          yield
        else
          puts "Could not find tracks at positions #{index_a} and #{index_b}"
        end
      end

      def add(path)
        unless EXTENSIONS.include?(File.extname(path).downcase)
          puts "skipping #{path}"
          return
        end

        puts "adding #{path}"
        tags = Segue::Ffmpeg.new(path)
        enqueue(
          title: tags.title,
          artist: tags.artist,
          album: tags.album,
          length: tags.time,
          path: File.expand_path(path)
        )
      end

      def enqueue(track)
        File.open(File.join(Segue::Paths.queue, next_name), "w") do |file|
          file.puts track.to_yaml
        end
      end

      private

      # Millisecond timestamps collide when tracks are queued in quick
      # succession, so add a zero padded sequence that keeps sorting stable.
      def next_name
        millis = (Time.now.to_f * 1000).to_i
        sequence = 0
        sequence += 1 while File.exist?(File.join(Segue::Paths.queue, name_for(millis, sequence)))
        name_for(millis, sequence)
      end

      def name_for(millis, sequence)
        format("%<millis>d-%<sequence>03d.yml", millis: millis, sequence: sequence)
      end
    end
  end
end
