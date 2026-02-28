# frozen_string_literal: true

module Timet
  # Module responsible for synchronizing local and remote databases
  module DatabaseSyncer
    ITEM_FIELDS = %w[start end tag notes pomodoro updated_at created_at deleted].freeze

    def handle_database_differences(*args)
      local_db, remote_storage, bucket, local_db_path, remote_path = args
      puts 'Differences detected between local and remote databases'
      begin
        sync_with_remote_database(local_db, remote_path, remote_storage, bucket, local_db_path)
      rescue SQLite3::Exception => e
        handle_sync_error(e, remote_storage: remote_storage, bucket: bucket, local_db_path: local_db_path)
      end
    end

    def handle_sync_error(error, *args)
      first_arg = args.first
      if first_arg.is_a?(Hash)
        options = first_arg
        remote_storage, bucket, local_db_path = options.values_at(:remote_storage, :bucket, :local_db_path)
      else
        remote_storage, bucket, local_db_path = args
      end
      report_sync_error(error)
      upload_local_database(remote_storage, bucket, local_db_path)
    end

    def report_sync_error(error)
      puts "Error opening remote database: #{error.message}"
      puts 'Uploading local database to replace corrupted remote database'
    end
    module_function :report_sync_error

    def upload_local_database(remote_storage, bucket, local_db_path)
      remote_storage.upload_file(bucket, local_db_path, 'timet.db')
    end
    module_function :upload_local_database

    def sync_with_remote_database(*args)
      local_db, remote_path, remote_storage, bucket, local_db_path = args
      db_remote = open_remote_database(remote_path)
      db_remote.results_as_hash = true
      local_db.instance_variable_get(:@db).results_as_hash = true
      sync_databases(local_db, db_remote, remote_storage, bucket, local_db_path)
    end

    def open_remote_database(remote_path)
      db_remote = SQLite3::Database.new(remote_path)
      raise 'Failed to initialize remote database' unless db_remote

      db_remote
    end

    def sync_databases(*args)
      local_db, remote_db, remote_storage, bucket, local_db_path = args
      process_database_items(local_db, remote_db)
      remote_storage.upload_file(bucket, local_db_path, 'timet.db')
      puts 'Database sync completed'
    end

    def process_database_items(local_db, remote_db)
      remote_items = remote_db.execute('SELECT * FROM items ORDER BY updated_at DESC')
      local_items = local_db.execute_sql('SELECT * FROM items ORDER BY updated_at DESC')

      sync_items_by_id(local_db, items_to_hash(local_items), items_to_hash(remote_items))
    end

    def sync_items_by_id(local_db, local_items_by_id, remote_items_by_id)
      all_item_ids = (remote_items_by_id.keys + local_items_by_id.keys).uniq
      all_item_ids.each { |id| sync_single_item(local_db, id, local_items_by_id, remote_items_by_id) }
    end

    def sync_single_item(*args)
      local_db, id, local_items_by_id, remote_items_by_id = args
      remote_item = remote_items_by_id[id]
      local_item = local_items_by_id[id]

      if !remote_item
        log_local_only(id)
      elsif !local_item
        add_remote_item(local_db, id, remote_item)
      else
        merge_item(local_db, id, local_item, remote_item)
      end
    end

    def log_local_only(id)
      puts "Local item #{id} will be uploaded"
    end
    module_function :log_local_only

    def add_remote_item(local_db, id, remote_item)
      puts "Adding remote item #{id} to local"
      insert_item_from_hash(local_db, remote_item)
    end

    def process_existing_item(id, local_item, remote_item, local_db)
      merge_item(local_db, id, local_item, remote_item)
    end

    def merge_item(*args)
      local_db, id, local_item, remote_item = args
      local_time = extract_timestamp(local_item)
      remote_time = extract_timestamp(remote_item)

      return resolve_remote_wins(local_db, id, remote_item) if remote_wins?(remote_item, remote_time, local_time)

      log_local_wins(id, local_item)
    end

    def resolve_remote_wins(local_db, id, remote_item)
      puts format_status_message(id, remote_item, 'Remote')
      update_item_from_hash(local_db, remote_item)
      :local_update
    end

    def log_local_wins(id, local_item)
      puts format_status_message(id, local_item, 'Local')
      :remote_update
    end

    def insert_item_from_hash(db, item)
      fields = ['id', *ITEM_FIELDS].join(', ')
      placeholders = Array.new(ITEM_FIELDS.length + 1, '?').join(', ')
      db.execute_sql(
        "INSERT INTO items (#{fields}) VALUES (#{placeholders})",
        get_insert_values(item)
      )
    end

    def update_item_from_hash(db, item)
      fields = "#{ITEM_FIELDS.join(' = ?, ')} = ?"
      db.execute_sql(
        "UPDATE items SET #{fields} WHERE id = ?",
        get_update_values(item)
      )
    end

    def extract_timestamp(item)
      item['updated_at'].to_i
    end
    module_function :extract_timestamp

    def items_to_hash(items)
      items.to_h { |item| [item['id'], item] }
    end

    def remote_wins?(remote_item, remote_time, local_time)
      time_diff = remote_time > local_time
      time_diff && (remote_item['deleted'].to_i == 1 || time_diff)
    end

    def format_status_message(id, item, source)
      deleted = item['deleted'].to_i == 1 ? ' and deleted' : ''
      "#{source} item #{id} is newer#{deleted} - #{source == 'Remote' ? 'updating local' : 'will be uploaded'}"
    end
    module_function :format_status_message

    def get_insert_values(item)
      @database_fields ||= ITEM_FIELDS
      values = @database_fields.map { |field| item[field] }
      [item['id'], *values]
    end

    def get_update_values(item)
      @database_fields ||= ITEM_FIELDS
      @database_fields.map { |field| item[field] }
    end

    def get_item_values(item, include_id_at_start: false)
      include_id_at_start ? get_insert_values(item) : get_update_values(item)
    end
  end
end
