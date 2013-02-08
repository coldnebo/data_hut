# DataHut

A small, portable data warehouse for Ruby for analytics on anything!

This hasn't been optimized yet, but has the basic features for small one-off analytics like parsing error logs and such.


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

The datahut *dataset* is a Sequel::Model backed by the data warehouse you just created. 

And here's the kinds of powerful things you can do:

    [2] pry(main)> ds.where(eligible: false).count
    => 2
    [3] pry(main)> ds.avg(:age)
    => 34.0
    [4] pry(main)> ds.max(:age)
    => 44
    [5] pry(main)> ds.min(:age)
    => 27

But wait, you can name these collections:

    [6] pry(main)> ineligible = ds.where(eligible: false)
    => #<Sequel::SQLite::Dataset: "SELECT * FROM `data_warehouse` WHERE (`eligible` = 'f')">

    [26] pry(main)> ineligible.avg(:age)
    => 37.5
    [24] pry(main)> ineligible.order(Sequel.desc(:age)).all
    => [#< @values={:dw_id=>3, :name=>"fred", :age=>44, :eligible=>false}>,
     #< @values={:dw_id=>2, :name=>"phil", :age=>31, :eligible=>false}>]

The results are Sequel::Model objects, so you can treat them as such:

    [32] pry(main)> record = ineligible.order(Sequel.desc(:age)).first
    => #< @values={:dw_id=>3, :name=>"fred", :age=>44, :eligible=>false}>
    [33] pry(main)> record.name
    => "fred"
    [34] pry(main)> record.age
    => 44


Read more about the [Sequel gem](http://sequel.rubyforge.org/rdoc/files/README_rdoc.html) to determine what operations you can perform on a datahut dataset.


## TODOS

* fill out tests
* add optimizations for skipping processed records on transform (i.e. transform only unprocessed records)
* further optimizations
* time-based series and binning.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
