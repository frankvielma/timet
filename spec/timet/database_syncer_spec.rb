# frozen_string_literal: true

require 'spec_helper'
require 'timet/database_syncer'
require 'sqlite3'
require 'timet/s3_supabase'

RSpec.describe Timet::DatabaseSyncer do
  let(:database_syncer) { Class.new { include Timet::DatabaseSyncer }.new }
  let(:local_db) { instance_spy(SQLite3::Database) }
  let(:remote_storage) { instance_spy(Timet::S3Supabase) }
  let(:db_remote) { instance_spy(SQLite3::Database) }
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
    end

    it 'uploads the local database when a sync error occurs' do
      error = SQLite3::Exception.new('Sync error')
      allow(database_syncer).to receive(:sync_with_remote_database).and_raise(error)
      database_syncer.handle_database_differences(local_db, remote_storage, bucket, local_db_path,
                                                  remote_path)
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

      allow(db).to receive(:execute_sql)

      dummy.insert_item_from_hash(db, item)
      expect(db).to have_received(:execute_sql).with(expected_sql, expected_values)
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
    before do
      allow(database_syncer).to receive(:open_remote_database).and_return(db_remote)
      allow(database_syncer).to receive(:sync_databases)
      allow(local_db).to receive(:instance_variable_get).with(:@db).and_return(local_db)
    end

    it 'sets results_as_hash for both databases' do
      database_syncer.sync_with_remote_database(local_db, remote_path, remote_storage, bucket, local_db_path)
      expect(db_remote).to have_received(:results_as_hash=).with(true)
    end

    it 'sets results_as_hash for local database' do
      database_syncer.sync_with_remote_database(local_db, remote_path, remote_storage, bucket, local_db_path)
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
    subject(:sync_databases) do
      database_syncer.sync_databases(local_db, db_remote, remote_storage, bucket, local_db_path)
    end

    let(:local_db) { instance_double(Timet::Database) }
    let(:local_items) { [{ 'id' => 1, 'updated_at' => '1706745600' }] }
    let(:remote_items) { [{ 'id' => 2, 'updated_at' => '1706745601' }] }

    before do
      allow(local_db).to receive(:execute_sql).and_return(local_items)
      allow(db_remote).to receive(:execute).and_return(remote_items)
      allow(database_syncer).to receive(:items_to_hash).and_call_original
      allow(database_syncer).to receive(:sync_single_item_and_flag).and_return(true)
      allow(remote_storage).to receive(:upload_file)
    end

    it 'fetches local items from database' do
      sync_databases
      expect(local_db).to have_received(:execute_sql).with('SELECT * FROM items ORDER BY updated_at DESC')
    end

    it 'fetches remote items from database' do
      sync_databases
      expect(db_remote).to have_received(:execute).with('SELECT * FROM items ORDER BY updated_at DESC')
    end
  end

  describe '#process_bidirectional_sync' do
    let(:local_items_by_id) { { 1 => { 'id' => 1, 'updated_at' => '1706745600' } } }
    let(:remote_items_by_id) { { 2 => { 'id' => 2, 'updated_at' => '1706745601' } } }

    it 'processes all item IDs from both databases' do
      allow(database_syncer).to receive(:sync_single_item_and_flag).and_return(true)
      database_syncer.process_bidirectional_sync(local_db, local_items_by_id, remote_items_by_id)
      expect(database_syncer).to have_received(:sync_single_item_and_flag).twice
    end
  end

  describe '#sync_single_item_and_flag' do
    let(:local_item) { { 'id' => 1, 'updated_at' => '1706745600' } }
    let(:remote_item) { { 'id' => 1, 'updated_at' => '1706745601' } }

    it 'returns true for local-only items' do
      allow(database_syncer).to receive(:puts)
      result = database_syncer.sync_single_item_and_flag(local_db, 1, local_item, nil)
      expect(result).to be true
    end

    it 'returns false and inserts remote-only items' do
      allow(database_syncer).to receive(:puts)
      allow(database_syncer).to receive(:insert_item_from_hash)
      result = database_syncer.sync_single_item_and_flag(local_db, 2, nil, remote_item)
      expect(result).to be false
      expect(database_syncer).to have_received(:insert_item_from_hash).with(local_db, remote_item)
    end
  end

  describe '#get_item_values' do
    let(:item) do
      { 'id' => 1, 'start' => 'value1', 'end' => 'value2', 'tag' => 'value3', 'notes' => 'value4',
        'pomodoro' => 'value5', 'updated_at' => 'value6', 'created_at' => 'value7', 'deleted' => 'value8' }
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
        expect(database_syncer.get_item_values(item, include_id_at_start: true)).to eq(
          [1, 'value1', 'value2', 'value3', 'value4', 'value5', 'value6', 'value7', 'value8']
        )
      end
    end

    context 'when item has missing fields' do
      let(:item) do
        { 'id' => 1, 'start' => 'value1', 'end' => 'value2', 'tag' => 'value3', 'notes' => 'value4',
          'pomodoro' => 'value5', 'updated_at' => 'value6', 'created_at' => 'value7', 'deleted' => 'value8' }
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
                                               include_id_at_start: false)).to eq(
                                                 [nil, 'value2', 'value3', 'value4',
                                                  'value5', 'value6', 'value7', 'value8']
                                               )
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
    let(:remote_time_future) { Time.now + 3600 }
    let(:remote_time_past) { Time.now }
    let(:local_time_past) { Time.now }
    let(:local_time_future) { Time.now + 3600 }
    let(:deleted_remote_item) { { 'deleted' => '1' } }
    let(:not_deleted_remote_item) { { 'deleted' => '0' } }

    it 'returns true if remote_time is greater than local_time and remote_item is deleted' do
      expect(database_syncer.remote_wins?(deleted_remote_item, remote_time_future, local_time_past)).to be true
    end

    it 'returns true if remote_time is greater than local_time and remote_item is not deleted' do
      expect(database_syncer.remote_wins?(not_deleted_remote_item, remote_time_future, local_time_past)).to be true
    end

    it 'returns false if remote_time is less than or equal to local_time' do
      expect(database_syncer.remote_wins?(deleted_remote_item, remote_time_past, local_time_future)).to be false
    end
  end

  describe '#merge_and_track_changes?' do
    let(:local_db) { instance_double(Timet::Database) }

    context 'when remote timestamp is newer' do
      let(:local_item) { { 'id' => 1, 'updated_at' => '1706745600', 'tag' => 'old_tag' } }
      let(:remote_item) { { 'id' => 1, 'updated_at' => '1706745700', 'tag' => 'new_tag' } }

      it 'updates local database with remote data' do
        allow(database_syncer).to receive(:update_item_from_hash)
        allow(database_syncer).to receive(:extract_timestamp).and_call_original
        allow(database_syncer).to receive(:puts)

        result = database_syncer.merge_and_track_changes?(local_db, 1, local_item, remote_item)

        expect(database_syncer).to have_received(:update_item_from_hash).with(local_db, remote_item)
        expect(result).to be true
      end

      it 'prints message about remote being newer' do
        allow(database_syncer).to receive(:update_item_from_hash)
        allow(database_syncer).to receive(:extract_timestamp).and_call_original

        expect do
          database_syncer.merge_and_track_changes?(local_db, 1, local_item, remote_item)
        end.to output(/Remote item 1 is newer - updating local/).to_stdout
      end
    end

    context 'when local timestamp is newer' do
      let(:local_item) { { 'id' => 1, 'updated_at' => '1706745700', 'tag' => 'new_tag' } }
      let(:remote_item) { { 'id' => 1, 'updated_at' => '1706745600', 'tag' => 'old_tag' } }

      it 'marks for upload without updating local' do
        allow(database_syncer).to receive(:update_item_from_hash)
        allow(database_syncer).to receive(:extract_timestamp).and_call_original
        allow(database_syncer).to receive(:puts)

        result = database_syncer.merge_and_track_changes?(local_db, 1, local_item, remote_item)

        expect(database_syncer).not_to have_received(:update_item_from_hash)
        expect(result).to be true
      end

      it 'prints message about local being newer' do
        allow(database_syncer).to receive(:update_item_from_hash)
        allow(database_syncer).to receive(:extract_timestamp).and_call_original

        expect do
          database_syncer.merge_and_track_changes?(local_db, 1, local_item, remote_item)
        end.to output(/Local item 1 is newer - will be uploaded/).to_stdout
      end
    end

    context 'when timestamps are equal' do
      let(:local_item) { { 'id' => 1, 'updated_at' => '1706745600', 'tag' => 'tag' } }
      let(:remote_item) { { 'id' => 1, 'updated_at' => '1706745600', 'tag' => 'tag' } }

      it 'keeps local and marks for upload' do
        allow(database_syncer).to receive(:update_item_from_hash)
        allow(database_syncer).to receive(:extract_timestamp).and_call_original
        allow(database_syncer).to receive(:puts)

        result = database_syncer.merge_and_track_changes?(local_db, 1, local_item, remote_item)

        expect(database_syncer).not_to have_received(:update_item_from_hash)
        expect(result).to be true
      end
    end
  end

  describe 'Bidirectional sync integration' do
    let(:temp_dir) { Dir.mktmpdir('timet_test') }

    after do
      FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
    end

    def create_test_db(path, items)
      db = SQLite3::Database.new(path)
      db.execute('CREATE TABLE IF NOT EXISTS items (
        id INTEGER PRIMARY KEY,
        start TEXT,
        end TEXT,
        tag TEXT,
        notes TEXT,
        pomodoro INTEGER,
        updated_at TEXT,
        created_at TEXT,
        deleted INTEGER DEFAULT 0
      )')
      items.each do |item|
        db.execute(
          'INSERT INTO items (id, start, end, tag, notes, pomodoro, updated_at, created_at, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [item[:id], item[:start], item[:end], item[:tag], item[:notes], item[:pomodoro], item[:updated_at],
           item[:created_at], item[:deleted] || 0]
        )
      end
      db
    end

    context 'when remote has item that local does not have' do
      it 'adds remote item to local database' do
        local_path = File.join(temp_dir, 'local.db')
        remote_path = File.join(temp_dir, 'remote.db')

        create_test_db(local_path, [
                         { id: 1, start: '2025-01-01 09:00', end: '2025-01-01 10:00', tag: 'work', notes: 'local task', pomodoro: 0, updated_at: '1706745600', created_at: '1706745600' }
                       ])

        create_test_db(remote_path, [
                         { id: 2, start: '2025-01-01 11:00', end: '2025-01-01 12:00', tag: 'meeting', notes: 'remote task', pomodoro: 0, updated_at: '1706745601', created_at: '1706745601' }
                       ])

        local_db = Timet::Database.new(local_path)
        remote_db = SQLite3::Database.new(remote_path)
        remote_db.results_as_hash = true
        local_db.instance_variable_get(:@db).results_as_hash = true

        remote_storage = instance_spy(Timet::S3Supabase)
        allow(remote_storage).to receive(:upload_file)

        database_syncer.sync_databases(local_db, remote_db, remote_storage, 'test-bucket', local_path)

        items = local_db.execute_sql('SELECT * FROM items ORDER BY id')
        expect(items.length).to eq(2)
        expect(items.map { |i| i['id'] }).to include(2)
      end
    end

    context 'when local has item that remote does not have' do
      it 'marks local-only item for upload' do
        local_path = File.join(temp_dir, 'local.db')
        remote_path = File.join(temp_dir, 'remote.db')

        create_test_db(local_path, [
                         { id: 1, start: '2025-01-01 09:00', end: '2025-01-01 10:00', tag: 'work', notes: 'local task', pomodoro: 0, updated_at: '1706745600', created_at: '1706745600' }
                       ])

        create_test_db(remote_path, [])

        local_db = Timet::Database.new(local_path)
        remote_db = SQLite3::Database.new(remote_path)
        remote_db.results_as_hash = true
        local_db.instance_variable_get(:@db).results_as_hash = true

        remote_storage = instance_spy(Timet::S3Supabase)
        allow(remote_storage).to receive(:upload_file)

        database_syncer.sync_databases(local_db, remote_db, remote_storage, 'test-bucket', local_path)

        expect(remote_storage).to have_received(:upload_file)
      end
    end

    context 'when same item exists in both with newer remote timestamp' do
      it 'updates local with remote data' do
        local_path = File.join(temp_dir, 'local.db')
        remote_path = File.join(temp_dir, 'remote.db')

        create_test_db(local_path, [
                         { id: 1, start: '2025-01-01 09:00', end: '2025-01-01 10:00', tag: 'old_tag', notes: 'local notes', pomodoro: 0, updated_at: '1706745600', created_at: '1706745600' }
                       ])

        create_test_db(remote_path, [
                         { id: 1, start: '2025-01-01 09:00', end: '2025-01-01 11:00', tag: 'new_tag', notes: 'remote notes', pomodoro: 0, updated_at: '1706745700', created_at: '1706745600' }
                       ])

        local_db = Timet::Database.new(local_path)
        remote_db = SQLite3::Database.new(remote_path)
        remote_db.results_as_hash = true
        local_db.instance_variable_get(:@db).results_as_hash = true

        remote_storage = instance_spy(Timet::S3Supabase)
        allow(remote_storage).to receive(:upload_file)

        database_syncer.sync_databases(local_db, remote_db, remote_storage, 'test-bucket', local_path)

        items = local_db.execute_sql('SELECT * FROM items WHERE id = 1')
        expect(items.first['tag']).to eq('new_tag')
        expect(items.first['end']).to eq('2025-01-01 11:00')
      end
    end

    context 'when same item exists in both with newer local timestamp' do
      it 'marks for upload without changing local' do
        local_path = File.join(temp_dir, 'local.db')
        remote_path = File.join(temp_dir, 'remote.db')

        create_test_db(local_path, [
                         { id: 1, start: '2025-01-01 09:00', end: '2025-01-01 11:00', tag: 'new_tag', notes: 'local notes', pomodoro: 0, updated_at: '1706745700', created_at: '1706745600' }
                       ])

        create_test_db(remote_path, [
                         { id: 1, start: '2025-01-01 09:00', end: '2025-01-01 10:00', tag: 'old_tag', notes: 'remote notes', pomodoro: 0, updated_at: '1706745600', created_at: '1706745600' }
                       ])

        local_db = Timet::Database.new(local_path)
        remote_db = SQLite3::Database.new(remote_path)
        remote_db.results_as_hash = true
        local_db.instance_variable_get(:@db).results_as_hash = true

        remote_storage = instance_spy(Timet::S3Supabase)
        allow(remote_storage).to receive(:upload_file)

        database_syncer.sync_databases(local_db, remote_db, remote_storage, 'test-bucket', local_path)

        items = local_db.execute_sql('SELECT * FROM items WHERE id = 1')
        expect(items.first['tag']).to eq('new_tag')
        expect(remote_storage).to have_received(:upload_file)
      end
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

    let(:incomplete_item) do
      {
        'id' => 1,
        'start' => '2025-02-08 12:00:00',
        'end' => '2025-02-08 13:00:00',
        'tag' => 'updated',
        'notes' => 'updated notes',
        'pomodoro' => 1,
        'updated_at' => '2025-02-08 11:00:00',
        'created_at' => '2025-02-08 10:00:00'
      }
    end

    let(:new_item) do
      {
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
    end

    it 'executes the correct SQL query with proper values' do
      expected_sql = "UPDATE items SET #{expected_fields} WHERE id = ?"
      expected_values = database_syncer.get_update_values(item) + [item['id']]

      allow(db).to receive(:execute_sql)
      database_syncer.update_item_from_hash(db, item)
      expect(db).to have_received(:execute_sql).with(expected_sql, expected_values)
    end

    it 'updates the item with new values' do
      expected_sql = "UPDATE items SET #{expected_fields} WHERE id = ?"
      expected_values = database_syncer.get_update_values(new_item) + [new_item['id']]

      allow(db).to receive(:execute_sql).with(expected_sql, expected_values)

      database_syncer.update_item_from_hash(db, new_item)
      expect(db).to have_received(:execute_sql).with(expected_sql, expected_values)
    end

    it 'handles missing fields gracefully' do
      expected_sql = "UPDATE items SET #{expected_fields} WHERE id = ?"
      expected_values = database_syncer.get_update_values(incomplete_item) + [incomplete_item['id']]
      allow(db).to receive(:execute_sql)
      database_syncer.update_item_from_hash(db, incomplete_item)
      expect(db).to have_received(:execute_sql).with(expected_sql, expected_values)
    end
  end
end
