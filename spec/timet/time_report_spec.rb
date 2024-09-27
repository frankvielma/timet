# frozen_string_literal: true

require_relative '../helpers'
require 'byebug'

RSpec.describe Timet::TimeReport do
  let(:db) do
    # Initialize the in-memory SQLite database
    Timet::Database.new(':memory:').tap do |database|
      database.execute_sql <<-SQL
        CREATE TABLE items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          start INTEGER,
          end INTEGER,
          tag TEXT
        );
      SQL
    end
  end

  let(:time_report) { described_class.new(db, nil, nil, nil) }

  before do
    db.execute_sql('DELETE FROM items')
  end

  describe '#display' do
    context 'when no tracked time found' do
      it 'prints a message indicating no tracked time' do
        expect { time_report.display }.to output("No tracked time found for the specified filter.\n").to_stdout
      end
    end

    context 'when tracked time exists' do
      before do
        db.execute_sql('INSERT INTO items (start, end, tag) VALUES (?, ?, ?)',
                       [Time.now.to_i, Time.now.to_i + 3600, 'Work'])
      end

      it 'prints a formatted time report' do
        start_time = Timet::TimeHelper.format_time(Time.now.to_i)
        end_time = Timet::TimeHelper.format_time(Time.now.to_i + 3600)

        expected_output = expected_time_report(start_time, end_time)
        expect { time_report.display }.to output(expected_output).to_stdout
      end
    end
  end
end
