# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Timet::TimeReportHelper do
  include described_class

  # Mock the items method for testing
  def items
    [
      [1, Time.new(2024, 1, 1, 10, 0, 0).to_i, Time.new(2024, 1, 1, 12, 0, 0).to_i, 'meeting', 'Discuss project'],
      [2, Time.new(2024, 1, 2, 14, 0, 0).to_i, Time.new(2024, 1, 2, 16, 0, 0).to_i, 'coding', 'Implement feature'],
      [3, Time.new(2024, 1, 3, 9, 0, 0).to_i, nil, 'task', 'Review code']
    ]
  end

  # Mock the csv_filename method for testing
  def csv_filename
    'test_report'
  end

  # Mock the ics_filename method for testing
  def ics_filename
    'test_calendar'
  end

  # Mock the write_csv method for testing
  def write_csv(_file_name)
    # Do nothing
  end

  describe '#date_ranges' do
    it 'returns the correct date ranges' do
      today = Date.today
      tomorrow = today + 1
      expected_ranges = {
        'today' => [today, nil],
        'yesterday' => [today - 1, nil],
        'week' => [today - 7, tomorrow],
        'month' => [today - 30, tomorrow]
      }
      expect(date_ranges).to eq(expected_ranges)
    end
  end

  describe '#format_item' do
    let(:item) do
      [1, Time.new(2024, 1, 1, 10, 0, 0).to_i, Time.new(2024, 1, 1, 12, 0, 0).to_i, 'meeting', 'Discuss project']
    end
    let(:formatted_item) { format_item(item) }

    it 'formats an item for CSV export - id' do
      expect(formatted_item[0]).to eq(item[0])
    end

    it 'formats an item for CSV export - start time' do
      expect(formatted_item[1]).to eq(Timet::TimeHelper.format_time(item[1]))
    end

    it 'formats an item for CSV export - end time' do
      expect(formatted_item[2]).to eq(Timet::TimeHelper.format_time(item[2]))
    end

    it 'formats an item for CSV export - tag' do
      expect(formatted_item[3]).to eq(item[3])
    end

    it 'formats an item for CSV export - notes' do
      expect(formatted_item[4]).to eq(item[4])
    end
  end

  describe '#valid_date_format?' do
    it 'returns true for valid single date format' do
      expect(valid_date_format?('2024-01-01')).to be true
    end

    it 'returns true for valid date range format' do
      expect(valid_date_format?('2024-01-01..2024-01-31')).to be true
    end

    it 'returns false for invalid date format' do
      expect(valid_date_format?('2024-01')).to be false
    end
  end

  describe '#add_hashes' do
    let(:base_hash) { { 'key1' => [10, 'tag1'], 'key2' => [20, 'tag2'] } }
    let(:additional_hash) { { 'key1' => [5, 'tag1'], 'key3' => [15, 'tag3'] } }
    let(:merged_hash) { add_hashes(base_hash, additional_hash) }

    it 'merges the key1' do
      expect(merged_hash['key1']).to eq([15, 'tag1'])
    end

    it 'merges the key2' do
      expect(merged_hash['key2']).to eq([20, 'tag2'])
    end

    it 'merges the key3' do
      expect(merged_hash['key3']).to eq([15, 'tag3'])
    end
  end

  describe '#export_csv' do
    it 'writes to the CSV file' do
      allow(self).to receive(:write_csv).with('test_report.csv').and_call_original
      export_csv
      expect(self).to have_received(:write_csv).with('test_report.csv').at_least(:once)
    end

    it 'outputs a message' do
      allow(self).to receive(:write_csv)
      expect { export_csv }.to output("The test_report.csv has been exported.\n").to_stdout
    end
  end

  describe '#export_icalendar' do
    it 'writes to the ics file' do
      allow(File).to receive(:write).with('test_calendar.ics', anything).and_call_original
      export_icalendar
      expect(File).to have_received(:write).with('test_calendar.ics', anything).once
    end

    it 'outputs a message' do
      allow(File).to receive(:write)
      expect { export_icalendar }.to output("The test_calendar.ics has been generated.\n").to_stdout
    end
  end

  describe '#add_events' do
    let(:cal) { send(:add_events) }

    it 'creates an iCalendar object' do
      expect(cal).to be_an_instance_of(Icalendar::Calendar)
    end

    it 'adds events to the calendar' do
      expect(cal.events.size).to eq(3)
    end
  end

  describe '#create_event' do
    let(:item) do
      [1, Time.new(2024, 1, 1, 10, 0, 0).to_i, Time.new(2024, 1, 1, 12, 0, 0).to_i, 'meeting', 'Discuss project']
    end
    let(:event) { send(:create_event, item) }

    it 'creates an iCalendar event' do
      expect(event).to be_an_instance_of(Icalendar::Event)
    end

    it 'sets the correct start time' do
      expect(event.dtstart).to eq(Time.at(item[1]).to_datetime)
    end

    it 'sets the correct end time' do
      expect(event.dtend).to eq(Time.at(item[2]).to_datetime)
    end

    it 'sets the correct summary' do
      expect(event.summary).to eq(item[3])
    end

    it 'sets the correct description' do
      expect(event.description).to eq(item[4])
    end

    it 'sets the correct privacy class' do
      expect(event.ip_class).to eq('PRIVATE')
    end
  end

  describe '#convert_to_datetime' do
    it 'converts a timestamp to a DateTime object' do
      timestamp = Time.new(2024, 1, 1, 10, 0, 0).to_i
      datetime = send(:convert_to_datetime, timestamp)
      expect(datetime).to eq(Time.at(timestamp).to_datetime)
    end
  end
end
