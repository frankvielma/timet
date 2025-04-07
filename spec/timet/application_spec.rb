# frozen_string_literal: true

require 'timet/application'
require 'timet/database'
require 'tty-prompt'

RSpec.describe Timet::Application do
  let(:db) { Timet::Database.new(':memory:') }
  let(:app) { described_class.new([], {}, { database: db }) }
  let(:prompt) { instance_double(TTY::Prompt) }

  before do
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
    # Ensure the table is empty before each test
    db.execute_sql('DELETE FROM items')
  end

  describe '#edit' do
    before do
      db.execute_sql('INSERT INTO items (start, end, tag, notes) VALUES (?, ?, ?, ?)', [100, 200, 'test', 'test note'])
    end

    context 'when field and new_value are not provided' do
      it 'prompts the user for field and new_value' do
        allow(prompt).to receive_messages(select: 'tag', ask: 'new_tag')

        app.edit(1)

        result = db.execute_sql('SELECT tag FROM items WHERE id = ?', [1])
        expect(result[0][0]).to eq('new_tag')
      end
    end

    context 'when field and new_value are provided' do
      it 'updates the item with the provided field and new_value' do
        app.edit(1, 'tag', 'new_tag')

        result = db.execute_sql('SELECT tag FROM items WHERE id = ?', [1])
        expect(result[0][0]).to eq('new_tag')
      end
    end
  end
end
