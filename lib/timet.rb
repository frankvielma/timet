# frozen_string_literal: true

# Require the Timet::Application class from the 'timet/application' file.
#
# @note This statement loads the Timet::Application class, which is responsible for handling the command-line interface and user commands.
require_relative 'timet/application'

# Require the Timet::Database class from the 'timet/database' file.
#
# @note This statement loads the Timet::Database class, which provides database access for managing time tracking data.
require_relative 'timet/database'

# Require the Timet::TimeReport class from the 'timet/time_report' file.
#
# @note This statement loads the Timet::TimeReport class, which is responsible for displaying a report of tracked time entries.
require_relative 'timet/time_report'
