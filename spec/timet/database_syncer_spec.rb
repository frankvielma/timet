# frozen_string_literal: true

require 'spec_helper'
require 'timet/database_syncer'
require 'sqlite3'
require 'timet/s3_supabase'

RSpec.describe Timet::DatabaseSyncer do
  let(:database_syncer) { Class.new { include Timet::DatabaseSyncer }.new }
  let(:local_db) { instance_spy(SQLite3::Database) }
  let(:remote_storage) { instance_spy(Timet::S3Supabase) }
  let(:bucket) { 'test_bucket' }
  let(:local_db_path) { 'path/to/local/db' }
  let(:remote_path) { 'path/to/remote/db' }
  let(:local_items) { [{ 'id' => 1, 'updated_at' => '2024-01-01' }] }
  let(:remote_items) { [{ 'id' => 2, 'updated_at' => '2024-01-02' }] }

  describe '#handle_database_differences' do
    it 'syncs with remote database' do
      allow(database_syncer).to receive(:sync_with_remote_database).and_return(nil)
      expect do
        database_syncer.handle_database_differences(local_db, remote_storage, bucket, local_db_path,
                                                    remote_path)
      end.to output(/Differences detected between local and remote databases/).to_stdout
    end

    it 'handles sync error' do
      error = SQLite3::Exception.new('Sync error')
      allow(database_syncer).to receive(:sync_with_remote_database).and_raise(error)
      expect do
        database_syncer.handle_database_differences(local_db, remote_storage, bucket, local_db_path,
                                                    remote_path)
      end.to output(/Error opening remote database: Sync error/).to_stdout
      expect(remote_storage).to have_received(:upload_file).with(bucket, local_db_path, 'timet.db')
    end
  end

  describe '#insert_item_from_hash' do
    let(:dummy) do
      Class.new do
        include Timet::DatabaseSyncer
      end.new
    end
    let(:db) { double('SQLite3::Database') }
    let(:item) do
      {
        'id' => 1,
        'start' => '2025-02-08 10:00:00',
        'end' => '2025-02-08 11:00:00',
        'tag' => 'test',
        'notes' => 'testing insert',
        'pomodoro' => 0,
        'updated_at' => '2025-02-08 09:00:00',
        'created_at' => '2025-02-08 08:00:00',
        'deleted' => 0
      }
    end

    it 'executes the correct SQL query with proper values' do
      expected_fields = "id, #{Timet::DatabaseSyncer::ITEM_FIELDS.join(', ')}"
      expected_placeholders = Array.new(Timet::DatabaseSyncer::ITEM_FIELDS.length + 1, '?').join(', ')
      expected_sql = "INSERT INTO items (#{expected_fields}) VALUES (#{expected_placeholders})"
      expected_values = dummy.get_item_values(item, include_id_at_start: true)

      expect(db).to receive(:execute_sql).with(expected_sql, expected_values)

      dummy.insert_item_from_hash(db, item)
    end
  end

  describe '#handle_sync_error' do
    it 'uploads local database to remote storage' do
      error = SQLite3::Exception.new('Sync error')
      allow(remote_storage).to receive(:upload_file)
      database_syncer.handle_sync_error(error, remote_storage, bucket, local_db_path)
      expect(remote_storage).to have_received(:upload_file).with(bucket, local_db_path, 'timet.db')
    end
  end

  describe '#sync_with_remote_database' do
    let(:db_remote) { instance_spy(SQLite3::Database) }

    before do
      allow(database_syncer).to receive(:open_remote_database).and_return(db_remote)
      allow(database_syncer).to receive(:sync_databases)
      allow(local_db).to receive(:instance_variable_get).with(:@db).and_return(local_db)
    end

    it 'sets results_as_hash for both databases' do
      database_syncer.sync_with_remote_database(local_db, remote_path, remote_storage, bucket, local_db_path)
      expect(db_remote).to have_received(:results_as_hash=).with(true)
      expect(local_db).to have_received(:results_as_hash=).with(true)
    end
  end

  describe '#open_remote_database' do
    it 'opens remote database' do
      db_remote = instance_double(SQLite3::Database)
      allow(SQLite3::Database).to receive(:new).with(remote_path).and_return(db_remote)
      expect(database_syncer.open_remote_database(remote_path)).to eq(db_remote)
    end

    it 'raises error if remote database cannot be opened' do
      allow(SQLite3::Database).to receive(:new)
        .with(remote_path)
        .and_raise(SQLite3::Exception.new('Failed to initialize remote database'))
      expect do
        database_syncer.open_remote_database(remote_path)
      end.to raise_error(SQLite3::Exception, 'Failed to initialize remote database')
    end
  end

  describe '#sync_databases' do
    let(:db_remote) { instance_double(SQLite3::Database) }

    it 'processes database items and uploads local database' do
      allow(database_syncer).to receive(:process_database_items)
      allow(remote_storage).to receive(:upload_file)
      database_syncer.sync_databases(local_db, db_remote, remote_storage, bucket, local_db_path)
      expect(remote_storage).to have_received(:upload_file).with(bucket, local_db_path, 'timet.db')
    end
  end

  describe '#process_database_items' do
    let(:local_db) { instance_double(Timet::Database) }
    let(:remote_db) { instance_double(SQLite3::Database) }

    before do
      allow(local_db).to receive(:execute_sql).and_return(local_items)
      allow(remote_db).to receive(:execute).and_return(remote_items)
      allow(database_syncer).to receive(:sync_items_by_id)
    end

    it 'fetches items from both databases' do
      database_syncer.process_database_items(local_db, remote_db)
      expect(local_db).to have_received(:execute_sql).with('SELECT * FROM items ORDER BY updated_at DESC')
      expect(remote_db).to have_received(:execute).with('SELECT * FROM items ORDER BY updated_at DESC')
    end

    it 'calls sync_items_by_id with the correct arguments' do
      local_items_hash = { 1 => { 'id' => 1, 'updated_at' => '2024-01-01' } }
      remote_items_hash = { 2 => { 'id' => 2, 'updated_at' => '2024-01-02' } }
      database_syncer.process_database_items(local_db, remote_db)
      expect(database_syncer).to have_received(:sync_items_by_id).with(local_db, local_items_hash, remote_items_hash)
    end
  end

  describe '#get_item_values' do
    let(:item) do
      { 'id' => 1, 'start' => 'value1', 'end' => 'value2', 'tag' => 'value3', 'notes' => 'value4', 'pomodoro' => 'value5',
        'updated_at' => 'value6', 'created_at' => 'value7', 'deleted' => 'value8' }
    end

    context 'when include_id_at_start is false' do
      it 'returns values without the item ID at the start' do
        expect(database_syncer.get_item_values(item,
                                               include_id_at_start: false)).to eq(%w[value1 value2 value3 value4 value5
                                                                                     value6 value7 value8])
      end
    end

    context 'when include_id_at_start is true' do
      it 'returns values with the item ID at the start' do
        expect(database_syncer.get_item_values(item,
                                               include_id_at_start: true)).to eq([1, 'value1', 'value2', 'value3',
                                                                                  'value4', 'value5', 'value6', 'value7', 'value8'])
      end
    end

    context 'when item has missing fields' do
      let(:item) do
        { 'id' => 1, 'start' => 'value1', 'end' => 'value2', 'tag' => 'value3', 'notes' => 'value4', 'pomodoro' => 'value5',
          'updated_at' => 'value6', 'created_at' => 'value7', 'deleted' => 'value8' }
      end

      it 'returns values with nil for missing fields' do
        expect(database_syncer.get_item_values(item,
                                               include_id_at_start: false)).to eq(%w[value1 value2 value3 value4 value5
                                                                                     value6 value7 value8])
      end
    end

    context 'when item has nil values for fields' do
      let(:item) do
        { 'id' => 1, 'start' => nil, 'end' => 'value2', 'tag' => 'value3', 'notes' => 'value4', 'pomodoro' => 'value5',
          'updated_at' => 'value6', 'created_at' => 'value7', 'deleted' => 'value8' }
      end

      it 'returns values with nil for nil fields' do
        expect(database_syncer.get_item_values(item,
                                               include_id_at_start: false)).to eq([nil, 'value2', 'value3', 'value4',
                                                                                   'value5', 'value6', 'value7', 'value8'])
      end
    end
  end

  describe '#sync_items_by_id' do
    let(:local_items_by_id) { { 1 => { 'id' => 1, 'updated_at' => '2025-01-01' } } }
    let(:remote_items_by_id) { { 2 => { 'id' => 2, 'updated_at' => '2025-01-02' } } }

    it 'syncs items between local and remote databases' do
      allow(database_syncer).to receive(:insert_item_from_hash)
      allow(database_syncer).to receive(:process_existing_item)
      database_syncer.sync_items_by_id(local_db, local_items_by_id, remote_items_by_id)
      expect(database_syncer).to have_received(:insert_item_from_hash).with(local_db, remote_items_by_id[2])
    end
  end

  describe '#process_existing_item' do
    let(:id) { 1 }
    let(:local_item) { { 'id' => 1, 'updated_at' => '2025-01-01' } }
    let(:remote_item) { { 'id' => 1, 'updated_at' => '2025-01-02' } }

    context 'when remote time is newer' do
      it 'updates from remote' do
        allow(database_syncer).to receive(:remote_wins?).and_return(true)
        allow(database_syncer).to receive(:update_item_from_hash)
        database_syncer.process_existing_item(id, local_item, remote_item, local_db)
        expect(database_syncer).to have_received(:update_item_from_hash).with(local_db, remote_item)
      end
    end

    context 'when local time is newer' do
      it 'returns :remote_update and prints local status' do
        local_time = Time.now + 3600
        remote_time = Time.now
        local_item = { 'updated_at' => local_time.to_i.to_s }
        remote_item = { 'updated_at' => remote_time.to_i.to_s }

        result = database_syncer.process_existing_item(
          id,
          local_item,
          remote_item,
          local_db
        )
        expect(result).to eq(:remote_update)
      end
    end
  end

  describe '#process_existing_item' do
    let(:id) { 1 }
    let(:local_item) { { 'id' => 1, 'updated_at' => '2025-01-01' } }
    let(:remote_item) { { 'id' => 1, 'updated_at' => '2025-01-02' } }

    context 'when remote time is newer' do
      it 'updates from remote' do
        allow(database_syncer).to receive(:remote_wins?).and_return(true)
        allow(database_syncer).to receive(:update_item_from_hash)
        database_syncer.process_existing_item(id, local_item, remote_item, local_db)
        expect(database_syncer).to have_received(:update_item_from_hash).with(local_db, remote_item)
      end
    end

    context 'when local time is newer' do
      it 'returns :remote_update and prints local status' do
        local_time = Time.now + 3600
        remote_time = Time.now
        local_item = { 'updated_at' => local_time.to_i.to_s }
        remote_item = { 'updated_at' => remote_time.to_i.to_s }

        result = database_syncer.process_existing_item(
          id,
          local_item,
          remote_item,
          local_db
        )
        expect(result).to eq(:remote_update)
      end
    end
  end

  describe '#items_to_hash' do
    let(:items) { [{ 'id' => 1, 'start' => '2025-01-01' }] }

    it 'converts database items to a hash indexed by ID' do
      result = database_syncer.items_to_hash(items)
      expect(result).to eq(1 => { 'id' => 1, 'start' => '2025-01-01' })
    end
  end

  describe '#remote_wins?' do
    it 'returns true if remote_time is greater than local_time and remote_item is deleted' do
      remote_item = { 'deleted' => '1' }
      remote_time = Time.now + 3600
      local_time = Time.now
      expect(database_syncer.remote_wins?(remote_item, remote_time, local_time)).to be true
    end

    it 'returns true if remote_time is greater than local_time and remote_item is not deleted' do
      remote_item = { 'deleted' => '0' }
      remote_time = Time.now + 3600
      local_time = Time.now
      expect(database_syncer.remote_wins?(remote_item, remote_time, local_time)).to be true
    end

    it 'returns false if remote_time is less than or equal to local_time' do
      remote_item = { 'deleted' => '1' }
      remote_time = Time.now
      local_time = Time.now + 3600
      expect(database_syncer.remote_wins?(remote_item, remote_time, local_time)).to be false
    end
  end

  describe '#update_item_from_hash' do
    let(:db) { double('SQLite3::Database') }
    let(:item) do
      {
        'id' => 1,
        'start' => '2025-02-08 10:00:00',
        'end' => '2025-02-08 11:00:00',
        'tag' => 'test',
        'notes' => 'testing update',
        'pomodoro' => 0,
        'updated_at' => '2025-02-08 09:00:00',
        'created_at' => '2025-02-08 08:00:00',
        'deleted' => 0
      }
    end
    let(:expected_fields) { "#{Timet::DatabaseSyncer::ITEM_FIELDS.join(' = ?, ')} = ?" }

    it 'executes the correct SQL query with proper values' do
      expected_sql = "UPDATE items SET #{expected_fields} WHERE id = ?"
      expected_values = database_syncer.get_item_values(item)

      allow(db).to receive(:execute_sql).with(expected_sql, expected_values)

      database_syncer.update_item_from_hash(db, item)
    end

    it 'updates the item with new values' do
      new_item = {
        'id' => 1,
        'start' => '2025-02-08 12:00:00',
        'end' => '2025-02-08 13:00:00',
        'tag' => 'updated',
        'notes' => 'updated notes',
        'pomodoro' => 1,
        'updated_at' => '2025-02-08 11:00:00',
        'created_at' => '2025-02-08 10:00:00',
        'deleted' => 0
      }

      expected_sql = "UPDATE items SET #{expected_fields} WHERE id = ?"
      expected_values = database_syncer.get_item_values(new_item)

      allow(db).to receive(:execute_sql).with(expected_sql, expected_values)

      database_syncer.update_item_from_hash(db, new_item)
    end

    it 'handles missing fields gracefully' do
      incomplete_item = {
        'id' => 1,
        'start' => '2025-02-08 12:00:00',
        'end' => '2025-02-08 13:00:00',
        'tag' => 'updated',
        'notes' => 'updated notes',
        'pomodoro' => 1,
        'updated_at' => '2025-02-08 11:00:00',
        'created_at' => '2025-02-08 10:00:00'
      }

      expected_sql = "UPDATE items SET #{expected_fields} WHERE id = ?"
      expected_values = database_syncer.get_item_values(incomplete_item)

      allow(db).to receive(:execute_sql).with(expected_sql, expected_values)
      expect(db).to receive(:execute_sql).with(expected_sql, expected_values)

      database_syncer.update_item_from_hash(db, incomplete_item)
    end
  end
end
