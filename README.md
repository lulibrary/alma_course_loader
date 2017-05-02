# AlmaCourseLoader

This gem provides a simple framework for generating Alma course loader files.
It provides a `Reader` class which serves as a basis for iterating over courses
from some data source, and a `Writer` class which uses the `Reader` to generate
a course loader file.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'alma_course_loader'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install alma_course_loader

## Usage

### Reader

The following model is assumed:

* Courses are retrieved by year.

* Courses may optionally consist of a number of cohorts. If this is the case, a
*course element* is a single cohort of a specific course for a specific year. If
not, the course element is the course itself for a specific year.

* Course elements have one or more associated instructors.

`Reader` provides an abstract base class for iterating over course elements read
from any data source. The iterators accept a list of years for which courses are
required. The implementation details of years, courses and cohorts are deferred
to the subclasses.

#### Basic use

```ruby
# Create a reader
reader = Reader.new

# Iterate over course elements
reader.each { |year, course, cohort, instructors| ... }

# Iterate over course elements as rows of the course loader CSV file
reader.each_row { |row| ... }
```

The constructor and iterator methods accept course criteria as arguments.
Positional arguments are years for which courses are required. The `filter`
keyword argument may specify a list of filters to further refine the courses.

Course criteria passed to the constructor are used as defaults for subsequent
iterations. Criteria passed to the iterators override the defaults for that
use only.

```ruby
# Create a reader with default critria
reader = AlmaCourseLoader::Reader.new(2015, 2016, filters: [f1, f2])

# Use the default criteria:
reader.each { |year, course, cohort, instructors| ... }
reader.each_row { |row| ... }

# Override the default years but use the default filters
reader.each(2013) { |year, course, cohort, instructors| ... }

# Override the default years and cancel the default filters
#   the empty filter list is required to cancel the default filters
reader.each(2012, filters: []) { |row| ... }
```

#### Filters

##### Creating a filter

A `Filter` is an object which extracts a value from a course element and
matches it against a known value or set of values. If the match succeeds, the
filter returns `true` and the course element has *passed* the filter. If the
match fails, the filter returns `false` and the course element is rejected.

To create a filter, pass in the value(s) to be matched against, the match
criterion (whether a match is considered a success or failure) and a code
block which extracts the match value from the course element.
```ruby
# Extractor as a code block
filter = AlmaCourseLoader::Filter.new(values, criterion) { |year, course, cohort| ... }

# Extractor as a Proc
extactor = proc { |year, course, cohort| ... }
filter = AlmaCourseLoader::Filter.new(values, criterion, extractor)
```
The match values can be:
* a single value (the values must stringwise match)
* an `Array`, `Hash` or `Set` (the extracted value must be in the values)
* a `Regexp` (the extracted value must match the regular expression)

The match criterion is either:
* `:exclude` (a match is a failure, i.e. the filter succeeds if it
excludes the extracted value)
* `:include` (a match is a success, i.e. the filter succeeds if it includes the
value)

The extractor is a `Proc` or code block which accepts the year, course and
cohort and returns a value to be matched against the filter's values.

##### Examples 
```ruby
codes = ['COMPSCI101', 'MAGIC101']
year1_magic = /MAGIC1\d\d/

# Extractor
get_code = proc { |year, course, cohort| course.code }

# Include only the specified codes
filter = AlmaCourseLoader::Filter.new(codes, :include, get_code)

# Include all except the specified codes
filter = AlmaCourseLoader::Filter.new(codes, :exclude, get_code)

# Include all codes matching the regular expression
filter = AlmaCourseLoader::Filter.new(year1_magic, :include, get_code)
```

##### Executing a filter
Filters provide a `call` method which accepts the year, course and cohort and
returns `true` if the course passes or `false` if it's rejected.

```ruby
if filter.call(year, course, cohort)
  # The course passes, continue processing
else
  # The course is rejected
end
```

##### Using filters with readers
`Reader` constructor and iterator methods accept a list of filters:
```ruby
filter1 = AlmaCourseLoader::Filter.new(...)
filter2 = AlmaCourseLoader::Filter.new(...)
reader = Reader.new(..., filters: [filter1, filter2])
reader.each(..., filters: [filter1]) { ... }
```

Course elements must pass all filters. If any filter fails, the course element
is not passed to the iterator's code block.
 
#### Writing a custom `Reader`

A `Reader` subclass may define any implementation of course, cohort, instructor
and year and must implement the following methods: 

##### `courses(year)`
```ruby
# Returns an array of course objects for the year
def courses
  # A course may be any object defined by the implementation 
end
```

##### `course_cohorts(year, course)`
```ruby
# Returns an array of cohorts for the course, or nil if cohorts are not used
def course_cohorts(year, course)
  # A cohort may be any object defined by the implementation
end
```

##### `current_academic_year`
```ruby
# Returns the current academic year
def current_academic_year
  # A year may be any object defined by the implementation
end
```

##### `instructors(year, course, cohort)`
```ruby
# Returns an array of instructors for the given year, course and cohort
def instructors(year, course, cohort)
  # An instructor may be any object defined by the implementation
end
```

##### `row_data(data, year, course, cohort, instructors)`
```ruby
# Populates the data array for a course element row in the Alma course
# loader CSV file. The data array is pre-allocated by the caller.
def row_data(data, year, course, cohort, instructors)

  # The implementation must define the current course details
  data[0] = 'Current-year-course-code'
  # :
  data[2] = 'Current-year-section-id'

  # The implementation must define the previous year's course code/section
  # These will be ignored by the Writer unless required for rollover
  data[29] = 'Previous-year-course-code'
  data[30] = 'Previous-year-section-id'

end
```

### Writer

The `Writer` class provides a single class-level method `write` which generates
an Alma course loader file given an appropriate `Reader`:

```ruby
Writer.write(output_filename, course_loader_op, reader)
```

The `course_loader_op` is the Alma course loader operation applied to all course
elements provided by the `reader`. This may be:
* `:delete` to delete the courses in the file
* `:rollover` to implement rollover to the courses defined by the file
* `:update` to update the courses in the file

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/alma_course_loader. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

