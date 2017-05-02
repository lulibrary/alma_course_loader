require 'alma_course_loader'

require 'test_helper'

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
    assert_course_details(:year, course_code[1], constraints)
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
      year: { empty: false, max: '2016', min: '2015' }
    }
    cohort_constraints(use_cohorts, constraints)
    constraints
  end
end

# Base class for test classes
class AlmaCourseLoaderTest < ::Minitest::Test
  include Assertions
  include Constraints

  FILE = '/tmp/alma_course_loader_%d.csv'.freeze
  FILES = {
    test_no_cohorts_no_filters: 1,
    test_with_cohorts_no_filters: 2
  }.freeze

  # Pre-test setup
  def setup
    # @file is set when a temporary filename is assigned
    @file = nil
  end

  # Post-test clean-up
  def teardown
    # Remove the temporary file
    # File.delete(@file) if @file
  end

  # Tests an unfiltered course reader with cohort processing disabled
  def test_no_cohorts_no_filters
    # Reader should produce 20 course entries + 1 header line
    # (10 courses per year * 2 years)
    reader = CourseReader.new(2015, 2016, use_cohorts: false)
    constraints = default_constraints(:update, use_cohorts: false)
    write_file(__callee__, reader, constraints)
  end

  # Tests that a version number is defined
  def test_version_number
    refute_nil ::AlmaCourseLoader::VERSION
  end

  # Tests an unfiltered course reader with cohort processing enabled
  def test_with_cohorts_no_filters
    # Reader should produce 40 course entries + 1 header line
    # (10 courses per year * 2 cohorts per course * 2 years)
    reader = CourseReader.new(2015, 2016, use_cohorts: true)
    constraints = default_constraints(:update, use_cohorts: true)
    write_file(__callee__, reader, constraints)
  end

  private

  # Sets and returns the output filename for a method
  # @param method [Symbol] the method name
  # @return [String] the output filename
  def filename(method)
    # FILES maps method names to integer file suffixes or explicit filenames
    method_filename = FILES[method]
    # Store the filename for later clean-up
    @file = if method_filename.is_a?(String)
              # Use filename as specified
              method_filename
            else
              # Substitute numeric suffix into filename template
              format(FILE, method_filename.to_i)
            end
  end

  # Writes a course loader file and asserts its properties
  def write_file(method, reader, constraints)
    file = filename(method)
    op = constraint(:file, :op, constraints) || :update
    AlmaCourseLoader::Writer.write(file, op, reader)
    assert_course_file(file, constraints)
  end
end