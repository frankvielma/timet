# frozen_string_literal: true

require 'timet/utils'

RSpec.describe Timet::Utils do
  describe '.valid_date_format?' do
    it 'returns true for valid single dates' do
      expect(described_class.valid_date_format?('2023-10-27')).to be true
    end

    it 'returns true for valid date ranges' do
      expect(described_class.valid_date_format?('2023-10-01..2023-10-31')).to be true
    end

    it 'returns false for invalid single dates' do
      expect(described_class.valid_date_format?('2023/10/27')).to be false
      expect(described_class.valid_date_format?('invalid')).to be false
    end

    it 'returns false for invalid date ranges' do
      expect(described_class.valid_date_format?('2023-10-01...2023-10-31')).to be false
    end

    it 'returns false for dates with newlines (anchor check)' do
      expect(described_class.valid_date_format?("2023-10-27\n")).to be false
      expect(described_class.valid_date_format?("\n2023-10-27")).to be false
      expect(described_class.valid_date_format?("2023-10-01..2023-10-31\n")).to be false
    end
  end
end
