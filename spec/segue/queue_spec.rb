# frozen_string_literal: true

RSpec.describe Segue::Queue, :sandboxed do
  def enqueue(title)
    described_class.enqueue(title: title, artist: "artist", album: "album", length: 10, path: __FILE__)
  end

  def titles
    described_class.to_enum(:each).map { |track| track[:title] }
  end

  it "keeps tracks in the order they were added" do
    %w[one two three].each { |title| enqueue(title) }

    expect(titles).to eq(%w[one two three])
  end

  it "keeps ordering stable when tracks are added within the same millisecond" do
    20.times { |index| enqueue("track-#{index}") }

    expect(titles).to eq(Array.new(20) { |index| "track-#{index}" })
  end

  it "reports the number of queued tracks" do
    2.times { |index| enqueue("track-#{index}") }

    expect(described_class.length).to eq(2)
  end

  it "removes the track at a position" do
    %w[one two three].each { |title| enqueue(title) }
    described_class.remove(1) { nil }

    expect(titles).to eq(%w[one three])
  end

  it "swaps two positions" do
    %w[one two three].each { |title| enqueue(title) }
    described_class.swap(0, 2) { nil }

    expect(titles).to eq(%w[three two one])
  end

  it "clears the queue" do
    enqueue("one")
    described_class.clear

    expect(described_class.length).to be_zero
  end

  it "counts only what is still to come, not the track it just handed out" do
    %w[one two three].each { |title| enqueue(title) }
    queue = described_class.new

    queue.next
    expect(described_class.length).to eq(2)
    queue.next
    expect(described_class.length).to eq(1)
    queue.next
    expect(described_class.length).to be_zero
  end

  it "hands out tracks one at a time and drops them as it goes" do
    %w[one two].each { |title| enqueue(title) }
    queue = described_class.new

    expect(queue.next[:title]).to eq("one")
    expect(queue.next[:title]).to eq("two")
    expect(queue.next).to be_nil
  end

  it "skips queued tracks whose file has gone away" do
    described_class.enqueue(title: "missing", artist: "a", album: "b", length: 1, path: "/nope/gone.mp3")
    enqueue("present")

    expect(described_class.new.next[:title]).to eq("present")
  end
end
