# frozen_string_literal: true

require 'timet/application_helper'

RSpec.describe Timet::ApplicationHelper do
  include Timet::ApplicationHelper

  describe '#show_message' do
    it 'returns the correct message for a given tag' do
      tag = 'work'
      expected_message = 'Pomodoro session complete (work). Time for a break.'
      expect(show_message(tag)).to eq(expected_message)
    end
  end

  describe '#export_report' do
    let(:report) { instance_double(Timet::TimeReport, items: items) }
    let(:options) { {} }

    context 'when there are items in the report' do
      let(:items) { [1, 2, 3] }

      it 'calls export_csv_report and export_icalendar_report' do
        expect(Timet::ApplicationHelper::ReportExporter).to receive(:export_csv_report).with(report, options)
        expect(Timet::ApplicationHelper::ReportExporter).to receive(:export_icalendar_report).with(report, options)
        export_report(report, options)
      end
    end

    context 'when there are no items in the report' do
      let(:items) { [] }

      it 'prints "No items found to export"' do
        expect { export_report(report, options) }.to output("No items found to export\n").to_stdout
      end
    end
  end
end
