# frozen_string_literal: true

module TeachingTaxonomy
  TEACHING_RECORD_COUNT = 3_000

  class << self
    def executions
      @executions ||= Hash.new(0)
    end

    def record_run(name)
      executions[name] += 1
    end
  end
end

RSpec::Sunspot::Profiles.define(:articles) do
  TeachingTaxonomy.record_run(:articles)
end

RSpec::Sunspot::Profiles.define(:comments) do
  TeachingTaxonomy.record_run(:comments)
end

RSpec::Sunspot::Profiles.define(:teaching_catalog) do
  TeachingTaxonomy.record_run(:teaching_catalog)
  Array.new(TeachingTaxonomy::TEACHING_RECORD_COUNT) { |index| "Guide #{index + 1}" }
end
