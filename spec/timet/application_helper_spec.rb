# frozen_string_literal: true

require 'timet/application_helper'

RSpec.describe Timet::ApplicationHelper do
  include described_class

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

  describe '#run_linux_session' do
    it 'constructs the correct command and detaches the process' do
      time = 1500
      tag = 'work'
      expected_command = "sleep #{time} && tput bel && tt stop 0 && notify-send --icon=clock 'Pomodoro session complete (#{tag}). Time for a break.' &"
      mock_pid = 1234

      # Ensure stub is applied before calling the method
      allow(Kernel).to receive(:spawn).and_return(mock_pid)
      allow(Process).to receive(:detach)

      # Call the method
      run_linux_session(time, tag)

      # Validate spawn and detach were called
      expect(Kernel).to have_received(:spawn).with(expected_command).once
      expect(Process).to have_received(:detach).with(mock_pid).once
    end
  end

  describe '#run_mac_session' do
    it 'constructs the correct command and detaches the process' do
      time = 1500
      tag = 'work'
      expected_command = "sleep #{time} && afplay /System/Library/Sounds/Basso.aiff && tt stop 0 && osascript -e 'display notification \"Pomodoro session complete (work). Time for a break.\"' &"
      mock_pid = 1235

      # Ensure stub is applied before calling the method
      allow(Kernel).to receive(:spawn).and_return(mock_pid)
      allow(Process).to receive(:detach)

      # Call the method
      run_mac_session(time, tag)

      # Validate spawn and detach were called
      expect(Kernel).to have_received(:spawn).with(expected_command).once
      expect(Process).to have_received(:detach).with(mock_pid).once
    end
  end
end
