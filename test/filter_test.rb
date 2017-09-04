require 'alma_course_loader/filter'

require_relative 'test_helper'

# The base class for filter parsing test classes
class FilterParseTestBase < ::Minitest::Test
  ARRAY = ['extractor 1', 'extractor 2'].freeze
  ARRAY_S = JSON.dump(ARRAY)

  EXTRACTOR_1 = proc { |_year, _course, _cohort| 'extractor 1' }
  EXTRACTOR_2 = proc { |_year, _course, _cohort| 'extractor 2' }
  EXTRACTOR_3 = proc { |_year, _course, _cohort| 'extractor 3' }
  EXTRACTOR_DEFAULT = proc { |_year, _course, _cohort| 'default extractor' }

  EXTRACTORS = {
    ext1: EXTRACTOR_1,
    ext2: EXTRACTOR_2,
    ext3: EXTRACTOR_3
  }.freeze

  EXTRACTORS_WITH_DEFAULT = {
    ext1: EXTRACTOR_1,
    ext2: EXTRACTOR_2,
    ext3: EXTRACTOR_3,
    nil => EXTRACTOR_DEFAULT
  }.freeze

  HASH = {
    'extractor 1' => 'v1',
    'extractor 2' => 'extractor 3'
  }.freeze
  HASH_S = JSON.dump(HASH)

  def assert_filter(extractor, method, values, negate, filter)
    assert_equal extractor, filter.extractor
    assert_equal method, filter.method
    assert_equal negate, filter.negate
    assert_equal values, filter.values
  end

  def assert_raises_msg(msg = nil, exception = ArgumentError, &block)
    err = assert_raises(exception, &block)
    assert_equal msg, err.message unless msg.nil?
  end
end

# Tests filter parsing error conditions
class FilterParseErrorTest < FilterParseTestBase
  def test_empty
    assert_raises_msg('expected filter') { AlmaCourseLoader::Filter.parse('') }
  end

  def test_extractor_invalid
    filter_s = 'noext != "valid JSON"'
    msg = 'invalid extractor: noext'
    assert_raises_msg(msg) do
      AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    end
  end

  def test_nil
    assert_raises_msg('expected filter') { AlmaCourseLoader::Filter.parse }
  end

  def test_no_default_extractor
    filter_s = '"valid JSON"'
    msg = 'no default extractor'
    assert_raises_msg(msg) do
      AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS)
    end
  end

  def test_no_extractors
    filter_s = '"valid JSON"'
    msg = 'extractors required'
    assert_raises_msg(msg) { AlmaCourseLoader::Filter.parse(filter_s) }
  end

  def test_value_invalid_json
    filter_s = 'invalid JSON'
    msg = "invalid value: #{filter_s}"
    assert_raises_msg(msg) do
      AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    end
  end

  def test_value_invalid_regexp
    filter_s = '/[/'
    msg = "invalid regular expression: #{filter_s}"
    assert_raises_msg(msg) do
      AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    end
  end
end

# Tests filter equality conditions
class FilterParseEqualityTest < FilterParseTestBase
  def test_equal_true
    filter_s = 'ext1 == "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :==, 'extractor 1', false, filter)
    assert filter.call
  end

  def test_equal_false
    filter_s = 'ext2 == "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :==, 'extractor 1', false, filter)
    refute filter.call
  end

  def test_not_equal_true
    filter_s = '! ext1 == "extractor 2"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :==, 'extractor 2', true, filter)
    assert filter.call
  end

  def test_not_equal_false
    filter_s = '! ext1 == "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :==, 'extractor 1', true, filter)
    refute filter.call
  end

  def test_not_unequal_true
    filter_s = '! ext1 != "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :!=, 'extractor 1', true, filter)
    assert filter.call
  end

  def test_not_unequal_false
    filter_s = '! ext1 != "extractor 2"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :!=, 'extractor 2', true, filter)
    refute filter.call
  end

  def test_unequal_true
    filter_s = 'ext1 != "extractor 2"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :!=, 'extractor 2', false, filter)
    assert filter.call
  end

  def test_unequal_false
    filter_s = 'ext1 != "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :!=, 'extractor 1', false, filter)
    refute filter.call
  end
end

# Tests filter greater-than conditions
class FilterParseGreaterThanTest < FilterParseTestBase
  def test_gt_true
    filter_s = 'ext2 > "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :<, 'extractor 1', false, filter)
    assert filter.call
  end

  def test_gt_false
    filter_s = 'ext1 > "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :<, 'extractor 1', false, filter)
    refute filter.call
  end

  def test_gte_true
    filter_s = 'ext2 >= "extractor 2"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :<=, 'extractor 2', false, filter)
    assert filter.call
  end

  def test_gte_false
    filter_s = 'ext1 >= "extractor 2"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :<=, 'extractor 2', false, filter)
    refute filter.call
  end

  def test_not_gt_true
    filter_s = '! ext2 > "extractor 3"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :<, 'extractor 3', true, filter)
    assert filter.call
  end

  def test_not_gt_false
    filter_s = '! ext2 > "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :<, 'extractor 1', true, filter)
    refute filter.call
  end

  def test_not_gte_true
    filter_s = '! ext2 >= "extractor 3"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :<=, 'extractor 3', true, filter)
    assert filter.call
  end

  def test_not_gte_false
    filter_s = '! ext2 >= "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :<=, 'extractor 1', true, filter)
    refute filter.call
  end
end

# Tests filter include conditions
class FilterParseIncludeTest < FilterParseTestBase
  def test_include_array_true
    filter_s = "ext1 in #{ARRAY_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :include?, ARRAY, false, filter)
    assert filter.call
  end

  def test_include_array_false
    filter_s = "ext3 in #{ARRAY_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_3, :include?, ARRAY, false, filter)
    refute filter.call
  end

  def test_include_hash_true
    filter_s = "ext1 in #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :include?, HASH, false, filter)
    assert filter.call
  end

  def test_include_hash_false
    filter_s = "ext3 in #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_3, :include?, HASH, false, filter)
    refute filter.call
  end

  def test_not_include_array_true
    filter_s = "! ext3 in #{ARRAY_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_3, :include?, ARRAY, true, filter)
    assert filter.call
  end

  def test_not_include_array_false
    filter_s = "! ext1 in #{ARRAY_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :include?, ARRAY, true, filter)
    refute filter.call
  end

  def test_not_include_hash_true
    filter_s = "! ext3 in #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_3, :include?, HASH, true, filter)
    assert filter.call
  end

  def test_not_include_hash_false
    filter_s = "! ext2 in #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :include?, HASH, true, filter)
  end
end

# Tests filter keyin conditions
class FilterParseKeyInTest < FilterParseTestBase
  def test_keyin_array
    assert_raises_msg('invalid method: Array#key?') do
      filter_s = "ext1 keyin #{ARRAY_S}"
      AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    end
  end

  def test_keyin_hash_true
    filter_s = "ext1 keyin #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :key?, HASH, false, filter)
    assert filter.call
  end

  def test_keyin_hash_false
    filter_s = "ext3 keyin #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_3, :key?, HASH, false, filter)
    refute filter.call
  end

  def test_not_keyin_array
    assert_raises_msg('invalid method: Array#key?') do
      filter_s = "! ext1 keyin #{ARRAY_S}"
      AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    end
  end

  def test_not_keyin_hash_true
    filter_s = "! ext3 keyin #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_3, :key?, HASH, true, filter)
    assert filter.call
  end

  def test_not_keyin_hash_false
    filter_s = "! ext2 keyin #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :key?, HASH, true, filter)
    refute filter.call
  end
end

# Tests filter less-than conditions
class FilterParseLessThanTest < FilterParseTestBase
  def test_lt_true
    filter_s = 'ext2 < "extractor 3"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :>, 'extractor 3', false, filter)
    assert filter.call
  end

  def test_lt_false
    filter_s = 'ext2 < "extractor 2"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :>, 'extractor 2', false, filter)
    refute filter.call
  end

  def test_lte_true
    filter_s = 'ext2 <= "extractor 3"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :>=, 'extractor 3', false, filter)
    assert filter.call
  end

  def test_lte_false
    filter_s = 'ext2 <= "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :>=, 'extractor 1', false, filter)
    refute filter.call
  end

  def test_not_lt_true
    filter_s = '! ext2 < "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :>, 'extractor 1', true, filter)
    assert filter.call
  end

  def test_not_lt_false
    filter_s = '! ext2 < "extractor 3"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :>, 'extractor 3', true, filter)
    refute filter.call
  end

  def test_not_lte_true
    filter_s = '! ext2 <= "extractor 1"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :>=, 'extractor 1', true, filter)
    assert filter.call
  end

  def test_not_lte_false
    filter_s = '! ext2 <= "extractor 3"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :>=, 'extractor 3', true, filter)
    refute filter.call
  end
end

# Tests filter regular expression match conditions
class FilterParseMatchTest < FilterParseTestBase
  def test_match_true
    regexp_s = '[Ee].*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "ext1 ~ /#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :match, regexp, false, filter)
    assert filter.call
  end

  def test_match_false
    regexp_s = 'E.*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "ext1 ~ /#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :match, regexp, false, filter)
    refute filter.call
  end

  def test_no_match_true
    regexp_s = 'E.*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "ext1 !~ /#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :match, regexp, true, filter)
    assert filter.call
  end

  def test_no_match_false
    regexp_s = '[Ee].*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "ext1 !~ /#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :match, regexp, true, filter)
    refute filter.call
  end

  def test_not_no_match_true
    regexp_s = '[Ee].*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "! ext1 !~ /#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :match, regexp, false, filter)
    assert filter.call
  end

  def test_not_no_match_false
    regexp_s = 'E.*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "! ext1 !~ /#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :match, regexp, false, filter)
    refute filter.call
  end

  def test_not_match_true
    regexp_s = 'E.*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "! ext1 ~ /#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :match, regexp, true, filter)
    assert filter.call
  end

  def test_not_match_false
    regexp_s = '[Ee].*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "! ext1 ~ /#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_1, :match, regexp, true, filter)
    refute filter.call
  end
end

# Tests filter valuein conditions
class FilterParseValueInTest < FilterParseTestBase
  def test_not_valuein_array
    assert_raises_msg('invalid method: Array#value?') do
      filter_s = "! ext1 valuein #{ARRAY_S}"
      AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    end
  end

  def test_not_valuein_hash_true
    filter_s = "! ext2 valuein #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :value?, HASH, true, filter)
    assert filter.call
  end

  def test_not_valuein_hash_false
    filter_s = "! ext3 valuein #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_3, :value?, HASH, true, filter)
    refute filter.call
  end

  def test_valuein_array
    assert_raises_msg('invalid method: Array#value?') do
      filter_s = "ext1 valuein #{ARRAY_S}"
      AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    end
  end

  def test_valuein_hash_true
    filter_s = "ext3 valuein #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_3, :value?, HASH, false, filter)
    assert filter.call
  end

  def test_valuein_hash_false
    filter_s = "ext2 valuein #{HASH_S}"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_2, :value?, HASH, false, filter)
    refute filter.call
  end
end

# Tests value-only filters (no extractors)
class FilterParseValueOnlyTest < FilterParseTestBase
  def test_value_array
    filter_s = ARRAY_S
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_DEFAULT, :include?, ARRAY, false, filter)
  end

  def test_value_hash
    filter_s = HASH_S
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_DEFAULT, :include?, HASH, false, filter)
  end

  def test_value_mode
    filter_s = '"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_DEFAULT, :==, 'valid JSON', false, filter)
    filter_s = '!"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_DEFAULT, :==, 'valid JSON', true, filter)
  end

  def test_value_regexp
    regexp_s = '[Ee].*[\d]'
    regexp = Regexp.new(regexp_s)
    filter_s = "/#{regexp_s}/"
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_DEFAULT, :match, regexp, false, filter)
  end

  def test_value_string
    filter_s = '"valid JSON"'
    filter = AlmaCourseLoader::Filter.parse(filter_s, EXTRACTORS_WITH_DEFAULT)
    assert_filter(EXTRACTOR_DEFAULT, :==, 'valid JSON', false, filter)
  end
end