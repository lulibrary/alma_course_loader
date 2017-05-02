$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'alma_course_loader'

require 'minitest/autorun'
require 'minitest/reporters'

Minitest::Reporters.use!

class CourseReader < AlmaCourseLoader::Reader
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