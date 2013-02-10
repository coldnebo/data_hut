
# run from the samples dir with:
# $ ruby basic.rb 

require_relative 'sample_helper.rb'

require 'data_hut'
require 'pry'

dh = DataHut.connect("sample")

data = [{name: "barney", age: 27, login: DateTime.parse('2008-05-03') },
        {name: "phil", age: 31},
        {name: "fred", age: 44, login: DateTime.parse('2013-02-07')},
        {name: "sarah", age: 24, login: DateTime.parse('2011-04-01')},
        {name: "robin", age: 45},
        {name: "jane", age: 19, login: DateTime.parse('2012-10-14')}]

# extract your data by iterating over your data format (from whatever source) and map it to a record model...
puts "extracting data"
dh.extract(data) do |r, d|
  r.name = d[:name]
  r.age = d[:age]
  # data quality step:
  d[:login] = DateTime.new unless d.has_key?(:login)
  r.last_active = d[:login]
  print '.'
end

# and only transform the new records automatically
puts "\ntransforming data"
dh.transform do |r|
  r.eligible = r.age < 30
  print '*'
end

dh.transform_complete
puts "\ndone."

# operate on your dataset by using chained queries
ds = dh.dataset

ds.each{|d| puts d.inspect}

puts "Average age: #{ds.avg(:age)}"

puts "Eligible:"
eligible = ds.where(eligible:true)
eligible.each{|d| puts d.inspect}

binding.pry

# clean up scratch demo
FileUtils.rm("sample.db")
puts "done."