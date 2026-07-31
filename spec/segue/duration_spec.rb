# frozen_string_literal: true

RSpec.describe Segue::Duration do
  describe ".clock" do
    it "pads minutes and seconds to two digits" do
      expect(described_class.clock(132)).to eq("02:12")
    end

    it "shows zero as 00:00" do
      expect(described_class.clock(0)).to eq("00:00")
    end

    it "keeps seconds under a minute in the seconds column" do
      expect(described_class.clock(6)).to eq("00:06")
    end

    it "does not roll over to hours until an hour has passed" do
      expect(described_class.clock(3599)).to eq("59:59")
    end

    it "widens to h:mm:ss for an hour or more" do
      expect(described_class.clock(3600)).to eq("1:00:00")
    end

    it "handles a long mix" do
      expect(described_class.clock(7332)).to eq("2:02:12")
    end

    it "treats a missing duration as zero rather than raising" do
      expect(described_class.clock(nil)).to eq("00:00")
    end
  end
end
