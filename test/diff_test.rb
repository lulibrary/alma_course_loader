require 'alma_course_loader/cli/diff'
require 'alma_course_loader/diff'

require_relative 'test_helper'

# Helper assertions for Diff tests
module Assertions
  OPS = %i[create delete update].freeze

  def assert_block_params(old, new, op, _opts)
    assert_includes OPS, op
    if op == :create
      # Created entries should only have a new entry
      assert_nil old
      refute_nil new
    else
      # Deleted and updated entries should have an old entry
      refute_nil old
      # Deleted entries should not have an old entry
      assert_nil new if op == :delete
      # Updated entries should have both old and new entries
      refute_nil new if op == :update
    end
  end

  def assert_file(file, op, expected, rollover = false)
    File.readlines(file).each do |line|
      line.chomp!
      fields = line.split("\t")
      # Check that the course is expected
      assert_file_course(fields, op, expected)
      # Check that the operation is expected
      assert_file_op(fields, op, rollover)
    end
    # Check that all expected course codes have been handled
    assert_empty expected[op]
  end

  def assert_file_course(fields, op, expected)
    # Check that the course code is expected
    assert_includes expected[op], fields[0]
    # Remove the course from the expected list
    expected[op].delete(fields[0])
  end

  def assert_file_op(fields, op, rollover = false)
    if op == :create
      assert_file_op_create(fields, op, rollover)
    else
      assert_file_op_delete_update(fields, op)
    end
  end

  def assert_file_op_create(fields, op, rollover = false)
    if rollover
      # New courses should be rollovers if rollover course/section are present
      # or updates if not
      if can_rollover?(fields)
        # can_rollover? guarantees that fields[29] and fields[30] are not empty
        assert_equal 'ROLLOVER', fields[28]
      else
        assert_file_op_delete_update(fields, :update)
      end
    else
      # New courses should be updates with no op or previous course details
      assert_file_op_delete_update(fields, op)
    end
  end

  def assert_file_op_delete_update(fields, op)
    assert_equal op == :delete ? 'DELETE' : '', fields[28] || ''
    assert fields[29].nil? || fields[29].empty?
    assert fields[30].nil? || fields[30].empty?
  end

  def assert_files(files, expected = nil, verbose = false, rollover = false)
    assert_log(files[:log], verbose, expected[:log]) if files[:log]
    files.each do |op, file|
      assert_file(file, op, expected, rollover) unless op == :log
    end
  end

  def assert_log(file, verbose, expected)
    action = nil
    course = nil
    File.readlines(file).each do |line|
      action, course = assert_log_entry(line, verbose, expected, action, course)
    end
    assert_empty expected, "Unexpected log entries: #{expected}"
  end

  def assert_log_action(fields, expected)
    action, course = fields[2..3]
    assert_includes expected, action, "Unknown action: #{action}"
    assert_includes expected[action], course,
                    "Unexpected #{action.downcase} for #{course}"
    expected[action].delete(course)
    expected.delete(action) if expected[action].empty?
    [action, course]
  end

  def assert_log_entry(line, verbose, expected, action = nil, course = nil)
    fields = line.chomp.split
    if '<>'.include?(fields[0])
      assert_log_verbose(fields, verbose, action, course)
    elsif fields[0] != '#' # Ignore the header comment added by the logger
      action, course = assert_log_action(fields, expected)
    end
    [action, course]
  end

  def assert_log_verbose(fields, verbose, action, _course)
    assert verbose
    flag = fields[0]
    refute_equal '<', flag, 'Unexpected < for Create' if action == 'Create'
    refute_equal '>', flag, 'Unexpected > for Delete' if action == 'Delete'
  end

  def can_rollover?(fields)
    return false if fields[29].nil? || fields[29].empty?
    return false if fields[30].nil? || fields[30].nil?
    true
  end
end

# Tests the Diff class
class DiffTest < Minitest::Test
  include Assertions

  def setup
    log = { 'Create' => %w[CRS210-2017:1 CRS211-2017:1],
            'Delete' => %w[CRS110-2017:1], 'Update' => %w[CRS103-2017:1] }
    @expected = { create: %w[CRS210-2017 CRS211-2017], delete: %w[CRS110-2017],
                  log: log, update: %w[CRS103-2017] }
    @files = { create: 'test/fixtures/diff_test_create.csv',
               delete: 'test/fixtures/diff_test_delete.csv', log: nil,
               update: 'test/fixtures/diff_test_update.csv' }
    @new = 'test/fixtures/diff_test_new.csv'
    @old = 'test/fixtures/diff_test_old.csv'
  end

  def test_diff
    # Diff the files
    block_called = false
    ::AlmaCourseLoader::Diff.diff(@old, @new, **@files) do |old, new, op, opts|
      block_called = true
      assert_block_params(old, new, op, opts)
    end
    # Check that the block was called
    assert block_called
    # Check the output files
    assert_files(@files, @expected)
  ensure
    # Cleanup
    delete_files(@files)
  end

  # Tests the diff when new courses are created without rollover
  def test_diff_cli_update
    diff_cli('.1')
  end

  # Tests the diff when new courses are created with rollover
  def test_diff_cli_rollover
    diff_cli('.2', true)
  end

  def test_diff_cli_help
    assert_output(/Usage:/, '') do
      ::AlmaCourseLoader::CLI::Diff.run('course_loader_diff', ['--help'])
    end
  end

  private

  def cli_args(files, rollover = false)
    result = [
      '-c', files[:create],
      '-d', files[:delete],
      '-l', files[:log],
      '-u', files[:update],
      '-v',
      @old, @new
    ]
    result.insert(0, '-r') if rollover
    result
  end

  def cli_files(suffix)
    {
      create: "#{@files[:create]}#{suffix}",
      delete: "#{@files[:delete]}#{suffix}",
      log: "test/fixtures/diff#{suffix}.log",
      update: "#{@files[:update]}#{suffix}"
    }
  end

  def delete_files(files = nil)
    files.each_value do |file|
      begin
        File.delete(file) if file
      rescue Errno::ENOENT
        # Ignore file-not-found errors
      end
    end
  end

  def diff_cli(suffix, rollover = false)
    # Get the output files
    files = cli_files(suffix)
    # Run the command
    args = cli_args(files, rollover)
    ex = assert_raises(SystemExit) do
      ::AlmaCourseLoader::CLI::Diff.run('course_loader_diff', args)
    end
    # The command should raise a successful SystemExit exception
    assert ex.success? unless ex.nil?
    # Check the output files
    assert_files(files, diff_cli_expected(rollover), true, rollover)
  ensure
    # Cleanup
    delete_files(files)
  end

  def diff_cli_expected(rollover = false)
    return @expected unless rollover
    # CRS210 should be created as an update when create-as-rollover is enabled
    result = @expected.clone
    result[:create].push('CRS210-2017')
    result[:log]['Create'].push('CRS210-2017:1')
    result
  end
end