require 'timet/time_helper'

RSpec.describe Timet::TimeHelper do
  describe '.timestamp_to_time' do
    it 'returns nil if timestamp is nil' do
      expect(Timet::TimeHelper.timestamp_to_time(nil)).to be_nil
    end

    it 'converts a timestamp to a formatted time string' do
      timestamp = Time.new(2023, 3, 15, 0, 0, 0).to_i # Example timestamp
      expect(Timet::TimeHelper.timestamp_to_time(timestamp)).to eq(Time.new(2023, 3, 15, 0, 0, 0).strftime('%H:%M:%S'))
    end

    it 'handles different timestamps correctly' do
      timestamp1 = Time.new(2023, 3, 15, 0, 0, 0).to_i
      timestamp2 = Time.new(2023, 3, 15, 3, 46, 40).to_i
      expect(Timet::TimeHelper.timestamp_to_time(timestamp1)).to eq(Time.new(2023, 3, 15, 0, 0, 0).strftime('%H:%M:%S'))
      expect(Timet::TimeHelper.timestamp_to_time(timestamp2)).to eq(Time.new(2023, 3, 15, 3, 46,
                                                                             40).strftime('%H:%M:%S'))
    end
  end

  describe '.format_time' do
    it 'returns nil if timestamp is nil' do
      expect(Timet::TimeHelper.format_time(nil)).to be_nil
    end

    it 'converts a timestamp to a formatted time string' do
      timestamp = Time.new(2024, 3, 15, 0, 0, 0).to_i # Example timestamp
      expect(Timet::TimeHelper.format_time(timestamp)).to eq(Time.new(2024, 3, 15, 0, 0,
                                                                      0).strftime('%Y-%m-%d %H:%M:%S'))
    end

    it 'handles different timestamps correctly' do
      timestamp1 = Time.new(2024, 3, 15, 0, 0, 0).to_i
      timestamp2 = Time.new(2024, 3, 15, 3, 46, 40).to_i
      expect(Timet::TimeHelper.format_time(timestamp1)).to eq(Time.new(2024, 3, 15, 0, 0,
                                                                       0).strftime('%Y-%m-%d %H:%M:%S'))
      expect(Timet::TimeHelper.format_time(timestamp2)).to eq(Time.new(2024, 3, 15, 3, 46,
                                                                       40).strftime('%Y-%m-%d %H:%M:%S'))
    end
  end
end
