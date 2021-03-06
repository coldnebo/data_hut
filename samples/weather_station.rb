
# run from the samples dir with: 
# $ rake samples
# $ ruby weather_station.rb 

require_relative 'common/sample_helper.rb'

require 'data_hut'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'haml'


def generate_report(ds)
  @title      = "Boston Weather Forecast"
  @h1         = "Forecasted Temperatures Report for Boston, MA, USA"
  @data       = ds.order(:start_time).all.to_json
  @css        = File.read("weather_files/weather.css")
  @js         = File.read("weather_files/weather.js")
  engine      = Haml::Engine.new(File.read("common/report.html.haml"))
  report_name = "output/weather_report.html"
  FileUtils.mkdir("output") unless Dir.exists?("output")
  File.open(report_name, "w") do |f|
    f.puts engine.render(self)
  end

  puts "rendered '#{report_name}'. open in your favorite browser."
end


# boston weather forecast for the next 7 days
url = 'http://forecast.weather.gov/MapClick.php?lat=42.35830&lon=-71.06030&FcstType=digitalDWML'

doc = Nokogiri::HTML(open(url))

# the data in this format is laid out in parallel arrays.
start_times = doc.xpath('//time-layout/start-valid-time').collect{|n| DateTime.parse(n.text)}
end_times = doc.xpath('//time-layout/end-valid-time').collect{|n| DateTime.parse(n.text)}
# in F'
temperatures = doc.xpath('//temperature[@type="hourly"]/value').collect{|n| n.text.to_f}
dew_points = doc.xpath('//temperature[@type="dew point"]/value').collect{|n| n.text.to_f}
wind_chills = doc.xpath('//temperature[@type="wind chill"]/value').collect{|n| n.text.to_f}

dh = DataHut.connect("weather")

dh.extract((0..start_times.count-1)) do |r, i|
  r.start_time = start_times[i]
  r.end_time = end_times[i]
  r.temperature = temperatures[i]
  r.dew_point = dew_points[i]
  r.wind_chill = wind_chills[i]
end

ds = dh.dataset

generate_report(ds)

binding.pry

puts "done."
