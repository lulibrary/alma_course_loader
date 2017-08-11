require_relative 'test_helper'

# Tests the AlmaCourseLoader::CLI class
class CourseLoaderCLITest < Minitest::Test
  include Assertions
  include Constraints
  include Helpers

  FILE = '/tmp/alma_course_loader_cli_%d.csv'.freeze
  FILES = {
    test_cli: 1
  }.freeze

  def test_cli
    # Get the output filename
    file = filename(__callee__, FILE, FILES)
    # Run the command
    ex = assert_raises(SystemExit) do
      CourseCLI.run('alma_course_loader', args_test_cli(file))
    end
    # Check the exit status
    assert ex.success? unless ex.nil?
    # Assert the file properties
    assert_course_file(file, constraints_test_cli)
  end

  def test_cli_help
    assert_output(/Usage:/, '') do
      CourseCLI.run('alma_course_loader', ['--help'])
    end
  end

  private

  def args_test_cli(file)
    args = []
    # Add a filter by cohort
    args.push('-f', 'cohort-/-2015-2$/')
    # Add filters by course
    args.push('-f', 'course-["CRS103-2016", "CRS104-2016", "CRS107-2016"]')
    # Add time periods
    [2015, 2016, 2017].map { |t| args.push('-t', t.to_s) }
    # Add the output filename
    args.push('-o', file)
    args
  end

  def constraints_test_cli
    constraints = default_constraints(:update, use_cohorts: true)
    constraints[:cohort][:except] = %w[
      CRS101-2015-2 CRS102-2015-2 CRS103-2015-2 CRS104-2015-1 CRS104-2015-2
      CRS105-2015-2 CRS106-2015-2 CRS107-2015-2 CRS108-2015-2 CRS109-2015-2
      CRS110-2015-2 CRS103-2016-1 CRS103-2016-2 CRS104-2016-1 CRS104-2016-2
      CRS107-2016-1 CRS107-2016-2
    ]
    constraints[:course][:except] = %w[CRS103-2016 CRS104-2016 CRS107-2016]
    constraints[:file][:lines] = 45
    constraints[:year][:min] = 2015
    constraints[:year][:max] = 2017
    constraints
  end
end