# frozen_string_literal: true

require 'timet/time_helper'

RSpec.describe Timet::TimeHelper do
  def create_time(*args)
    year, month, day, hour, min, sec = args
    Time.new(year, month, day, hour, min, sec)
  end

  describe '.timestamp_to_time' do
    it 'returns nil if timestamp is nil' do
      expect(described_class.timestamp_to_time(nil)).to be_nil
    end

    it 'converts a timestamp to a formatted time string' do
      timestamp = Time.new(2023, 3, 15, 0, 0, 0).to_i
      expect(described_class.timestamp_to_time(timestamp)).to eq(Time.new(2023, 3, 15, 0, 0, 0).strftime('%H:%M:%S'))
    end

    it 'handles different timestamps correctly' do
      test_cases = [
        { time: create_time(2023, 3, 15, 0, 0, 0), expected: '00:00:00' },
        { time: create_time(2023, 3, 15, 3, 46, 40), expected: '03:46:40' }
      ]

      test_cases.each do |test_case|
        timestamp = test_case[:time].to_i
        expect(described_class.timestamp_to_time(timestamp)).to eq(test_case[:expected])
      end
    end
  end

  describe '.format_time' do
    it 'returns nil if timestamp is nil' do
      expect(described_class.format_time(nil)).to be_nil
    end

    it 'converts a timestamp to a formatted time string' do
      timestamp = Time.new(2024, 3, 15, 0, 0, 0).to_i # Example timestamp
      expect(described_class.format_time(timestamp)).to eq(Time.new(2024, 3, 15, 0, 0,
                                                                    0).strftime('%Y-%m-%d %H:%M:%S'))
    end

    it 'handles different timestamps correctly' do
      test_cases = [
        { time: create_time(2024, 3, 15, 0, 0, 0), expected: '2024-03-15 00:00:00' },
        { time: create_time(2024, 3, 15, 3, 46, 40), expected: '2024-03-15 03:46:40' }
      ]

      test_cases.each do |test_case|
        timestamp = test_case[:time].to_i
        expect(described_class.format_time(timestamp)).to eq(test_case[:expected])
      end
    end
  end

  describe '.parse_time_components' do
    it 'parses a 6-digit string correctly' do
      expect(described_class.parse_time_components('123456')).to eq([12, 34, 56])
    end

    it 'parses a 4-digit string correctly' do
      expect(described_class.parse_time_components('1234')).to eq([12, 34, 0])
    end

    it 'parses a 3-digit string correctly' do
      expect(described_class.parse_time_components('123')).to eq([12, 30, 0])
    end

    it 'parses a 2-digit string correctly' do
      expect(described_class.parse_time_components('12')).to eq([12, 0, 0])
    end

    it 'parses a 1-digit string correctly' do
      expect(described_class.parse_time_components('1')).to eq([1, 0, 0])
    end

    it 'handles empty string' do
      expect(described_class.parse_time_components('')).to eq([0, 0, 0])
    end

    it 'handles non-numeric characters' do
      expect(described_class.parse_time_components('abc')).to eq([0, 0, 0])
    end
  end
end
