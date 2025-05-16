# frozen_string_literal: true

module Timet
  #
  # The BlockCharHelper module provides a utility method for getting the block character
  # based on a given value.
  #
  module BlockCharHelper
    # Character mapping for different time ranges
    CHAR_MAPPING = {
      0..120 => '_',
      121..450 => ' ',
      451..900 => '▂',
      901..1350 => '▃',
      1351..1800 => '▄',
      1801..2250 => '▅',
      2251..2700 => '▆',
      2701..3150 => '▇',
      3151..3600 => '█'
    }.freeze

    # Gets the block character for a given value
    #
    # @param [Integer, nil] value The value
    # @return [String] The block character
    def self.get_block_char(value)
      return ' ' unless value

      mapping = CHAR_MAPPING.find { |range, _| range.include?(value) }
      mapping ? mapping.last : ' '
    end
  end
end
