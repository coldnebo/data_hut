# run from the samples dir with: 
# $ rake samples
# $ ruby police_reports.rb 

require_relative 'common/sample_helper.rb'

require 'data_hut'
require 'nokogiri'
require 'open-uri'
require 'pry'

# fix for open-uri, uri with pipes: http://stackoverflow.com/a/5287528/555187
URI::DEFAULT_PARSER = URI::Parser.new(:UNRESERVED => URI::REGEXP::PATTERN::UNRESERVED + '|')

url = "http://www.reddit.com/r/science.rss"

doc = Nokogiri::XML(open(url))

dh = DataHut.connect("rscience")

puts "extracting latest articles"
dh.extract(doc.xpath('//item')) do |r, item|

  # extract the guid and skip processing this record if the guid is already in the dataset.
  guid = item.xpath('guid').text
  next if dh.not_unique(guid: guid)

  # otherwise, extract the record
  r.guid = guid
  r.title = item.xpath('title').text
  r.pub_date = DateTime.parse(item.xpath('pubDate').text)

  description = item.xpath('description').text
  ddoc = Nokogiri::XML.fragment(description)
  r.user = ddoc.xpath('a[contains(@href,"reddit.com/user")]').text.strip
  r.article_url = ddoc.xpath('a[contains(text(),"link")]').attribute("href").value

  # fetch the actual article body
  adoc = Nokogiri::HTML(open(r.article_url))
  # get rid of the nontext items
  adoc.xpath('//script').remove
  adoc.xpath('//form').remove
  adoc.xpath('//style').remove
  adoc.xpath('//comment()').remove

  r.article_body = adoc.text
  print '.'
end


dh.transform(true) do |r|
  topic = case r.article_body
    when /physic/ then "physics" 
    when /biolog/ then "biology"
    when /astronom/ then "astronomy"
    when /chemist/ then "chemistry"
    when /engineer/ then "engineering"
    else 'unclassified'
  end
  #binding.pry
  r.topic = topic
end

dh.transform_complete


ds = dh.dataset


puts ds.where(topic: "unclassified").collect {|e| e.title}.join("\n")

puts "unclassified:"
puts ds.where(topic: "unclassified").count

binding.pry

puts "done."
