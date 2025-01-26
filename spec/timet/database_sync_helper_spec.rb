# frozen_string_literal: true

require 'rspec'
require 'sqlite3'
require 'timet/database_sync_helper'
require 'timet/s3_supabase'

RSpec.describe Timet::DatabaseSyncHelper do
  let(:local_db) { SQLite3::Database.new(':memory:') }
  let(:bucket) { 'test-bucket' }
  let(:remote_storage) { instance_double(Timet::S3Supabase) }

  before do
    allow(Timet::S3Supabase).to receive(:new).and_return(remote_storage)
    allow(remote_storage).to receive(:create_bucket).with(bucket)
  end

  describe '.sync' do
    context 'when remote database exists' do
      before do
        allow(remote_storage).to receive(:list_objects).with(bucket).and_return([{ key: 'timet.db' }])
        allow(described_class).to receive(:process_remote_database)
      end

      it 'processes the remote database' do
        described_class.sync(local_db, bucket)
        expect(described_class).to have_received(:process_remote_database).with(local_db,
                                                                                remote_storage,
                                                                                bucket,
                                                                                Timet::Database::DEFAULT_DATABASE_PATH)
      end
    end

    context 'when remote database does not exist' do
      before do
        allow(remote_storage).to receive(:list_objects).with(bucket).and_return([])
        allow(remote_storage).to receive(:upload_file)
      end

      it 'uploads the local database' do
        expect do
          described_class.sync(local_db, bucket)
        end.to output(/No remote database found, uploading local database/).to_stdout
        expect(remote_storage).to have_received(:upload_file).with(bucket, Timet::Database::DEFAULT_DATABASE_PATH,
                                                                   'timet.db')
      end
    end

    it 'creates the bucket' do
      allow(remote_storage).to receive(:list_objects).with(bucket).and_return([])
      allow(remote_storage).to receive(:upload_file)
      described_class.sync(local_db, bucket)
      expect(remote_storage).to have_received(:create_bucket).with(bucket)
    end
  end

  describe '.process_remote_database' do
    let(:local_db_path) { 'local_db_path' }
    let(:temp_file) { instance_double(Tempfile, path: 'temp_file_path') }

    before do
      allow(described_class).to receive(:with_temp_file).and_yield(temp_file)
      allow(remote_storage).to receive(:download_file).with(bucket, 'timet.db', temp_file.path)
    end

    context 'when databases are in sync' do
      before do
        allow(described_class).to receive(:databases_are_in_sync?).with(temp_file.path,
                                                                        local_db_path).and_return(true)
      end

      it 'prints that the local database is up to date' do
        expect do
          described_class.process_remote_database(local_db, remote_storage, bucket, local_db_path)
        end.to output(/Local database is up to date/).to_stdout
      end
    end

    context 'when databases are not in sync' do
      before do
        allow(described_class).to receive(:databases_are_in_sync?).with(temp_file.path,
                                                                        local_db_path).and_return(false)
        allow(described_class).to receive(:handle_database_differences)
      end

      it 'handles database differences' do
        described_class.process_remote_database(local_db, remote_storage, bucket, local_db_path)
        expect(described_class).to have_received(:handle_database_differences).with(local_db, remote_storage,
                                                                                    bucket, local_db_path, temp_file.path)
      end
    end
  end
end
