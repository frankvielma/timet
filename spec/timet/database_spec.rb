# frozen_string_literal: true

require "timet/database"
require "tmpdir"

RSpec.describe Timet::Database do
  let(:db_path) { File.join(Dir.tmpdir, "test_timet.db") }
  let(:db) { described_class.new(db_path) }

  after do
    db.close
    FileUtils.rm_f(db_path)
  end

  it "creates a table if it doesn't exist" do
    expect { db.create_table }.not_to raise_error
  end

  it "inserts an item into the table" do
    start_time = 1_678_886_400
    tag = "work"

    db.insert_item(start_time, tag)

    result = db.fetch_last_id

    expect(result).to eq(1)
  end

  it "updates the end time of the last item" do
    db.insert_item(1_678_886_400, "work")
    db.update(1_678_886_460)

    result = db.execute_sql("SELECT * FROM items ORDER BY id DESC LIMIT 1").first
    expect(result[2]).to eq(1_678_886_460)
  end

  it "closes the database connection" do
    db.close
    expect(db.instance_variable_get(:@db).closed?).to be true
  end
end
