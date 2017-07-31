require_relative 'test_helper'

# Tests the AlmaCourseLoader::CLI class
class CLITest < Minitest::Test
  include Assertions
  include Constraints
  include Helpers

  FILE = '/tmp/alma_course_loader_cli_%d.csv'.freeze
  FILES = {
    test_cli: 1
  }.freeze

  def test_cli
    args = []
    constraints = default_constraints(:update, use_cohorts: true)
    constraints[:cohort][:except] = %w[2]
    constraints[:course][:except] = %w[CRS103 CRS104 CRS107]
    constraints[:file][:lines] = 22
    constraints[:year][:min] = 2015
    constraints[:year][:max] = 2017
    # Add a filter by cohort
    args.push('-f', 'cohort-2')
    # Add filters by course
    %w[CRS103 CRS104 CRS107].map { |f| args.push('-f', "course-\"#{f}\"") }
    # Add time periods
    [2015, 2016, 2017].map { |t| args.push('-t', t.to_s) }
    # Add the output filename
    file = filename(__callee__, FILE, FILES)
    args.push('-o', file)
    # Run the command
    CourseCLI.run('alma_course_loader', args)
    # Assert the file properties
    assert_course_file(file, constraints)
  end

  def test_cli_help
    assert_output(/Usage:/, '') do
      CourseCLI.run('alma_course_loader', ['--help'])
    end
  end
end