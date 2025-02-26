# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_context 'when S3Supabase is set up' do
  let(:env_file_path) { File.join('/tmp', '.timet', '.env') }
  let(:s3_client_mock) { instance_double(Aws::S3::Client) }

  let(:s3_config) do
    {
      s3_endpoint: 'http://localhost:9000',
      s3_access_key: 'test',
      s3_secret_key: 'test123',
      s3_region: 'us-west-1',
      bucket_name: 'test-bucket'
    }
  end

  before do
    # Create and populate .env file
    FileUtils.mkdir_p(File.dirname(env_file_path))
    File.write(env_file_path, <<~ENV)
      S3_ENDPOINT='#{s3_config[:s3_endpoint]}'
      S3_ACCESS_KEY='#{s3_config[:s3_access_key]}'
      S3_SECRET_KEY='#{s3_config[:s3_secret_key]}'
      S3_REGION='#{s3_config[:s3_region]}'
    ENV

    # Load environment variables
    Dotenv.load(env_file_path)

    # Mock AWS S3 Client
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client_mock)

    if File.exist?(Timet::S3Supabase::ENV_FILE_PATH)
      FileUtils.mv(Timet::S3Supabase::ENV_FILE_PATH, "#{Timet::S3Supabase::ENV_FILE_PATH}.backup", force: true)
    end
  end

  after do
    if File.exist?("#{Timet::S3Supabase::ENV_FILE_PATH}.backup")
      FileUtils.mv("#{Timet::S3Supabase::ENV_FILE_PATH}.backup", Timet::S3Supabase::ENV_FILE_PATH, force: true)
    end
  end
end

RSpec.describe Timet::S3Supabase do
  include_context 'when S3Supabase is set up'

  let(:s3_supabase) { described_class.new }
  let(:bucket_name) { s3_config[:bucket_name] }

  describe '#initialize' do
    it 'initializes successfully with valid environment variables' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe '.ensure_env_file_exists' do
    let(:temp_env_path) { File.join('/tmp', '.timet_test', '.env') }

    it 'adds S3_ENDPOINT to the .env file' do
      Timet.ensure_env_file_exists(env_file_path)
      content = File.read(env_file_path)
      expect(content).to include("S3_ENDPOINT='http://localhost:9000'")
    end

    it 'adds S3_ACCESS_KEY to the .env file' do
      Timet.ensure_env_file_exists(env_file_path)
      content = File.read(env_file_path)
      expect(content).to include("S3_ACCESS_KEY='test'")
    end

    it 'adds S3_SECRET_KEY to the .env file' do
      Timet.ensure_env_file_exists(env_file_path)
      content = File.read(env_file_path)
      expect(content).to include("S3_SECRET_KEY='test123'")
    end

    it 'adds S3_REGION to the .env file' do
      Timet.ensure_env_file_exists(env_file_path)
      content = File.read(env_file_path)
      expect(content).to include("S3_REGION='us-west-1'")
    end
  end

  describe '#download_file' do
    let(:download_dependencies) do
      {
        object_key: 'test-object',
        download_path: 'downloaded_file.txt',
        response_body: 'file content'
      }
    end
    let(:response_mock) do
      instance_double(Aws::S3::Types::GetObjectOutput, body: StringIO.new(download_dependencies[:response_body]))
    end

    before do
      allow(s3_client_mock).to receive(:get_object)
        .with(bucket: bucket_name, key: download_dependencies[:object_key]).and_return(response_mock)
      allow(File).to receive(:binwrite)
        .with(download_dependencies[:download_path],
              download_dependencies[:response_body]).and_return(download_dependencies[:response_body].length)
      allow(s3_supabase.instance_variable_get(:@logger)).to receive(:info)
      allow(s3_supabase.instance_variable_get(:@logger)).to receive(:error)
    end

    after do
      FileUtils.rm_f(download_dependencies[:download_path])
    end

    it 'downloads file successfully' do
      s3_supabase.download_file(bucket_name, download_dependencies[:object_key], download_dependencies[:download_path])
      expect(File).to have_received(:binwrite).with(download_dependencies[:download_path],
                                                    download_dependencies[:response_body])
    end

    it 'logs successful download' do
      s3_supabase.download_file(bucket_name, download_dependencies[:object_key], download_dependencies[:download_path])
      response = "File '#{download_dependencies[:object_key]}' downloaded successfully."
      expect(s3_supabase.instance_variable_get(:@logger)).to have_received(:info).with(response)
    end

    it 'handles service error' do
      allow(s3_client_mock).to receive(:get_object).with(bucket: bucket_name, key: download_dependencies[:object_key])
                                                   .and_raise(Aws::S3::Errors::ServiceError.new(nil,
                                                                                                'Service error'))
      s3_supabase.download_file(bucket_name, download_dependencies[:object_key], download_dependencies[:download_path])
      response = 'Error downloading file: Service error'
      expect(s3_supabase.instance_variable_get(:@logger)).to have_received(:error).with(response)
    end
  end

  describe '#create_bucket' do
    it 'creates a bucket successfully' do
      allow(s3_client_mock).to receive(:create_bucket).with(bucket: bucket_name)
      expect(s3_supabase.create_bucket(bucket_name)).to be true
    end

    it 'handles bucket already exists error' do
      allow(s3_client_mock).to receive(:create_bucket)
        .and_raise(Aws::S3::Errors::BucketAlreadyExists.new(nil, 'Bucket exists'))
      expect(s3_supabase.create_bucket(bucket_name)).to be false
    end
  end

  describe '#list_objects' do
    let(:empty_response) { instance_double(Aws::S3::Types::ListObjectsV2Output, contents: []) }
    let(:object_mock) { instance_double(Aws::S3::Types::Object, key: 'test.txt', last_modified: Time.now, to_h: {}) }
    let(:populated_response) { instance_double(Aws::S3::Types::ListObjectsV2Output, contents: [object_mock]) }

    it 'returns false for empty bucket' do
      allow(s3_client_mock).to receive(:list_objects_v2)
        .with(bucket: bucket_name)
        .and_return(empty_response)
      expect(s3_supabase.list_objects(bucket_name)).to be false
    end

    it 'returns array of objects for non-empty bucket' do
      allow(s3_client_mock).to receive(:list_objects_v2)
        .with(bucket: bucket_name)
        .and_return(populated_response)
      expect(s3_supabase.list_objects(bucket_name)).to be_an(Array)
    end
  end

  describe '#upload_file' do
    let(:file_path) { 'test.txt' }
    let(:object_key) { 'uploaded.txt' }

    before do
      File.write(file_path, 'test content')
    end

    after do
      FileUtils.rm_f(file_path)
    end

    it 'uploads file successfully' do
      allow(s3_client_mock).to receive(:put_object)
      expect { s3_supabase.upload_file(bucket_name, file_path, object_key) }
        .not_to raise_error
    end
  end

  describe '#delete_object' do
    let(:object_key) { 'test-object' }

    it 'deletes object successfully' do
      allow(s3_client_mock).to receive(:delete_object).with(bucket: bucket_name, key: object_key).and_return(true)
      expect { s3_supabase.delete_object(bucket_name, object_key) }.not_to raise_error
    end

    it 'handles service error' do
      allow(s3_client_mock).to receive(:delete_object).with(bucket: bucket_name, key: object_key)
                                                      .and_raise(Aws::S3::Errors::ServiceError.new(nil,
                                                                                                   'Service error'))
      expect { s3_supabase.delete_object(bucket_name, object_key) }.to raise_error(Aws::S3::Errors::ServiceError)
    end
  end

  describe '#delete_bucket' do
    let(:object_mock) { instance_double(Aws::S3::Types::Object, key: 'test-object') }

    before do
      allow(s3_client_mock).to receive(:list_objects_v2).with(bucket: bucket_name).and_return(
        instance_double(Aws::S3::Types::ListObjectsV2Output, contents: [object_mock])
      )
      allow(object_mock).to receive_messages(to_h: {}, last_modified: Time.now)
      allow(s3_supabase).to receive(:delete_object).with(bucket_name, 'test-object').and_return(true)
    end

    it 'deletes bucket and all its contents successfully' do
      allow(s3_client_mock).to receive(:delete_bucket).with(bucket: bucket_name).and_return(true)
      expect { s3_supabase.delete_bucket(bucket_name) }.not_to raise_error
    end

    it 'handles service error' do
      allow(s3_client_mock).to receive(:delete_bucket).with(bucket: bucket_name)
                                                      .and_raise(Aws::S3::Errors::ServiceError.new(nil,
                                                                                                   'Service error'))
      expect { s3_supabase.delete_bucket(bucket_name) }.to raise_error(Aws::S3::Errors::ServiceError)
    end
  end
end
