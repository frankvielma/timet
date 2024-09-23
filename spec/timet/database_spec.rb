# frozen_string_literal: true

require "timet/database"
require "tmpdir"

RSpec.describe Timet::Database do
  let(:db_path) { File.join(Dir.tmpdir, "test_timet.db") }
  let(:db) { described_class.new(db_path) }
  let(:last_item) do
    db.execute_sql("SELECT * FROM items ORDER BY id DESC LIMIT 1").first
  end
  let(:test_tag) { "Test Task" }

  after do
    db.close
    FileUtils.rm_f(db_path)
  end

  # Test Table Creation
  describe "#create_table" do
    it "creates the items table if it doesn't exist" do
      expect { db.create_table }.not_to raise_error
    end

    # Ensure the table has the expected structure
    it "creates a table with the correct columns" do
      db.create_table

      # Retrieve table schema
      schema = db.execute_sql("PRAGMA table_info(items)").map { |row| row[1] }
      # Use a set for order-independent comparison
      expect(Set.new(schema)).to eq(Set.new(%w[id start end tag notes]))
    end
  end

  # Test Item Insertion
  describe "#insert_item" do
    it "inserts an item into the table" do
      start_time = 1_678_886_400
      tag = "work"

      db.insert_item(start_time, tag)
      result = db.fetch_last_id

      expect(result).to eq(1)
    end

    it "inserts an item with the correct start time" do
      start_time = 1_678_886_400
      tag = "work"

      db.insert_item(start_time, tag)
      expect(last_item[1]).to eq(start_time)
    end

    it "inserts an item with the correct tag" do
      start_time = 1_678_886_400
      tag = "work"

      db.insert_item(start_time, tag)
      expect(last_item[3]).to eq(tag)
    end
  end

  ## Test End Time Update
  describe "#update" do
    it "updates the end time of the last item" do
      db.insert_item(1_678_886_400, "work")
      db.update(1_678_886_460)
      expect(last_item[2]).to eq(1_678_886_460)
    end

    it "does nothing if there's no last item" do
      expect { db.update(1_678_886_460) }.not_to(change(db, :fetch_last_id))
    end
  end

  # Test Fetching Last ID
  describe "#fetch_last_id" do
    it "returns the ID of the last inserted item" do
      db.insert_item(1_678_886_400, "work")
      expect(db.fetch_last_id).to eq(1)
    end

    it "returns nil if no items exist" do
      expect(db.fetch_last_id).to be_nil
    end
  end

  describe "#last_item" do
    it "returns the last item from the items table" do
      start_time = Time.now.to_i
      tag = "Test Task"
      db.insert_item(start_time, tag)
      last_item = db.last_item

      # Check if the item is correct (one expectation per block)
      expect(last_item[1]).to eq(start_time)
    end

    it "returns the correct start time and tag for the last item" do
      start_time = Time.now.to_i
      db.insert_item(start_time, test_tag)
      last_item = db.last_item

      expect(last_item[3]).to eq(test_tag)
    end

    it "returns nil if no items exist" do
      # Call last_item without inserting any items
      last_item = db.last_item

      # Check if it returns nil
      expect(last_item).to be_nil
    end
  end

  describe "#last_item_status" do
    context "when no items exist" do
      it "returns :no_items" do
        expect(db.last_item_status).to eq(:no_items)
      end
    end

    context "when the last item is incomplete" do
      it "returns :incomplete" do
        start_time = Time.now.to_i
        db.insert_item(start_time, test_tag)

        expect(db.last_item_status).to eq(:incomplete)
      end
    end

    context "when the last item is complete" do
      it "returns :complete" do
        start_time = Time.now.to_i
        db.insert_item(start_time, test_tag)
        db.update(Time.now.to_i)

        expect(db.last_item_status).to eq(:complete)
      end
    end
  end

  # Test Total Time Calculation
  describe "#total_time" do
    it "returns the correct total time for an incomplete item" do
      start_time = Time.now.to_i - 3600
      db.insert_item(start_time, "work")
      expect(db.total_time).to eq("01:00:00")
    end

    it "returns the correct total time for a complete item" do
      start_time = 1_678_886_400
      end_time = 1_678_886_460
      db.insert_item(start_time, "work")
      db.update(end_time)
      expect(db.total_time).to eq("00:01:00")
    end

    it "returns 00:00:00 for an empty database" do
      expect(db.total_time).to eq("00:00:00")
    end
  end

  describe "#execute_sql" do
    it "executes a SQL query and returns the result" do
      result = db.execute_sql("SELECT * FROM items")
      expect(result).to be_a(Array)
    end

    it "handles errors during query execution" do
      # Execute an invalid query
      result = db.execute_sql("INVALID SQL")

      # Check if it returns an empty array and prints an error message
      expect(result).to be_empty
    end
  end

  # Test Database Closing
  describe "#close" do
    it "closes the database connection" do
      db.close
      expect(db.instance_variable_get(:@db).closed?).to be true
    end
  end
end
