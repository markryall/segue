# frozen_string_literal: true

require "json"
require "socket"

module Segue
  # Client for mpv's JSON IPC protocol.
  #
  # mpv speaks newline delimited JSON over a unix socket. Requests carry a
  # request_id and replies echo it back, which is what lets us ignore the
  # asynchronous event messages mpv interleaves with responses.
  class Mpv
    class Error < RuntimeError
    end

    CONNECT_TIMEOUT = 5
    LOAD_TIMEOUT = 5
    POLL_INTERVAL = 0.05

    attr_reader :socket_path

    def initialize(socket_path)
      @socket_path = socket_path
      @request_id = 0
    end

    # mpv creates the socket a moment after it starts, so retry until it shows up.
    def connect(timeout: CONNECT_TIMEOUT)
      deadline = Time.now + timeout
      begin
        @socket = UNIXSocket.new(socket_path)
      rescue Errno::ENOENT, Errno::ECONNREFUSED
        raise Error, "timed out waiting for mpv socket at #{socket_path}" if Time.now > deadline

        sleep POLL_INTERVAL
        retry
      end
      self
    end

    def connected?
      !@socket.nil?
    end

    def command(*args)
      reply = request(args)
      raise Error, "#{args.first}: #{reply["error"]}" unless reply["error"] == "success"

      reply["data"]
    end

    # Returns nil when mpv considers a property unavailable - time-pos and
    # duration are both unavailable whenever nothing is loaded.
    def get(property)
      request(["get_property", property])["data"]
    end

    def set(property, value)
      command("set_property", property, value)
    end

    def load(path, start: nil)
      command("loadfile", path, "replace")
      wait_for_load
      command("seek", start, "absolute") if start&.positive?
    end

    def close
      return unless @socket

      begin
        request(["quit"])
      rescue Error, IOError, SystemCallError
        # mpv may have gone already - nothing left to ask politely
      end
      @socket.close unless @socket.closed?
      @socket = nil
    end

    private

    def wait_for_load(timeout: LOAD_TIMEOUT)
      deadline = Time.now + timeout
      sleep POLL_INTERVAL while get("time-pos").nil? && Time.now < deadline
    end

    def request(args)
      raise Error, "not connected to #{socket_path}" unless @socket

      @request_id += 1
      @socket.puts JSON.generate(command: args, request_id: @request_id)
      read_reply(@request_id)
    end

    def read_reply(id)
      loop do
        line = @socket.gets
        raise Error, "mpv closed the connection" if line.nil?

        message = parse(line)
        return message if message && message["request_id"] == id
      end
    end

    def parse(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end
  end
end
