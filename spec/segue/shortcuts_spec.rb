# frozen_string_literal: true

RSpec.describe "Segue.shortcuts" do
  it "lists a label for every key the player loop dispatches, plus quit" do
    expect(Segue.shortcuts).to eq(
      [%w[space pause], %w[n skip], %w[p play], %w[s stop], %w[q quit]]
    )
  end

  it "covers every entry in KEYS so the help line cannot drift" do
    described = Segue.shortcuts.map(&:last)

    expect(Segue::KEYS.values.map(&:to_s) - described).to be_empty
  end

  it "spells the space bar out rather than showing a blank" do
    expect(Segue.shortcuts.map(&:first)).to all(satisfy { |key| !key.strip.empty? })
  end
end
