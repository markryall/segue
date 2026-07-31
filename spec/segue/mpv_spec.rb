# frozen_string_literal: true

require "json"
require "socket"
require "tmpdir"

# Stands in for mpv: accepts one client and answers each request with whatever
# the handler returns (an array of messages, so a test can interleave events).
class FakeMpv
  attr_reader :socket_path, :requests

  def initialize(socket_path, &handler)
    @socket_path = socket_path
    @handler = handler
    @requests = []
    @server = UNIXServer.new(socket_path)
    @thread = Thread.new { serve }
  end

  def stop
    @thread&.kill
    @server.close unless @server.closed?
  end

  private

  def serve
    client = @server.accept
    while (line = client.gets)
      request = JSON.parse(line)
      @requests << request
      # Array() would turn a single hash into pairs, so wrap it by hand
      reply = @handler.call(request)
      reply = [reply] unless reply.is_a?(Array)
      reply.each { |message| client.puts JSON.generate(message) }
    end
  rescue IOError, Errno::EBADF, Errno::EPIPE
    nil
  end
end

RSpec.describe Segue::Mpv do
  around do |example|
    Dir.mktmpdir("segue-mpv") do |dir|
      @socket_path = File.join(dir, "mpv.sock")
      example.run
      @fake&.stop
    end
  end

  def serving(&handler)
    @fake = FakeMpv.new(@socket_path, &handler)
    described_class.new(@socket_path).connect
  end

  def ok(request, data)
    { "request_id" => request["request_id"], "error" => "success", "data" => data }
  end

  it "returns the data from a successful command" do
    mpv = serving { |request| ok(request, 42) }

    expect(mpv.command("get_property", "volume")).to eq(42)
  end

  it "sends the command and arguments mpv expects" do
    mpv = serving { |request| ok(request, nil) }
    mpv.set("volume", 30)

    expect(@fake.requests.last["command"]).to eq(["set_property", "volume", 30])
  end

  it "gives each request a distinct id" do
    mpv = serving { |request| ok(request, nil) }
    3.times { mpv.get("volume") }

    expect(@fake.requests.map { |r| r["request_id"] }).to eq([1, 2, 3])
  end

  it "skips over asynchronous events to find the reply" do
    mpv = serving do |request|
      [
        { "event" => "playback-restart" },
        { "event" => "file-loaded" },
        ok(request, 7)
      ]
    end

    expect(mpv.get("time-pos")).to eq(7)
  end

  it "returns nil rather than raising when a property is unavailable" do
    mpv = serving do |request|
      { "request_id" => request["request_id"], "error" => "property unavailable", "data" => nil }
    end

    expect(mpv.get("time-pos")).to be_nil
  end

  it "raises when a command fails" do
    mpv = serving do |request|
      { "request_id" => request["request_id"], "error" => "invalid parameter" }
    end

    expect { mpv.command("seek", "nonsense") }.to raise_error(described_class::Error, /seek: invalid parameter/)
  end

  it "raises when nothing is listening on the socket" do
    mpv = described_class.new(File.join(Dir.tmpdir, "segue-missing.sock"))

    expect { mpv.connect(timeout: 0.1) }.to raise_error(described_class::Error, /timed out/)
  end

  it "raises when used before connecting" do
    expect { described_class.new(@socket_path).get("volume") }
      .to raise_error(described_class::Error, /not connected/)
  end
end
