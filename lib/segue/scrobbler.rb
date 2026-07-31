# frozen_string_literal: true

require "net/http"
require "digest/md5"
require "uri"
require "cgi"
require "rexml/document"
require_relative "settings"

module Segue
  class Scrobbler
    SCROBBLER_URL = "http://ws.audioscrobbler.com/2.0/"

    class SubmissionError < RuntimeError
    end

    class SessionError < RuntimeError
    end

    def self.ask(prompt)
      puts prompt
      gets.chomp.strip
    end

    REQUIRED = %i[api_key secret user].freeze

    def self.blank?(attribute)
      (attribute || "").empty?
    end

    def self.load
      conf = Segue::Settings.new("~/.lastfm.yml")
      prompt_for_credentials(conf)
      return nil if REQUIRED.any? { |key| blank?(conf[key]) }

      scrobbler = new(conf[:api_key], conf[:secret], conf[:user], conf[:session])
      conf[:session] ||= authorise(scrobbler)
      return nil if blank?(conf[:session])

      scrobbler
    end

    def self.prompt_for_credentials(conf)
      conf[:api_key] = ask("What is the api key? ") if blank?(conf[:api_key])
      conf[:secret] = ask("What is the secret? ") if blank?(conf[:secret])
      conf[:user] = ask("What is your lastfm username? ") if blank?(conf[:user])
    end

    def self.authorise(scrobbler)
      scrobbler.fetch_session_key do |url|
        puts "A browser will now launch to allow to authorise this application to access your lastfm account"
        `open '#{url}'`
        puts "Press enter when you have authorised the application"
        gets
      end
    end

    def initialize(api_key, secret, user, session_key = nil)
      @api_key     = api_key
      @secret      = secret
      @user        = user
      @session_key = session_key
    end

    attr_reader :user, :api_key, :secret

    def session_key
      @session_key or raise SessionError, "The session key must be set or fetched"
    end

    def fetch_session_key
      doc = lfm :get, "auth.gettoken"
      request_token = doc.root.elements["token"].text
      yield "http://www.last.fm/api/auth/?api_key=#{api_key}&token=#{request_token}"
      doc = lfm :get, "auth.getsession", token: request_token
      status = doc.root.attributes["status"]
      raise SubmissionError, status unless status == "ok"

      @session_key = doc.root.elements["session"].elements["key"].text
    end

    def with_profile_url
      yield "http://www.last.fm/user/#{user}" if user
    end

    # http://www.last.fm/api/show?service=443
    def scrobble(artist, title, params = {})
      lfm_track "track.scrobble", artist, title, params
    end

    # See http://www.last.fm/api/show?service=454 for more details
    def now_playing(artist, title, params = {})
      lfm_track "track.updateNowPlaying", artist, title, params
    end

    # http://www.last.fm/api/show?service=260
    def love(artist, title, params = {})
      lfm_track "track.love", artist, title, params
    end

    private

    def lfm_track(method, artist, title, params)
      doc = lfm :post, method, params.merge(sk: session_key, artist: artist, track: title)
      status = doc.root.attributes["status"]
      raise SubmissionError, status unless status == "ok"
    end

    def lfm(get_or_post, method, parameters = {})
      p = signed_parameters parameters.merge api_key: api_key, method: method
      xml = send get_or_post, SCROBBLER_URL, p
      REXML::Document.new xml
    end

    def get(url, parameters)
      query_string = sort_parameters(parameters)
                     .map { |k, v| "#{k}=#{CGI.escape(v)}" }
                     .join("&")
      Net::HTTP.get_response(URI.parse("#{url}?#{query_string}")).body
    end

    def post(url, parameters)
      Net::HTTP.post_form(URI.parse(url), parameters).body
    end

    def signed_parameters(parameters)
      sorted    = sort_parameters parameters
      signature = Digest::MD5.hexdigest(sorted.join + secret)
      parameters.merge api_sig: signature
    end

    def sort_parameters(parameters)
      parameters.map { |k, v| [k.to_s, v.to_s] }.sort
    end
  end
end
