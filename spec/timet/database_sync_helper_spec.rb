# frozen_string_literal: true

require 'rspec'
require 'sqlite3'
require 'timet/database_sync_helper'
require 'timet/s3_supabase'

RSpec.describe Timet::DatabaseSyncHelper do
  let(:local_db) { SQLite3::Database.new(':memory:') }
  let(:bucket) { 'test-bucket' }
  let(:remote_storage) { instance_double('Timet::S3Supabase') }

  before do
    allow(Timet::S3Supabase).to receive(:new).and_return(remote_storage)
    allow(remote_storage).to receive(:create_bucket).with(bucket)
  end

  describe '.sync' do
    context 'when remote database exists' do
      before do
        allow(remote_storage).to receive(:list_objects).with(bucket).and_return([{ key: 'timet.db' }])
        allow(Timet::DatabaseSyncHelper).to receive(:process_remote_database)
      end

      it 'processes the remote database' do
        Timet::DatabaseSyncHelper.sync(local_db, bucket)
        expect(Timet::DatabaseSyncHelper).to have_received(:process_remote_database).with(local_db, remote_storage,
                                                                                          bucket, Timet::Database::DEFAULT_DATABASE_PATH)
      end
    end

    context 'when remote database does not exist' do
      before do
        allow(remote_storage).to receive(:list_objects).with(bucket).and_return([])
        allow(remote_storage).to receive(:upload_file)
      end

      it 'uploads the local database' do
        expect do
          Timet::DatabaseSyncHelper.sync(local_db, bucket)
        end.to output(/No remote database found, uploading local database/).to_stdout
        expect(remote_storage).to have_received(:upload_file).with(bucket, Timet::Database::DEFAULT_DATABASE_PATH,
                                                                   'timet.db')
      end
    end
  end
end
