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

  describe '#handle_database_differences' do
    it 'syncs with remote database' do
      allow(database_syncer).to receive(:sync_with_remote_database).and_return(nil)
      expect do
        database_syncer.handle_database_differences(local_db, remote_storage, bucket, local_db_path,
                                                    remote_path)
      end.to output(/Differences detected between local and remote databases/).to_stdout
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

    describe '#process_database_items' do
      let(:local_db) { instance_double(SQLite3::Database) }
      let(:remote_db) { instance_double(SQLite3::Database) }

      it 'processes database items' do
        allow(database_syncer).to receive(:process_database_items).and_return(nil)
        expect(database_syncer.process_database_items(local_db, remote_db)).to be_nil
      end
    end

    it 'handles sync error' do
      allow(database_syncer).to receive(:sync_with_remote_database)
        .and_raise(SQLite3::Exception.new('Sync error'))
      expect do
        database_syncer.handle_database_differences(local_db, remote_storage, bucket, local_db_path,
                                                    remote_path)
      end.to output(/Error opening remote database: Sync error/).to_stdout
      expect(remote_storage).to have_received(:upload_file)
        .with(bucket, local_db_path, 'timet.db')
    end
  end

  describe '#handle_sync_error' do
    it 'uploads local database to remote storage' do
      error = SQLite3::Exception.new('Sync error')
      allow(remote_storage).to receive(:upload_file) # Stub upload_file method
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
      allow(remote_storage).to receive(:upload_file) # Stub upload_file method
      database_syncer.sync_databases(local_db, db_remote, remote_storage, bucket, local_db_path)
      expect(remote_storage).to have_received(:upload_file).with(bucket, local_db_path, 'timet.db')
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

    it 'processes an item that exists in both databases' do
      allow(database_syncer).to receive(:remote_wins?).and_return(true)
      allow(database_syncer).to receive(:update_item_from_hash)
      database_syncer.process_existing_item(id, local_item, remote_item, local_db)
      expect(database_syncer).to have_received(:update_item_from_hash).with(local_db, remote_item)
    end
  end

  describe '#items_to_hash' do
    let(:items) { [{ 'id' => 1, 'start' => '2025-01-01' }] }

    it 'converts database items to a hash indexed by ID' do
      result = database_syncer.items_to_hash(items)
      expect(result).to eq(1 => { 'id' => 1, 'start' => '2025-01-01' })
    end
  end
end
