# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sunspot profile metadata" do
  it "applies a single profile from metadata", sunspot_profile: :articles do
    expect(sunspot_profile_names).to eq(["articles"])
    expect(sunspot_profile_data.fetch("records")).to include(
      include("title" => "First article", "category" => "guides")
    )
    expect(sunspot_profile_data.fetch("search")).to include(
      "fulltext" => "Sunspot",
      "with" => { "category" => "guides" }
    )
    expect(sunspot_profile_results.fetch("articles")).to include("type" => "static")
  end

  it "merges multiple profiles for a single example", sunspot_profiles: %i[articles comments] do
    expect(sunspot_profile_names).to eq(%w[articles comments])
    expect(sunspot_profile_data.fetch("records").size).to eq(2)
    expect(sunspot_profile_data.fetch("search")).to include(
      "fulltext" => "Sunspot",
      "with" => { "category" => "guides", "article_id" => 1 }
    )
  end
end
