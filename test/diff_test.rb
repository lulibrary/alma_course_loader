require 'alma_course_loader/cli/diff'
require 'alma_course_loader/diff'

require_relative 'test_helper'

# Tests the Diff class
class DiffTest < Minitest::Test
  def setup
    @in_new = 'test/fixtures/diff_test_new.csv'
    @in_old = 'test/fixtures/diff_test_old.csv'
    @out_delete = 'test/fixtures/diff_test_delete.csv'
    @out_log = 'test/fixtures/diff_test_cli.log'
    @out_update = 'test/fixtures/diff_test_update.csv'
    @expected = { delete: %w[CRS110-2017], update: %w[CRS103-2017 CRS210-2017] }
    @expected_log = { 'Delete' => %w[CRS110-2017:1], 'New' => %w[CRS210-2017:1],
                      'Update' => %w[CRS103-2017:1] }
  end

  def test_diff
    # Pre-test cleanup
    delete_out_files
    # Diff the files
    block_called = false
    ::AlmaCourseLoader::Diff.diff(@in_old, @in_new,
                                  delete: @out_delete, update: @out_update) \
    do |old, new, op|
      block_called = true
      assert_block_params(old, new, op)
    end
    # Check that the block was called
    assert block_called
    # Check the output files
    assert_file(@out_delete, :delete, @expected)
    assert_file(@out_update, :update, @expected)
  ensure
    # Cleanup
    delete_out_files
  end

  def test_diff_cli
    # Output filenames
    out_delete = "#{@out_delete}.cli"
    out_update = "#{@out_update}.cli"
    out_files = [out_delete, @out_log, out_update]
    # Pre-test cleanup
    delete_out_files(*out_files)
    # Run the command
    args = ['-d', out_delete, '-l', @out_log, '-u', out_update, '-v',
            @in_old, @in_new]
    regexp = /Update CRS103-2017:1.*?Delete CRS110-2017:1.*?New CRS210-2017:1/
    ex = assert_raises(SystemExit) do
      ::AlmaCourseLoader::CLI::Diff.run('course_loader_diff', args)
    end
    # Check the exit status
    assert ex.success? unless ex.nil?
    # Check the output files
    assert_file(out_delete, :delete, @expected)
    assert_file(out_update, :update, @expected)
    # Check the log file
    assert_log(@out_log, true, @expected_log)
  ensure
    # Cleanup
    delete_out_files(*out_files)
  end

  def test_diff_cli_help
    assert_output(/Usage:/, '') do
      ::AlmaCourseLoader::CLI::Diff.run('course_loader_diff', ['--help'])
    end
  end

  private

  def assert_block_params(old, new, op)
    assert_includes %i[delete new update], op
    if op == :delete
      refute_nil old
      assert_nil new
    elsif op == :new
      assert_nil old
      refute_nil new
    else
      refute_nil old
      refute_nil new
    end
  end

  def assert_file(file, op, expected)
    File.readlines(file).each do |line|
      line.chomp!
      fields = line.split("\t")
      # Check that the course is expected
      assert_file_course(fields, op, expected)
      # Check that the operation is expected
      assert_file_op(fields, op)
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

  def assert_file_op(fields, op)
    if op == :delete
      assert_equal fields[28], 'DELETE'
    else
      assert fields[28].nil? || fields[28] == ''
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
    action = fields[2]
    course = fields[3]
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
    refute_equal '<', flag, 'Unexpected < for New' if action == 'New'
    refute_equal '>', flag, 'Unexpected > for Delete' if action == 'Delete'
  end

  def delete_out_files(*files)
    files = [@out_delete, @out_log, @out_update] if files.nil? || files.empty?
    files.each do |file|
      begin
        File.delete(file)
      rescue Errno::ENOENT
        # Ignore file-not-found errors
      end
    end
  end
end