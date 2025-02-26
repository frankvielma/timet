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
    db.execute_sql('DELETE FROM items')
  end

  after do
    FileUtils.rm_f(db_path)
  end

  describe 'filtering' do
    it 'filters entries for today and returns the correct number of items' do
      today = Date.today
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'work', 'Testing task 1')",
        [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
         Time.new(today.year, today.month, today.day, 10, 0, 0).to_i]
      )
      report = described_class.new(db, filter: 'today')
      expect(report.items.length).to eq(1)
    end

    it 'filters entries for today and returns the correct type of work' do
      today = Date.today
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'work', 'Testing task 1')",
        [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
         Time.new(today.year, today.month, today.day, 10, 0, 0).to_i]
      )
      report = described_class.new(db, filter: 'today')
      expect(report.items.first[3]).to eq('work')
    end

    it 'filters entries for yesterday' do
      yesterday = Date.today - 1
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'meeting', 'Testing task 2')",
        [Time.new(yesterday.year, yesterday.month, yesterday.day, 14, 0, 0).to_i,
         Time.new(yesterday.year, yesterday.month, yesterday.day, 15, 0, 0).to_i]
      )
      report = described_class.new(db, filter: 'yesterday')
      expect(report.items.length).to eq(1)
    end

    it 'verifies the first item is a meeting' do
      yesterday = Date.today - 1
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'meeting', 'Testing task 2')",
        [Time.new(yesterday.year, yesterday.month, yesterday.day, 14, 0, 0).to_i,
         Time.new(yesterday.year, yesterday.month, yesterday.day, 15, 0, 0).to_i]
      )
      report = described_class.new(db, filter: 'yesterday')
      expect(report.items.first[3]).to eq('meeting')
    end

    it 'filters by tag' do
      today = Date.today
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'work', 'Testing task 1')",
        [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
         Time.new(today.year, today.month, today.day, 10, 0, 0).to_i]
      )
      report = described_class.new(db, filter: 'today', tag: 'work')
      expect(report.items.length).to eq(1)
    end

    it 'verifies the first item is tagged as work' do
      today = Date.today
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'work', 'Testing task 1')",
        [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
         Time.new(today.year, today.month, today.day, 10, 0, 0).to_i]
      )
      report = described_class.new(db, filter: 'today', tag: 'work')
      expect(report.items.first[3]).to eq('work')
    end

    it 'filters entries by date range' do
      today = Date.today
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'work', 'Testing task 1')",
        [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
         Time.new(today.year, today.month, today.day, 10, 0, 0).to_i]
      )
      report = described_class.new(db, filter: "#{today}..#{today}")
      expect(report.items.length).to eq(1)
    end

    it 'handles invalid filter' do
      report = described_class.new(db, filter: 'invalid_filter')
      expect(report.items).to eq([])
    end
  end

  describe 'CSV export' do
    let(:today) { Date.today }
    let(:start_time) { Time.new(today.year, today.month, today.day, 9, 0, 0).to_i }
    let(:end_time) { Time.new(today.year, today.month, today.day, 10, 0, 0).to_i }
    let(:csv_header) { %w[ID Start End Tag Notes] }
    let(:csv_entry) { [anything, start_time, end_time, 'work', 'Testing task 1'] }

    before do
      db.execute_sql(
        'INSERT INTO items (start, end, tag, notes) VALUES (?, ?, ?, ?)',
        [start_time, end_time, 'work', 'Testing task 1']
      )
    end

    def read_csv(path)
      CSV.read(path)
    end

    it 'exports entries to CSV' do
      temp_csv = Tempfile.new(['test_export', '.csv'])
      report = described_class.new(db, filter: 'today', csv: temp_csv.path)
      report.send(:write_csv, temp_csv.path)

      csv_content = read_csv(temp_csv.path)
      expect(csv_content.length).to eq(2)
      temp_csv.close!
    end

    it 'verifies the CSV header' do
      temp_csv = Tempfile.new(['test_export', '.csv'])
      report = described_class.new(db, filter: 'today', csv: temp_csv.path)
      report.send(:write_csv, temp_csv.path)

      csv_content = read_csv(temp_csv.path)
      expect(csv_content[0]).to eq(csv_header)
      temp_csv.close!
    end

    it 'verifies the CSV content' do
      temp_csv = Tempfile.new(['test_export', '.csv'])
      report = described_class.new(db, filter: 'today', csv: temp_csv.path)
      report.send(:write_csv, temp_csv.path)

      csv_content = read_csv(temp_csv.path)
      expect(csv_content[1][3]).to eq('work')
      temp_csv.close!
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
