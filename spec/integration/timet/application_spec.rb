# frozen_string_literal: true

require 'spec_helper'
require 'timet/application'
require 'timet/database'
require 'tempfile'
require 'date'

RSpec.describe Timet::Application, type: :integration do
  let(:tempfile) { Tempfile.new(['test_db', '.sqlite3']) }
  let(:db_path) { tempfile.path }
  let(:command_double) do
    instance_double(
      Thor::Command,
      name: 'start',
      description: 'Start tracking time',
      long_description: 'Start tracking time with optional notes',
      usage: 'start [TAG] [NOTES]',
      options: {},
      hidden?: false,
      ancestor_name: nil,
      options_relation: {},
      required_options: []
    )
  end

  let(:args) { [[], {}, { current_command: command_double }] }
  let(:app) { described_class.new(*args) }

  before do
    # Stub the Database initialization to use our test database
    allow(Timet::Database).to receive(:new).and_return(Timet::Database.new(db_path))

    # Create the test database schema
    @db = app.instance_variable_get(:@db)
    @db.execute_sql(<<-SQL)
      CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY,
        start INTEGER,
        end INTEGER,
        tag TEXT,
        notes TEXT,
        deleted INTEGER DEFAULT 0,
        pomodoro INTEGER
      )
    SQL
  end

  after do
    FileUtils.rm_f(db_path)
  end

  describe 'time tracking commands' do
    it 'starts and stops time tracking' do
      # Start tracking
      expect { app.start('work', 'Testing task') }.to output(/work/).to_stdout

      # Verify item was created
      items = app.instance_variable_get(:@db).all_items
      expect(items.length).to eq(1)
      expect(items.first[3]).to eq('work')
      expect(items.first[4]).to eq('Testing task')

      # Stop tracking
      expect { app.stop }.to output(/work/).to_stdout

      # Verify end time was set
      items = app.instance_variable_get(:@db).all_items
      expect(items.first[2]).not_to be_nil
    end

    it 'resumes the last task' do
      # Create and complete a task
      app.start('meeting', 'First meeting')
      app.stop

      # Resume the task
      expect { app.resume }.to output(/meeting/).to_stdout

      # Verify a new item was created with same tag and notes
      items = app.instance_variable_get(:@db).all_items
      expect(items.length).to eq(2)
      expect(items.first[3]).to eq('meeting')
      expect(items.first[4]).to eq('First meeting')
    end

    it 'cancels active time tracking' do
      app.start('study', 'Learning Ruby')
      expect { app.cancel }.to output(/Canceled active time tracking/).to_stdout

      # Verify item was deleted
      items = app.instance_variable_get(:@db).all_items
      expect(items.length).to eq(0)
    end
  end

  describe 'reporting and summary' do
    before do
      # Create some test data
      today = Date.today
      db = app.instance_variable_get(:@db)

      # Clear existing items
      db.execute_sql('DELETE FROM items')

      # Today's entries with explicit deleted = 0
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes, deleted, created_at, updated_at, pomodoro) VALUES (?, ?, 'work', 'Task 1', 0, ?, ?, 0)",
        [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
         Time.new(today.year, today.month, today.day, 10, 0, 0).to_i,
         Time.now.to_i,
         Time.now.to_i]
      )

      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes, deleted, created_at, updated_at, pomodoro) VALUES (?, ?, 'meeting', 'Meeting 1', 0, ?, ?, 0)",
        [Time.new(today.year, today.month, today.day, 11, 0, 0).to_i,
         Time.new(today.year, today.month, today.day, 12, 0, 0).to_i,
         Time.now.to_i,
         Time.now.to_i]
      )
    end

    it 'generates summary for today' do
      filter = 'today'
      items = [
        [1, Time.new(Date.today.year, Date.today.month, Date.today.day, 9, 0, 0).to_i,
         Time.new(Date.today.year, Date.today.month, Date.today.day, 10, 0, 0).to_i, 'work', 'Task 1'],
        [2, Time.new(Date.today.year, Date.today.month, Date.today.day, 11, 0, 0).to_i,
         Time.new(Date.today.year, Date.today.month, Date.today.day, 12, 0, 0).to_i, 'meeting', 'Meeting 1']
      ]

      Timet::Table.new(filter, items, @db)

      expect { app.summary(filter) }.to output(
        match(/#{Date.today}/)
          .and(match(/meetin/))
          .and(match(/work/))
          .and(match(/02:00:00/))
          .and(match(/AVG: 60.0min/))
      ).to_stdout
    end

    it 'exports data to CSV' do
      temp_csv = Tempfile.new(['test_export', '.csv'])
      begin
        # Mock Thor options
        allow(app).to receive(:options).and_return({ csv: temp_csv.path })

        app.summary('today')

        # Ensure the file exists and has content
        expect(File.exist?(temp_csv.path)).to be true

        # Read and verify CSV content
        csv_content = CSV.read(temp_csv.path)
        expect(csv_content.length).to eq(3) # Header + 2 entries
        expect(csv_content[0]).to eq(%w[ID Start End Tag Notes])
        expect(csv_content[1][3]).to eq('meeting')
        expect(csv_content[2][3]).to eq('work')
      ensure
        temp_csv.close
        temp_csv.unlink
      end
    end
  end

  describe 'task editing' do
    let!(:task_id) do
      app.start('work', 'Original task')
      app.stop
      app.instance_variable_get(:@db).fetch_last_id
    end

    it 'edits task notes' do
      # Stub TTY::Prompt to avoid interactive prompts
      allow_any_instance_of(TTY::Prompt).to receive(:select).and_return('notes')
      allow_any_instance_of(TTY::Prompt).to receive(:ask).and_return('Updated notes')

      expect { app.edit(task_id) }.to output(/Updated notes/).to_stdout

      # Verify notes were updated
      item = app.instance_variable_get(:@db).find_item(task_id)
      expect(item[4]).to eq('Updated notes')
    end

    it 'deletes a task' do
      # Stub TTY::Prompt confirmation
      allow_any_instance_of(TTY::Prompt).to receive(:yes?).and_return(true)

      expect { app.delete(task_id) }.to output(/Deleted/).to_stdout

      # Verify task was deleted
      items = app.instance_variable_get(:@db).all_items
      expect(items.length).to eq(0)
    end
  end
end
