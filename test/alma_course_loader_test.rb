require 'alma_course_loader'

require 'test_helper'

# Base class for test classes
class AlmaCourseLoaderTest < ::Minitest::Test
  include Assertions
  include Constraints
  include Helpers

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

  # Writes a course loader file and asserts its properties
  def write_file(method, reader, constraints)
    file = filename(method, FILE, FILES)
    op = constraint(:file, :op, constraints) || :update
    AlmaCourseLoader::Writer.write(file, op, reader)
    assert_course_file(file, constraints)
  end
end