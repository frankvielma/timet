# frozen_string_literal: true

require 'timet/database'
require 'tmpdir'
require 'set' # Add require for Set

RSpec.describe Timet::Database do
  let(:db_path) { File.join(Dir.tmpdir, 'test_timet.db') }
  let(:db) { described_class.new(db_path) }
  let(:last_item) do
    db.execute_sql('SELECT * FROM items ORDER BY id DESC LIMIT 1').first
  end

  after do
    db.close
    FileUtils.rm_f(db_path)
  end

  # Test Table Creation
  describe '#create_table' do
    it "creates the items table if it doesn't exist" do
      expect { db.create_table }.not_to raise_error
    end

    # Ensure the table has the expected structure
    it 'creates a table with the correct columns' do
      db.create_table

      # Retrieve table schema
      schema = db.execute_sql('PRAGMA table_info(items)').map { |row| row[1] }
      # Use a set for order-independent comparison
      expect(Set.new(schema)).to eq(Set.new(%w[id start end tag notes pomodoro updated_at created_at deleted]))
    end
  end

  # Test Item Insertion
  describe '#insert_item' do
    let(:start_time) { 1_700_000_000 }
    let(:tag) { 'work' }

    context 'without notes' do
      before do
        db.insert_item(start_time, tag, '')
      end

      it 'inserts an item into the table' do
        expect(db.fetch_last_id).to eq(1)
      end

      it 'inserts an item with the correct start time' do
        expect(db.last_item[1]).to eq(start_time)
      end

      it 'inserts an item with the correct tag' do
        expect(db.last_item[3]).to eq(tag)
      end
    end

    context 'with notes' do
      it 'inserts an item with nil notes' do
        notes = nil
        db.insert_item(start_time, tag, notes)
        expect(last_item[4]).to be_nil
      end

      it 'inserts an item with empty notes' do
        notes = ''
        db.insert_item(start_time, tag, notes)
        expect(last_item[4]).to eq('')
      end

      it 'inserts an item with short notes' do
        notes = 'short string'
        db.insert_item(start_time, tag, notes)
        expect(last_item[4]).to eq('short string')
      end

      it 'inserts an item with long notes' do
        notes = 'Quis cupidatat laborum commodo deserunt tempor ad proident'
        db.insert_item(start_time, tag, notes)
        expect(last_item[4]).to eq('Quis cupidatat laborum commodo deserunt tempor ad proident')
      end
    end
  end

  # Test Fetching Last ID
  describe '#fetch_last_id' do
    it 'returns the ID of the last inserted item' do
      db.insert_item(1_700_000_000, 'work', '')
      expect(db.fetch_last_id).to eq(1)
    end

    it 'returns nil if no items exist' do
      expect(db.fetch_last_id).to be_nil
    end
  end

  describe '#last_item' do
    let(:test_tag) { 'Test Task' }

    it 'returns the last item from the items table' do
      start_time = Time.now.utc.to_i
      tag = 'Test Task'
      notes = ''
      db.insert_item(start_time, tag, notes)
      last_item = db.last_item

      # Check if the item is correct (one expectation per block)
      expect(last_item[1]).to eq(start_time)
    end

    it 'returns the correct start time and tag for the last item' do
      start_time = Time.now.utc.to_i
      notes = ''
      db.insert_item(start_time, test_tag, notes)
      last_item = db.last_item

      expect(last_item[3]).to eq(test_tag)
    end

    it 'returns nil if no items exist' do
      # Call last_item without inserting any items
      last_item = db.last_item

      # Check if it returns nil
      expect(last_item).to be_nil
    end
  end

  describe '#item_status' do
    let(:test_tag) { 'Test Task' }

    context 'when no items exist' do
      it 'returns :no_items' do
        expect(db.item_status).to eq(:no_items)
      end
    end

    context 'when the last item is in progress' do
      it 'returns :in_progress' do
        start_time = Time.now.utc.to_i
        notes = ''
        db.insert_item(start_time, test_tag, notes)

        expect(db.item_status).to eq(:in_progress)
      end
    end

    context 'when the last item is complete' do
      it 'returns :complete' do
        start_time = Time.now.utc.to_i
        notes = ''
        db.insert_item(start_time, test_tag, notes)
        last_id = db.fetch_last_id
        db.update_item(last_id, 'end', Time.now.utc.to_i)

        expect(db.item_status).to eq(:complete)
      end
    end
  end

  describe '#execute_sql' do
    it 'executes a SQL query and returns the result' do
      result = db.execute_sql('SELECT * FROM items')
      expect(result).to be_a(Array)
    end

    it 'handles errors during query execution' do
      # Execute an invalid query
      result = db.execute_sql('INVALID SQL')

      # Check if it returns an empty array and prints an error message
      expect(result).to be_empty
    end
  end

  # Test Database Closing
  describe '#close' do
    it 'closes the database connection' do
      db.close
      expect(db.instance_variable_get(:@db).closed?).to be true
    end
  end

  # Test Update Time Columns
  describe '#update_time_columns' do
    let(:start_time) { 1_700_000_000 }
    let(:tag) { 'work' }

    before do
      db.insert_item(start_time, tag, '')
    end

    context 'when end_time is NULL' do
      it 'updates updated_at and created_at to NULL' do
        db.execute_sql('INSERT INTO items (start, end, tag) VALUES (?, ?, ?)', [100, nil, 'test'])
        db.update_time_columns
        result = db.execute_sql('SELECT updated_at, created_at FROM items WHERE id = ?', [2])
        expect(result[0][0]).to be_nil
        expect(result[0][1]).to be_nil
      end
    end

    context 'when end_time is not NULL' do
      it 'updates updated_at and created_at to end_time' do
        db.execute_sql('INSERT INTO items (start, end, tag) VALUES (?, ?, ?)', [100, 200, 'test'])
        db.update_time_columns
        result = db.execute_sql('SELECT updated_at, created_at FROM items WHERE id = ?', [2])
        expect(result[0][0]).to eq(200)
        expect(result[0][1]).to eq(200)
      end
    end

    it 'does not update updated_at column for items where it is not null' do
      db.insert_item(start_time, tag, '', nil, start_time, start_time)
      db.update_time_columns
      last_item = db.last_item
      expect(last_item[6]).to eq(start_time) # updated_at
    end

    it 'does not update created_at column for items where it is not null' do
      db.insert_item(start_time, tag, '', nil, start_time, start_time)
      db.update_time_columns
      last_item = db.last_item
      expect(last_item[7]).to eq(start_time) # created_at
    end
  end

  describe '#update_item' do
    before do
      db.execute_sql('INSERT INTO items (start, end, tag) VALUES (?, ?, ?)', [100, 200, 'test'])
    end

    context 'when value is NULL' do
      it 'updates the field to NULL and updated_at to the current time' do
        current_time = Time.now.utc.to_i
        db.update_item(1, 'end', nil)
        result = db.execute_sql('SELECT end, updated_at FROM items WHERE id = ?', [1])
        expect(result[0][0]).to be_nil
        expect(result[0][1]).to be_within(1).of(current_time)
      end
    end

    context 'when value is not NULL' do
      it 'updates the field to the new value and updated_at to the current time' do
        current_time = Time.now.utc.to_i
        db.update_item(1, 'tag', 'new_tag')
        result = db.execute_sql('SELECT tag, updated_at FROM items WHERE id = ?', [1])
        expect(result[0][0]).to eq('new_tag')
        expect(result[0][1]).to be_within(1).of(current_time)
      end
    end
  end
end
