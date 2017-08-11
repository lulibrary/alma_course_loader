$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'alma_course_loader'
require 'alma_course_loader/cli/course_loader'

require 'minitest/autorun'
require 'minitest/reporters'

Minitest::Reporters.use!

# Assertions for course loader file properties
module Assertions
  # Course loader operations
  OPERATIONS = {
    delete: 'DELETE',
    rollover: 'ROLLOVER',
    update: nil
  }.freeze

  # Fails if the value doesn't match any of the optional assertions
  # @param type [String] the type of value (a constraints hash index)
  # @param value [Object] the value to test
  # @param constraints [Hash] the constraints
  # @return void
  def assert_course_details(type, value, constraints)
    assert_constraint_empty(type, value, constraints)
    assert_constraint_except(type, value, constraints)
    assert_constraint_range(type, value, constraints)
  end

  # Fails if the course entry doesn't pass all constraints
  # @param line_number [Integer] the line number in the course loader file
  # @param line [String] the line from the course loader file
  # @param constraints [Hash] the constraints
  # @return [void]
  def assert_course_entry(line_number, line, constraints)
    # Extract data fields from tab-separated CSV
    data = line.split("\t")
    # Check the entry against the file header
    return assert_course_header(data) if line_number == 1
    # Check the entry's file operation
    assert_course_entry_operation(data, constraints)
    # Check the course code details
    assert_course_entry_code(data, constraints)
  end

  # Fails if the course code doesn't pass all constraints
  # @param data [Array<String>] the data fields
  # @param constraints [Hash] the constraints
  # @return [void]
  def assert_course_entry_code(data, constraints)
    # Test the course code components
    course_code = data[0].split('-')
    assert_course_details(:course, course_code[0], constraints)
    assert_course_details(:cohort, course_code[2], constraints)
    assert_course_details(:year, course_code[1].to_i, constraints)
  end

  # Fails if the entry does not match file-level constraints
  # @param data [Array<String>] the data fields
  # @param constraints [Hash] the constraints
  # @return [void]
  def assert_course_entry_operation(data, constraints)
    file_op = constraint(:file, :op, constraints)
    return if file_op.nil?
    op = OPERATIONS[file_op]
    if op.nil?
      assert_nil(data[28], "Expected operation nil, got #{data[28]}")
    else
      assert_equal(data[28], op, "Expected operation #{op}, got #{data[28]}")
    end
  end

  # Fails if any course entry in the file doesn't match the constraints
  # @param filename [String] the course loader filename
  # @param constraints [Hash] the constraints
  def assert_course_file(filename, constraints)
    lines = 0
    File.foreach(filename) do |line|
      lines += 1
      assert_course_entry(lines, line.chomp, constraints)
    end
    assert_course_file_properties(lines, constraints)
  end

  # Fails if the file does match the expected constraints
  # @param lines [Integer] the actual number of lines
  # @param constraints [Hash] the constraints
  def assert_course_file_properties(lines, constraints)
    expected = constraint(:file, :lines, constraints).to_i
    assert_equal(expected, lines, 'Wrong file line count') if expected > 0
  end

  # Fails if the entry does not match the expected file header
  def assert_course_header(data)
    assert_equal(AlmaCourseLoader::Writer::ROW_HEADERS, data, 'Header expected')
  end
end

# Methods for specifying and testing course loader file constraints
module Constraints
  # Constraints are specified as:
  # {
  #   cohort: { constraints-hash },
  #   course: { constraints-hash },
  #   file:   { file-constraints-hash },
  #   year:   { constraints-hash }
  # }

  # constraint-hash may contain any of the following optional constraints:
  # {
  #   empty: if true, value must be nil or empty
  #   except: [value-which-should-not-be-present...]
  #   max: maximum value,
  #   min: minimum value
  # }

  # file-constraint-hash may contain any of the following optional constraints:
  # {
  #   lines: expected-number-of-lines,
  #   op: expected-course-loader-operation (:delete|:rollover|:update)
  # }

  # Fails if the value does not match its expected "emptiness" (nil? || empty?)
  # @param type [Symbol] the type of value
  # @param value [Object] the value to test
  # @param constraints [Hash] the constraints
  # @return void
  def assert_constraint_empty(type, value, constraints)
    require_empty = constraint(type, :empty, constraints)
    return if require_empty.nil?
    is_empty = value.nil? || (value.respond_to?(:empty?) && value.empty?)
    if require_empty
      assert(is_empty, "#{type} #{value} should be nil/empty")
    else
      refute(is_empty, "#{type} #{value} should not be nil/empty")
    end
  end

  # Fails if the value appears in an exception list
  # @param type [Symbol] the type of value
  # @param value [Object] the value to test
  # @param constraints [Hash] the constraints
  # @return void
  def assert_constraint_except(type, value, constraints)
    exceptions = constraint(type, :except, constraints)
    return if exceptions.nil? || exceptions.empty?
    refute_includes(exceptions, value, "#{type} #{value} not expected")
  end

  # Fails if the value lies outside a specified range
  # @param type [Symbol] the type of value
  # @param value [Object] the value to test
  # @param constraints [Hash] the constraints
  # @return void
  def assert_constraint_range(type, value, constraints)
    min = constraint(type, :min, constraints)
    max = constraint(type, :max, constraints)
    assert_operator(value, :>=, min, "#{type} #{value} < #{min}") if min
    assert_operator(value, :<=, max, "#{type} #{value} > #{max}") if max
  end

  # Sets constraints for cohort processing
  # @param use_cohorts [Boolean] if true, use courses with cohorts
  # @param constraints [Hash] the constraints
  # @return [Hash] the constraints
  def cohort_constraints(use_cohorts, constraints)
    if use_cohorts
      constraints[:cohort] = { empty: false, max: '2', min: '1' }
      constraints[:file][:lines] = 41
    else
      constraints[:cohort] = { empty: true }
      constraints[:file][:lines] = 21
    end
    constraints
  end

  # Returns the value of a constraint from the constraints hash
  # @param type [Symbol] the type of value
  # @param key [Symbol] the constraint key
  # @param constraints [Hash] the constraints hash
  # @return [Object, nil] the constraint value or nil if undefined
  def constraint(type, key, constraints)
    return nil if constraints.nil? || constraints[type].nil?
    constraints[type][key]
  end

  # Returns a set of default constraints
  # @param op [Symbol] the course loader operation
  # @param use_cohorts [Boolean] if true, use courses with cohorts
  # @return [Hash] the constraints
  def default_constraints(op = :update, use_cohorts: false)
    constraints = {
      course: { empty: false, max: 'CRS110', min: 'CRS101' },
      file: { op: op },
      year: { empty: false, max: 2016, min: 2015 }
    }
    cohort_constraints(use_cohorts, constraints)
    constraints
  end
end

# Test helper methods
module Helpers
  # Sets and returns the output filename for a method
  # @param method [Symbol] the method name
  # @param template [String] the filename template
  # @param files [Hash<Symbol, Integer|String>] the method-to-filename map
  # @return [String] the output filename
  def filename(method, template, files)
    # files maps method names to integer file suffixes or explicit filenames
    method_filename = files[method]
    # Return the filename for later clean-up
    if method_filename.is_a?(String)
      # Use filename as specified
      method_filename
    else
      # Substitute numeric suffix into filename template
      format(template, method_filename.to_i)
    end
  end
end

# Implements a mock course reader for testing
class CourseReader < ::AlmaCourseLoader::Reader
  attr_accessor :use_cohorts

  def initialize(*args, use_cohorts: true, **kwargs)
    super(*args, **kwargs)
    self.use_cohorts = use_cohorts
  end

  def courses(year)
    courses = []
    (101..110).each { |course| courses << "CRS#{course}-#{year}" }
    courses
  end

  def course_cohorts(year, course)
    return nil unless use_cohorts
    cohorts = []
    (1..2).each { |cohort| cohorts << "#{course}-#{cohort}" }
    cohorts
  end

  def current_academic_year
    2017
  end

  def instructors(year, course, cohort)
    instructors = []
    (1..10).each { |i| instructors << "#{cohort}-inst-#{i}" }
    instructors
  end

  def row_data(data, year, course, cohort, instructors)
    course_code = use_cohorts ? cohort : course
    previous_course_code = course_code.split('-')
    previous_course_code[1] = year - 1
    previous_course_code = previous_course_code.join('-')
    data[0] = course_code
    data[1] = "#{course_code} Title"
    data[2] = 'Section 1'
    data[3] = 'Processing dept'
    data[4] = 'Academic dept'
    data[5] = 'Autumn'
    data[6] = 'Winter'
    data[7] = 'Spring'
    data[8] = 'Summer'
    data[9] = "01-01-#{year}"
    data[10] = "30-06-#{year + 1}"
    data[11] = 50
    data[12] = 7
    data[13] = "#{year}-#{year + 1}"
    data[14] = "#{course_code} search-id 1"
    data[15] = "#{course_code} search-id 2"
    data[16] = "#{course_code} search-id 3"
    (0..9).each { |i| data[17 + i] = "#{course_code}-#{instructors[i]}" }
    data[27] = instructors.join(',')
    data[28] = 'OPERATION'
    data[29] = previous_course_code
    data[30] = 'Section 1'
  end
end

# Implements a mock CLI for testing
class CourseCLI < ::AlmaCourseLoader::CLI::CourseLoader
  def extractors
    {
      cohort: proc { |_year, _course, cohort| cohort },
      course: proc { |_year, course, _cohort| course },
      year: proc { |year, _course, _cohort| year }
    }
  end

  def reader
    CourseReader.new(*time_period_list, use_cohorts: true, filters: filter_list)
  end

  private

  # Convert a string containing a year to the year as a number
  def time_period(time_period_s)
    time_period_s.to_i
  end
end