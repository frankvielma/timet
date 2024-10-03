# frozen_string_literal: true

RSpec.describe Timet::TimeHelper do
  describe '.format_time' do
    it 'formats timestamp to YYYY-MM-DD HH:MM:SS' do
      expect(described_class.format_time(1_704_067_200)).to eq('2024-01-01 00:00:00')
    end

    it 'returns nil for nil input' do
      expect(described_class.format_time(nil)).to be_nil
    end
  end

  describe '.timestamp_to_date' do
    it 'converts timestamp to YYYY-MM-DD' do
      expect(described_class.timestamp_to_date(1_704_067_200)).to eq('2024-01-01')
    end

    it 'returns nil for nil input' do
      expect(described_class.timestamp_to_date(nil)).to be_nil
    end
  end

  describe '.timestamp_to_time' do
    it 'converts timestamp to HH:MM:SS' do
      expect(described_class.timestamp_to_time(1_704_067_200)).to eq('00:00:00')
    end

    it 'returns nil for nil input' do
      expect(described_class.timestamp_to_time(nil)).to be_nil
    end
  end

  describe '.calculate_duration' do
    it 'calculates duration between two timestamps' do
      expect(described_class.calculate_duration(1_703_995_200, 1_703_998_800)).to eq(3600)
    end

    it 'uses current time if end_time is nil' do
      allow(Time).to receive(:now).and_return(Time.at(1_703_998_800))
      expect(described_class.calculate_duration(1_703_995_200, nil)).to eq(3600)
    end
  end

  describe '.date_to_timestamp' do
    it 'converts Date to timestamp' do
      date = Date.new(2024, 1, 1)
      expect(described_class.date_to_timestamp(date)).to eq(1_704_067_200)
    end
  end

  describe '.calculate_end_time' do
    it 'calculates end time when end_date is provided' do
      start_date = Date.new(2024, 1, 1)
      end_date = Date.new(2024, 1, 2)
      expect(described_class.calculate_end_time(start_date, end_date)).to eq(1_704_240_000)
    end

    it 'calculates end time as next day when end_date is nil' do
      start_date = Date.new(2024, 1, 1)
      expect(described_class.calculate_end_time(start_date, nil)).to eq(1_704_153_600)
    end
  end

  describe '.extract_date' do
    let(:items) do
      [
        [1, 1_704_081_600, nil, 'tag1', 'notes1'],
        [2, 1_704_168_000, nil, 'tag2', 'notes2'],
        [3, 1_704_168_000, nil, 'tag3', 'notes3']
      ]
    end

    it 'extracts date when it changes' do
      expect(described_class.extract_date(items, 1)).to eq('2024-01-02')
    end

    it 'returns nil when date does not change' do
      expect(described_class.extract_date(items, 2)).to be_nil
    end

    it 'returns date for the first item' do
      expect(described_class.extract_date(items, 0)).to eq('2024-01-01')
    end
  end

  describe '.format_time_string' do
    it 'returns an empty string for nil input' do
      expect(described_class.format_time_string(nil)).to be_nil
    end

    it 'returns format "00:00:00" for an empty string' do
      expect(described_class.format_time_string('')).to be_nil
    end

    it 'returns format "00:00:00" for a single digit' do
      expect(described_class.format_time_string('1')).to eq('01:00:00')
      expect(described_class.format_time_string('01')).to eq('01:00:00')
      expect(described_class.format_time_string('09')).to eq('09:00:00')
    end

    it 'returns format "00:00:00" for two digits' do
      expect(described_class.format_time_string('12')).to eq('12:00:00')
    end

    it 'returns format "00:00:00" for three digits' do
      expect(described_class.format_time_string('123')).to eq('12:30:00')
    end

    it 'returns format "00:00:00" for four digits' do
      expect(described_class.format_time_string('1234')).to eq('12:34:00')
    end

    it 'returns format "00:00:00" for five digits' do
      expect(described_class.format_time_string('12345')).to eq('12:34:50')
    end

    it 'returns format "00:00:00" for six digits' do
      expect(described_class.format_time_string('123456')).to eq('12:34:56')
    end

    it 'returns format "00:00:00" for six digits with non-digit characters' do
      expect(described_class.format_time_string('1a2b3c4d5e6f')).to eq('12:34:56')
    end

    it 'returns nil for invalid time values' do
      expect(described_class.format_time_string('240000')).to be_nil
      expect(described_class.format_time_string('126000')).to be_nil
      expect(described_class.format_time_string('123460')).to be_nil
    end
  end
end
