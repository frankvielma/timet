# frozen_string_literal: true

require 'spec_helper'
require 'timet/utils'

RSpec.describe Timet::TimeReport do
  let(:db) { instance_double(Timet::Database) }
  let(:report) { described_class.new(db, csv: 'test_report', ics: 'test_calendar') }

  def items
    [
      [1, Time.new(2024, 1, 1, 10, 0, 0).to_i, Time.new(2024, 1, 1, 12, 0, 0).to_i, 'meeting', 'Discuss project'],
      [2, Time.new(2024, 1, 2, 14, 0, 0).to_i, Time.new(2024, 1, 2, 16, 0, 0).to_i, 'coding', 'Implement feature'],
      [3, Time.new(2024, 1, 3, 9, 0, 0).to_i, nil, 'task', 'Review code']
    ]
  end

  before do
    allow(db).to receive_messages(all_items: items, execute_sql: [])
  end

  describe '#export_csv' do
    it 'writes to the CSV file' do
      expect(report).to receive(:write_csv).with('test_report.csv').and_call_original
      report.export_csv
    end

    it 'outputs a message' do
      allow(report).to receive(:write_csv)
      expect { report.export_csv }.to output("The test_report.csv has been exported.\n").to_stdout
    end
  end

  describe '#export_icalendar' do
    it 'writes to the ics file' do
      expect(File).to receive(:write).with('test_calendar.ics', anything).and_call_original
      report.export_icalendar
    end

    it 'outputs a message' do
      allow(File).to receive(:write)
      expect { report.export_icalendar }.to output("The test_calendar.ics has been generated.\n").to_stdout
    end
  end
end
