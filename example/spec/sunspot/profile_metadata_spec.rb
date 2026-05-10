# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sunspot profile metadata" do
  it "applies a single profile from metadata", sunspot_profile: :articles do
    expect(sunspot_profile_names).to eq(["articles"])
    expect(sunspot_profile_data).to eq({})
    expect(sunspot_profile_results.fetch("articles")).to include("type" => "executable")
    expect(TeachingTaxonomy.executions[:articles]).to be >= 1
  end

  it "merges multiple profiles for a single example", sunspot_profiles: %i[articles comments] do
    expect(sunspot_profile_names).to eq(%w[articles comments])
    expect(sunspot_profile_data).to eq({})
    expect(sunspot_profile_results.fetch("articles")).to include("type" => "executable")
    expect(sunspot_profile_results.fetch("comments")).to include("type" => "executable")
    expect(TeachingTaxonomy.executions[:articles]).to be >= 1
    expect(TeachingTaxonomy.executions[:comments]).to be >= 1
  end
end
