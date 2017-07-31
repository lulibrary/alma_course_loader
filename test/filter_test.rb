require 'alma_course_loader/filter'

require_relative 'test_helper'

# Tests the AlmaCourseLoader::Filter class' parse method
class FilterParseTest < ::Minitest::Test
  ARRAY = ['1', 2, %w[3.1 3.2], { '4.1' => '41', '4.2' => '42' }].freeze
  ARRAY_S = JSON.dump(ARRAY)

  EXTRACTOR_1 = proc { 'extractor 1' }
  EXTRACTOR_2 = proc { 'extractor 2' }
  EXTRACTOR_3 = proc { 'extractor 3' }
  EXTRACTOR_DEFAULT = proc { 'default extractor' }

  EXTRACTORS = {
    ext1: EXTRACTOR_1,
    ext2: EXTRACTOR_2,
    ext3: EXTRACTOR_3
  }.freeze

  EXTRACTORS_WITH_DEFAULT = {
    ext1: EXTRACTOR_1,
    ext2: EXTRACTOR_2,
    ext3: EXTRACTOR_3,
    '' => EXTRACTOR_DEFAULT
  }.freeze

  HASH = { 'f1' => 'v1', 'f2' => 'v2', 'f3' => %w[v31 v32] }.freeze
  HASH_S = JSON.dump(HASH)

  def setup
    @ext = EXTRACTORS
    @extd = EXTRACTORS_WITH_DEFAULT
  end

  def test_empty
    assert_raises_msg('expected filter') { AlmaCourseLoader::Filter.parse('') }
  end

  def test_nil
    assert_raises_msg('expected filter') { AlmaCourseLoader::Filter.parse }
  end

  def test_extractor_exclude
    filter_s = 'ext1-"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_1, :exclude, 'valid JSON', filter)
    filter_s = 'ext2-"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_2, :exclude, 'valid JSON', filter)
    filter_s = 'ext3-"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_3, :exclude, 'valid JSON', filter)
  end

  def test_extractor_include
    filter_s = 'ext1+"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_1, :include, 'valid JSON', filter)
    filter_s = 'ext2+"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_2, :include, 'valid JSON', filter)
    filter_s = 'ext3+"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_3, :include, 'valid JSON', filter)
  end

  def test_extractor_invalid
    filter_s = 'noext-"valid JSON"'
    msg = 'invalid extractor: noext'
    assert_raises_msg(msg) { AlmaCourseLoader::Filter.parse(filter_s, @extd) }
  end

  def test_no_default_extractor
    filter_s = '"valid JSON"'
    msg = 'no default extractor'
    assert_raises_msg(msg) { AlmaCourseLoader::Filter.parse(filter_s, @ext) }
  end

  def test_no_extractors
    filter_s = '"valid JSON"'
    msg = 'extractors required'
    assert_raises_msg(msg) { AlmaCourseLoader::Filter.parse(filter_s) }
  end

  def test_value_array
    filter_s = ARRAY_S
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_DEFAULT, :include, ARRAY, filter)
  end

  def test_value_hash
    filter_s = HASH_S
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_DEFAULT, :include, HASH, filter)
  end

  def test_value_invalid
    filter_s = 'invalid JSON'
    msg = "invalid value: #{filter_s}"
    assert_raises_msg(msg) do
      AlmaCourseLoader::Filter.parse(filter_s, @extd)
    end
  end

  def test_value_mode
    filter_s = '+"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_DEFAULT, :include, 'valid JSON', filter)
    filter_s = '-"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_DEFAULT, :exclude, 'valid JSON', filter)
  end

  def test_value_string
    filter_s = '"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, @extd)
    assert_filter(EXTRACTOR_DEFAULT, :include, 'valid JSON', filter)
  end

  private

  def assert_filter(extractor, mode, values, filter)
    assert_equal extractor, filter.extractor
    assert_equal mode, filter.mode
    assert_equal values, filter.values
  end

  def assert_raises_msg(msg = nil, exception = ArgumentError, &block)
    err = assert_raises(exception, &block)
    assert_equal msg, err.message unless msg.nil?
  end
end