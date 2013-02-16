# DataHut

A small, portable data warehouse for Ruby for analytics on anything!

DataHut has basic features for small one-off analytics like parsing error logs and such.  Like its bigger cousin (the Data Warehouse) it has support for *extract*, *transform* and *load* processes (ETL).  Unlike its bigger cousin it is simple to setup and use for simple projects.

*Extract* your data from anywhere, *transform* it however you like and *analyze* it for insights!

<img src="https://raw.github.com/coldnebo/data_hut/master/samples/weather_files/screenshot.png" width="70%"/>  
*from [samples/weather_station.rb](https://github.com/coldnebo/data_hut/blob/master/samples/weather_station.rb)*


## Installation

Add this line to your application's Gemfile:

    gem 'data_hut'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install data_hut

## Usage

Setting up a datahut is easy...

    require 'data_hut'
    require 'pry'

    dh = DataHut.connect("scratch")

    data = [{name: "barney", age: 27},
            {name: "phil", age: 31},
            {name: "fred", age: 44}]

    # extract your data by iterating over your data format (from whatever source) and map it to a record model...
    dh.extract(data) do |r, d|
      r.name = d[:name]
      r.age = d[:age]
    end

    # transform your data by adding fields to it
    dh.transform do |r|
      r.eligible = r.age < 30
    end

    # operate on your dataset by using chained queries
    ds = dh.dataset

    binding.pry

DataHut provides access to the underlying [Sequel::Dataset](http://sequel.rubyforge.org/rdoc/classes/Sequel/Dataset.html) using
a Sequel::Model binding.  This allows you to query individual fields and stats from the dataset, but also returns rows as objects that are accessed with the same uniform object syntax you used for extracting and transforming... i.e.:

    [1] pry(main)> person = ds.first
    [2] pry(main)> [person.name, person.age]
    => ["barney", 27]

And here's some of the other powerful things you can do with a Sequel::Dataset:

    [2] pry(main)> ds.where(eligible: false).count
    => 2
    [3] pry(main)> ds.avg(:age)
    => 34.0
    [4] pry(main)> ds.max(:age)
    => 44
    [5] pry(main)> ds.min(:age)
    => 27

But wait, you can also name these collections:

    [6] pry(main)> ineligible = ds.where(eligible: false)
    => #<Sequel::SQLite::Dataset: "SELECT * FROM `data_warehouse` WHERE (`eligible` = 'f')">

    [26] pry(main)> ineligible.avg(:age)
    => 37.5
    [24] pry(main)> ineligible.order(Sequel.desc(:age)).all
    => [#< @values={:dw_id=>3, :name=>"fred", :age=>44, :eligible=>false}>,
     #< @values={:dw_id=>2, :name=>"phil", :age=>31, :eligible=>false}>]

The results are always Sequel::Model objects, so you can access them with object notation:

    [32] pry(main)> record = ineligible.order(Sequel.desc(:age)).first
    => #< @values={:dw_id=>3, :name=>"fred", :age=>44, :eligible=>false}>
    [33] pry(main)> record.name
    => "fred"
    [34] pry(main)> record.age
    => 44


Read more about the [Sequel gem](http://sequel.rubyforge.org/rdoc/files/README_rdoc.html) to determine what operations you can perform on a DataHut dataset.

## A More Ambitious Example...

Taking a popular game like League of Legends and hand-rolling some simple analysis of the champions...

<script src="http://gist-it.appspot.com/github/coldnebo/data_hut/raw/master/samples/league_of_legends.rb"></script>

Now that we have some data, lets play...

* who has the most base damage?

        [1] pry(main)> ds.order(Sequel.desc(:damage)).limit(5).collect{|c| {c.name => c.damage}}
        => [{"Taric"=>58.0},
         {"Maokai"=>58.0},
         {"Warwick"=>56.76},
         {"Singed"=>56.65},
         {"Poppy"=>56.3}]


* but wait a minute... what about at level 18?  Fortunately, we've transformed our data to add some extra fields for this...

        [2] pry(main)> ds.order(Sequel.desc(:total_damage)).limit(5).collect{|c| {c.name => c.total_damage}}
        => [{"Skarner"=>129.70000000000002},
         {"Cho'Gath"=>129.70000000000002},
         {"Kassadin"=>122.5},
         {"Taric"=>121.0},
         {"Alistar"=>120.19}]

* how about using some of the indexes we defined above... like the 'nuke_index' (notice that the assumptions on what make a good
nuke are subjective, but that's the fun of it; we can model our assumptions and see how the data changes in response.)

        [3] pry(main)> ds.order(Sequel.desc(:nuke_index)).limit(5).collect{|c| {c.name => [c.total_damage, c.total_move_speed, c.total_mana, c.ability_power]}}
        => [{"Karthus"=>[100.7, 335.0, 1368.0, 10]},
         {"Morgana"=>[114.58, 335.0, 1320.0, 9]},
         {"Ryze"=>[106.0, 335.0, 1240.0, 10]},
         {"Karma"=>[109.4, 335.0, 1320.0, 9]},
         {"Lux"=>[109.4, 340.0, 1150.0, 10]}]

I must have hit close to the mark, because personally I hate each of these champions when I go up against them!  ;)

* and (now I risk becoming addicted to DataHut myself), here's some further guesses with an easy_nuke index:

        [4] pry(main)> ds.order(Sequel.desc(:easy_nuke_index)).limit(5).collect{|c| c.name}
        => ["Sona", "Ryze", "Nasus", "Soraka", "Heimerdinger"]

* makes sense, but is still fascinating... what about my crack at a support_index?

        [5] pry(main)> ds.order(Sequel.desc(:support_index)).limit(5).collect{|c| c.name}
        => ["Sion", "Diana", "Nunu", "Nautilus", "Amumu"]



You get the idea now!  *Extract* your data from anywhere, *transform* it however you like and *analyze* it for insights!

Have fun!


## TODOS

* further optimizations
* time-based series and binning helpers (by week/day/hour/5-min/etc).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
