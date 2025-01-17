# frozen_string_literal: true

require 'spec_helper'
require 'timet/time_report'
require 'timet/database'
require 'date'
require 'tempfile'

RSpec.describe Timet::TimeReport, type: :integration do
  let(:db_path) { Tempfile.new(['test_db', '.sqlite3']).path }
  let(:db) { Timet::Database.new(db_path) }

  before do
    # Setup test database
    db.execute_sql(<<-SQL)
			CREATE TABLE IF NOT EXISTS items (
				id INTEGER PRIMARY KEY,
				start INTEGER,
				end INTEGER,
				tag TEXT,
				notes TEXT,
				deleted INTEGER DEFAULT 0
			)
    SQL

    # Insert test data
    today = Date.today
    yesterday = today - 1

    # Today's entries
    db.execute_sql(
      "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'work', 'Testing task 1')",
      [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
       Time.new(today.year, today.month, today.day, 10, 0, 0).to_i]
    )

    # Yesterday's entries
    db.execute_sql(
      "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'meeting', 'Testing task 2')",
      [Time.new(yesterday.year, yesterday.month, yesterday.day, 14, 0, 0).to_i,
       Time.new(yesterday.year, yesterday.month, yesterday.day, 15, 0, 0).to_i]
    )
  end

  after do
    FileUtils.rm_f(db_path)
  end

  describe 'filtering' do
    it 'filters entries for today' do
      report = described_class.new(db, filter: 'today')
      expect(report.items.length).to eq(1)
      expect(report.items.first[3]).to eq('work')
    end

    it 'filters entries for yesterday' do
      report = described_class.new(db, filter: 'yesterday')
      expect(report.items.length).to eq(1)
      expect(report.items.first[3]).to eq('meeting')
    end

    it 'filters by tag' do
      report = described_class.new(db, filter: 'today', tag: 'work')
      expect(report.items.length).to eq(1)
      expect(report.items.first[3]).to eq('work')
    end
  end

  describe 'CSV export' do
    it 'exports entries to CSV' do
      temp_csv = Tempfile.new(['test_export', '.csv'])
      begin
        report = described_class.new(db, filter: 'today', csv: temp_csv.path)
        report.send(:write_csv, temp_csv.path)

        csv_content = CSV.read(temp_csv.path)
        expect(csv_content.length).to eq(2) # Header + 1 entry
        expect(csv_content[0]).to eq(%w[ID Start End Tag Notes])
        expect(csv_content[1][3]).to eq('work')
      ensure
        temp_csv.close
        temp_csv.unlink
      end
    end
  end

  describe 'display' do
    it 'displays report without errors' do
      report = described_class.new(db, filter: 'today')
      expect { report.display }.not_to raise_error
    end

    it 'shows appropriate message for empty results' do
      report = described_class.new(db, filter: 'today', tag: 'nonexistent')
      expect { report.display }.to output(/No tracked time found for the specified filter/).to_stdout
    end
  end
end
