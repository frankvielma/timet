# frozen_string_literal: true

require 'spec_helper'
require 'timet/database_syncer'
require 'sqlite3'
require 'timet/s3_supabase'

RSpec.describe Timet::DatabaseSyncer do
  let(:database_syncer) { Class.new { include Timet::DatabaseSyncer }.new }
  let(:local_db) { instance_double(SQLite3::Database) }
  let(:remote_storage) { instance_double(Timet::S3Supabase) }
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

    it 'handles sync error' do
      allow(database_syncer).to receive(:sync_with_remote_database)
        .and_raise(SQLite3::Exception.new('Sync error'))
      expect(remote_storage).to receive(:upload_file)
        .with(bucket, local_db_path, 'timet.db')
      expect do
        database_syncer.handle_database_differences(local_db, remote_storage, bucket, local_db_path,
                                                    remote_path)
      end.to output(/Error opening remote database: Sync error/).to_stdout
    end
  end

  describe '#handle_sync_error' do
    it 'uploads local database to remote storage' do
      error = SQLite3::Exception.new('Sync error')
      expect(remote_storage).to receive(:upload_file).with(bucket, local_db_path, 'timet.db')
      database_syncer.handle_sync_error(error, remote_storage, bucket, local_db_path)
    end
  end

  describe '#sync_with_remote_database' do
    let(:db_remote) { instance_double(SQLite3::Database) }

    before do
      allow(database_syncer).to receive(:open_remote_database).and_return(db_remote)
      allow(database_syncer).to receive(:sync_databases)
      allow(local_db).to receive(:instance_variable_get).with(:@db).and_return(local_db)
    end

    it 'sets results_as_hash for both databases' do
      expect(db_remote).to receive(:results_as_hash=).with(true)
      expect(local_db).to receive(:results_as_hash=).with(true)

      database_syncer.sync_with_remote_database(local_db, remote_path, remote_storage, bucket, local_db_path)
    end
  end

  describe '#open_remote_database' do
    it 'opens remote database' do
      db_remote = instance_double(SQLite3::Database)
      allow(SQLite3::Database).to receive(:new).with(remote_path).and_return(db_remote)
      expect(database_syncer.open_remote_database(remote_path)).to eq(db_remote)
    end

    it 'raises error if remote database cannot be opened' do
      allow(SQLite3::Database).to receive(:new).with(remote_path).and_return(nil)
      expect do
        database_syncer.open_remote_database(remote_path)
      end.to raise_error(RuntimeError, 'Failed to initialize remote database')
    end
  end

  describe '#sync_databases' do
    let(:db_remote) { instance_double(SQLite3::Database) }

    it 'processes database items and uploads local database' do
      allow(database_syncer).to receive(:process_database_items)
      expect(remote_storage).to receive(:upload_file).with(bucket, local_db_path, 'timet.db')
      database_syncer.sync_databases(local_db, db_remote, remote_storage, bucket, local_db_path)
    end
  end
end
