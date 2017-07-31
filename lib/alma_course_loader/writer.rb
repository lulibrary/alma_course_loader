require 'csv'

require 'alma_course_loader/version'

module AlmaCourseLoader
  # Writes an Alma course loader file
  #
  # This provides a single class method #write which accepts an output filename,
  # the Alma course loader operation (:delete, :rollover, :update) and a
  # Reader instance. The output is a tab-delimited CSV file containing one row
  # per course element.
  #
  # The writer calls the reader's #each_row method without arguments, so the
  # reader must be constructed with the appropriate defaults.
  #
  # For course rollover, the writer assumes that the reader provides the correct
  # previous course ID and section ID in the row data. These fields are not
  # output for other operations.
  #
  # If the operation is unspecified or invalid, the default is :update
  #
  # @example Write an Alma course loader file to update course entries
  #   # The reader must be constructed with the appropriate selection criteria
  #   reader = Reader.new(2015, 2016, 2017, filters: [...])
  #   Writer.write('courses.xls', :update, reader)
  #
  # @example Write an Alma course loader file for course rollover
  #   Writer.write('courses.xls', :rollover, reader)
  #
  # @example Write an Alma course loader file to delete course entries
  #   Writer.write('courses.xls', :delete, reader)
  #
  class Writer
    # CSV row headers
    ROW_HEADERS = %w[
      COURSE_CODE
      COURSE_TITLE
      SECTION_ID
      ACAD_DEPT
      PROC_DEPT
      TERM1
      TERM2
      TERM3
      TERM4
      START_DATE
      END_DATE
      NUM_OF_PARTICIPANTS
      WEEKLY_HOURS
      YEAR
      SEARCH_ID1
      SEARCH_ID2
      ALL_SEARCHABLE_IDS
      INSTR1
      INSTR2
      INSTR3
      INSTR4
      INSTR5
      INSTR6
      INSTR7
      INSTR8
      INSTR9
      INSTR10
      ALL_INSTRUCTORS
      OPERATION
      OLD_COURSE_CODE
      OLD_COURSE_SECTION
    ].freeze

    # Creates a CSV file in the Alma Course Loader format
    # @param filename [String] the filename of the course loader file
    # @param op [Symbol] the file loader operation (:delete, :rollover, :update)
    # @param courses [AlmaCourseLoader::Reader] the course reader
    def self.write(filename = nil, op = nil, courses = nil)
      # Check the operation, default to regular import if invalid
      op, rollover = write_op(op)
      # Write the course data to a tab-separated CSV file
      CSV.open(filename, 'wb', col_sep: "\t") do |csv|
        # Write the header row
        csv << ROW_HEADERS
        # Write a row for each course entry
        courses.each_row { |row| csv << row_data(row, op, rollover) }
      end
    end

    class << self
      protected

      # Adds the operation and related fields to the row data
      # @param row [Array<String>] the CSV row data
      # @param op [String] the Alma Course Loader operation
      #   '' - update
      #   'DELETE' - delete
      #   'ROLLOVER' - course rollover
      # @param rollover [Boolean] true if performing rollover, false otherwise
      def row_data(row, op, rollover)
        row[28] = op
        # The old course ID and section ID are only required for rollover
        unless rollover
          row[29] = nil
          row[30] = nil
        end
        row
      end

      # Returns the Alma Course Loader operation string
      # @param op [Symbol] the operation (:delete, :rollover, :update)
      # @return [String, Boolean] the Alma operation string and a Boolean set
      #   to true if performing rollover, false otherwise
      def write_op(op)
        rollover = op == :rollover
        op = %i[delete rollover].include?(op) ? op.to_s.upcase : nil
        [op, rollover]
      end
    end
  end
end