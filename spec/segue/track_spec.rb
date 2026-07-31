# frozen_string_literal: true

RSpec.describe Segue::Track do
  describe ".present?" do
    it "treats nil, empty and whitespace-only tags as missing" do
      expect([nil, "", "   ", "\n"].map { |value| described_class.present?(value) }).to all(be false)
    end

    it "treats a real tag as present" do
      expect(described_class.present?("The Strokes")).to be true
    end
  end

  describe ".title" do
    it "uses the title tag when there is one" do
      expect(described_class.title(title: "Home", path: "/music/whatever.mp3")).to eq("Home")
    end

    it "falls back to the filename when the file has no title tag" do
      expect(described_class.title(title: nil, path: "/music/ZD_Sting_19.mp3")).to eq("ZD_Sting_19")
    end

    it "falls back when the title tag is blank rather than absent" do
      expect(described_class.title(title: "  ", path: "/music/untagged.flac")).to eq("untagged")
    end
  end
end

RSpec.describe "Segue.list_line" do
  def line(track)
    Segue.list_line(track, 0, nil).gsub(/\e\[[0-9;]*m/, "")
  end

  it "renders everything when all the tags are there" do
    expect(line(title: "Home", artist: "Chasing Luena", album: "Home", length: 241))
      .to eq("0 Home by Chasing Luena from Home (4 minutes and 1 seconds)")
  end

  it "leaves out the album when the file has none" do
    expect(line(title: "Sting", artist: "4ZZZ", album: nil, length: 6))
      .to eq("0 Sting by 4ZZZ (0 minutes and 6 seconds)")
  end

  it "leaves out the artist when the file has none" do
    expect(line(title: "Sting", artist: "", album: nil, length: 6))
      .to eq("0 Sting (0 minutes and 6 seconds)")
  end

  it "falls back to the filename when there is no title either" do
    expect(line(path: "/music/field-recording.wav", length: nil))
      .to eq("0 field-recording")
  end
end
