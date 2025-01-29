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
    it 'formats an item for CSV export' do
      item = [1, Time.new(2024, 1, 1, 10, 0, 0).to_i, Time.new(2024, 1, 1, 12, 0, 0).to_i, 'meeting', 'Discuss project']
      formatted_item = format_item(item)
      expect(formatted_item[0]).to eq(item[0])
      expect(formatted_item[1]).to eq(Timet::TimeHelper.format_time(item[1]))
      expect(formatted_item[2]).to eq(Timet::TimeHelper.format_time(item[2]))
      expect(formatted_item[3]).to eq(item[3])
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
    it 'merges two hashes and sums the values' do
      base_hash = { 'key1' => [10, 'tag1'], 'key2' => [20, 'tag2'] }
      additional_hash = { 'key1' => [5, 'tag1'], 'key3' => [15, 'tag3'] }
      merged_hash = add_hashes(base_hash, additional_hash)
      expect(merged_hash['key1']).to eq([15, 'tag1'])
      expect(merged_hash['key2']).to eq([20, 'tag2'])
      expect(merged_hash['key3']).to eq([15, 'tag3'])
    end
  end

  describe '#export_csv' do
    it 'exports the report to a CSV file' do
      allow(self).to receive(:write_csv).with('test_report.csv').and_call_original
      expect { export_csv }.to output("The test_report.csv has been exported.\n").to_stdout
      expect(self).to have_received(:write_csv).with('test_report.csv').at_least(:once)
    end
  end

  describe '#export_icalendar' do
    it 'generates an iCalendar file' do
      allow(File).to receive(:write).with('test_calendar.ics', anything).and_call_original
      expect { export_icalendar }.to output("The test_calendar.ics has been generated.\n").to_stdout
      expect(File).to have_received(:write).with('test_calendar.ics', anything).once
    end
  end

  describe '#add_events' do
    it 'creates an iCalendar object and adds events' do
      cal = send(:add_events)
      expect(cal).to be_an_instance_of(Icalendar::Calendar)
      expect(cal.events.size).to eq(3)
    end
  end

  describe '#create_event' do
    it 'creates an iCalendar event' do
      item = [1, Time.new(2024, 1, 1, 10, 0, 0).to_i, Time.new(2024, 1, 1, 12, 0, 0).to_i, 'meeting', 'Discuss project']
      event = send(:create_event, item)
      expect(event).to be_an_instance_of(Icalendar::Event)
      expect(event.dtstart).to eq(Time.at(item[1]).to_datetime)
      expect(event.dtend).to eq(Time.at(item[2]).to_datetime)
      expect(event.summary).to eq(item[3])
      expect(event.description).to eq(item[4])
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
