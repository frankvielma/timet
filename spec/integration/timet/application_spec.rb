# frozen_string_literal: true

require 'spec_helper'
require 'timet/application'
require 'timet/database'
require 'tempfile'
require 'date'

RSpec.describe Timet::Application, type: :integration do
  let(:db) { app.instance_variable_get(:@db) }
  let(:app) do
    command_double = instance_double(
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
    args = [[], {}, { current_command: command_double }]
    described_class.new(*args)
  end

  let(:db_path) { Tempfile.new(['test_db', '.sqlite3']).path }

  before do
    # Stub the Database initialization to use our test database
    allow(Timet::Database).to receive(:new).and_return(Timet::Database.new(db_path))

    # Create the test database schema
    db.execute_sql(<<-SQL)
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

    it 'creates and completes a task' do
      # Create and complete a task
      app.start('meeting', 'First meeting')
      app.stop

      # Verify item was created and completed
      items = app.instance_variable_get(:@db).all_items
      expect(items.length).to eq(1)
      expect(items.first[3]).to eq('meeting')
      expect(items.first[4]).to eq('First meeting')
      expect(items.first[2]).not_to be_nil # Verify end time is set (completed)
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

    it 'cancels active time tracking and outputs a confirmation message' do
      expect { app.cancel }.to output(/Canceled active time tracking/).to_stdout
    end

    it 'cancels active time tracking and deletes the tracked item' do
      app.cancel # Execute cancel to ensure deletion
      items = db.all_items
      expect(items.length).to eq(0)
    end
  end

  describe 'reporting and summary' do
    before do
      create_test_data
    end

    def create_test_data
      today = Date.today

      # Clear existing items
      db.execute_sql('DELETE FROM items')

      # Today's entries with explicit deleted = 0
      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes, deleted, created_at, updated_at, pomodoro)
        VALUES (?, ?, 'work', 'Task 1', 0, ?, ?, 0)",
        [Time.new(today.year, today.month, today.day, 9, 0, 0).to_i,
         Time.new(today.year, today.month, today.day, 10, 0, 0).to_i,
         Time.now.to_i,
         Time.now.to_i]
      )

      db.execute_sql(
        "INSERT INTO items (start, end, tag, notes, deleted, created_at, updated_at, pomodoro)
        VALUES (?, ?, 'meeting', 'Meeting 1', 0, ?, ?, 0)",
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

      Timet::Table.new(filter, items, db)

      expect { app.summary(filter) }.to output(
        match(/#{Date.today}/)
          .and(match(/meetin/))
          .and(match(/work/))
          .and(match(/02:00:00/))
          .and(match(/AVG: 60.0min/))
      ).to_stdout
    end

    describe 'exports data to CSV' do
      let(:temp_csv) { Tempfile.new(['test_export', '.csv']) }

      after do
        temp_csv.close
        temp_csv.unlink
      end

      before do
        allow(app).to receive(:options).and_return({ csv: temp_csv.path })
        app.summary('today')
      end

      it 'exports data to CSV file' do
        expect(File.exist?(temp_csv.path)).to be true
      end

      it 'exports CSV with correct header' do
        csv_content = CSV.read(temp_csv.path)
        expect(csv_content[0]).to eq(%w[ID Start End Tag Notes])
      end

      it 'exports CSV with correct number of rows' do
        csv_content = CSV.read(temp_csv.path)
        expect(csv_content.length).to eq(3) # Header + 2 entries
      end

      it 'exports CSV with correct first data row tag' do
        csv_content = CSV.read(temp_csv.path)
        expect(csv_content[1][3]).to eq('meeting')
      end

      it 'exports CSV with correct second data row tag' do
        csv_content = CSV.read(temp_csv.path)
        expect(csv_content[2][3]).to eq('work')
      end
    end
  end

  describe 'task editing' do
    let!(:task_id) do
      app.start('work', 'Original task')
      app.stop
      app.instance_variable_get(:@db).fetch_last_id
    end

    it 'edits task notes and outputs confirmation' do
      # Stub TTY::Prompt to avoid interactive prompts
      prompt = instance_double(TTY::Prompt)
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive_messages(select: 'notes', ask: 'Updated notes')

      expect { app.edit(task_id) }.to output(/Updated notes/).to_stdout
    end

    it 'updates task notes in database' do
      # Stub TTY::Prompt to avoid interactive prompts
      prompt = instance_double(TTY::Prompt)
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive_messages(select: 'notes', ask: 'Updated notes')

      app.edit(task_id)

      # Verify notes were updated
      item = db.find_item(task_id)
      expect(item[4]).to eq('Updated notes')
    end

    it 'deletes a task and outputs confirmation' do
      # Stub TTY::Prompt confirmation
      prompt = instance_double(TTY::Prompt)
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive(:yes?).and_return(true)

      expect { app.delete(task_id) }.to output(/Deleted/).to_stdout
    end

    it 'deletes task from database' do
      # Stub TTY::Prompt confirmation
      prompt = instance_double(TTY::Prompt)
      allow(TTY::Prompt).to receive(:new).and_return(prompt)
      allow(prompt).to receive(:yes?).and_return(true)

      app.delete(task_id)

      # Verify task was deleted
      items = db.all_items
      expect(items.length).to eq(0)
    end
  end
end
