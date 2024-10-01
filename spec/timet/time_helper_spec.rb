# frozen_string_literal: true

RSpec.describe Timet::TimeHelper do
  describe '.format_time' do
    it 'formats timestamp to YYYY-MM-DD HH:MM:SS' do
      expect(described_class.format_time(1_704_081_600)).to eq('2024-01-01 00:00:00')
    end

    it 'returns nil for nil input' do
      expect(described_class.format_time(nil)).to be_nil
    end
  end

  describe '.timestamp_to_date' do
    it 'converts timestamp to YYYY-MM-DD' do
      expect(described_class.timestamp_to_date(1_704_081_600)).to eq('2024-01-01')
    end

    it 'returns nil for nil input' do
      expect(described_class.timestamp_to_date(nil)).to be_nil
    end
  end

  describe '.timestamp_to_time' do
    it 'converts timestamp to HH:MM:SS' do
      expect(described_class.timestamp_to_time(1_704_081_600)).to eq('00:00:00')
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
      expect(described_class.date_to_timestamp(date)).to eq(1_704_081_600)
    end
  end

  describe '.calculate_end_time' do
    it 'calculates end time when end_date is provided' do
      start_date = Date.new(2024, 1, 1)
      end_date = Date.new(2024, 1, 2)
      expect(described_class.calculate_end_time(start_date, end_date)).to eq(1_704_168_000)
    end

    it 'calculates end time as next day when end_date is nil' do
      start_date = Date.new(2024, 1, 1)
      expect(described_class.calculate_end_time(start_date, nil)).to eq(1_704_168_000)
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
    it 'formats a valid time string' do
      expect(described_class.format_time_string('123456')).to eq('12:34:56')
    end

    it 'pads single-digit input' do
      expect(described_class.format_time_string('1')).to eq('01:00:00')
    end

    it 'removes non-digit characters' do
      expect(described_class.format_time_string('12:34:56')).to eq('12:34:56')
    end

    it 'handles nil input' do
      expect(described_class.format_time_string(nil)).to eq('')
    end

    it 'pads incomplete input' do
      expect(described_class.format_time_string('12')).to eq('12:00:00')
    end
  end
end
