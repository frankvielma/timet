# frozen_string_literal: true

require 'spec_helper'
require 'timet/time_statistics'
require 'timet/database'
require 'date'
require 'tempfile'

RSpec.describe Timet::TimeStatistics, type: :integration do
  let(:db_path) { Tempfile.new(['test_db', '.sqlite3']).path }
  let(:items) { db.execute_sql('SELECT * FROM items') }
  let(:statistics) { described_class.new(items) }
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

    # Insert test data with known durations for predictable statistics
    today = Date.today

    # Work entries - 1 hour each
    db.execute_sql(
      "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'work', 'Task 1')",
      [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
       Time.new(today.year, today.month, today.day, 10, 0, 0).to_i]
    )

    db.execute_sql(
      "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'work', 'Task 2')",
      [Time.new(today.year, today.month, today.day, 11, 0, 0).to_i,
       Time.new(today.year, today.month, today.day, 12, 0, 0).to_i]
    )

    # Meeting entries - 30 minutes each
    db.execute_sql(
      "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'meeting', 'Meeting 1')",
      [Time.new(today.year, today.month, today.day, 14, 0, 0).to_i,
       Time.new(today.year, today.month, today.day, 14, 30, 0).to_i]
    )

    db.execute_sql(
      "INSERT INTO items (start, end, tag, notes) VALUES
			(?, ?, 'meeting', 'Meeting 2')",
      [Time.new(today.year, today.month, today.day, 15, 0, 0).to_i,
       Time.new(today.year, today.month, today.day, 15, 30, 0).to_i]
    )
  end

  after do
    FileUtils.rm_f(db_path)
  end

  describe 'duration calculations' do
    it 'correctly calculates total duration for all entries' do
      # Total: 2 hours (work) + 1 hour (meetings) = 3 hours
      expect(statistics.total_duration).to eq(3 * 3600)
    end

    it 'correctly calculates duration by tag' do
      duration_by_tag = statistics.total_duration_by_tag
      expect(duration_by_tag['work']).to eq(2 * 3600) # 2 hours
      expect(duration_by_tag['meeting']).to eq(1 * 3600) # 1 hour
    end

    it 'provides sorted durations by tag' do
      sorted = statistics.sorted_duration_by_tag
      expect(sorted.first).to eq(['work', 2 * 3600])     # Most time spent
      expect(sorted.last).to eq(['meeting', 1 * 3600])   # Least time spent
    end
  end

  describe 'statistical calculations' do
    it 'calculates correct averages by tag' do
      averages = statistics.average_by_tag
      expect(averages['work']).to eq(3600)     # 1 hour average
      expect(averages['meeting']).to eq(1800)  # 30 minutes average
    end

    it 'calculates standard deviation by tag' do
      std_dev = statistics.standard_deviation_by_tag
      # Since durations are identical within tags, std dev should be 0
      expect(std_dev['work']).to eq(0)
      expect(std_dev['meeting']).to eq(0)
    end

    it 'provides overall statistics' do
      totals = statistics.totals
      expect(totals[:total]).to eq(3 * 3600) # 3 hours total
      expect(totals[:avg]).to be_within(0.1).of(2700) # Average of all entries (45 minutes)
    end

    it 'provides detailed statistics by tag' do
      stats = statistics.additional_stats_by_tag

      work_stats = stats['work']
      expect(work_stats[:min]).to eq(3600)    # 1 hour
      expect(work_stats[:max]).to eq(3600)    # 1 hour
      expect(work_stats[:mean]).to eq(3600)   # 1 hour

      meeting_stats = stats['meeting']
      expect(meeting_stats[:min]).to eq(1800)   # 30 minutes
      expect(meeting_stats[:max]).to eq(1800)   # 30 minutes
      expect(meeting_stats[:mean]).to eq(1800)  # 30 minutes
    end
  end
end
