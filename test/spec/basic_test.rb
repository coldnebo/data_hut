require_relative File.join(*%w[.. test_helper])

class Foo
  attr_accessor :bar

  def initialize
    @time = DateTime.now
  end

  def what
    puts "say what?"
  end
end

describe DataHut do
  def teardown
    FileUtils.rm("foo.db", force: true)
  end

  describe "gem loading" do
    it "must be defined" do
      DataHut::VERSION.wont_be_nil
    end
  end

  describe "connect" do 
    it "should create a database if none exists" do
      FileUtils.rm("foo.db", force: true)
      dh = DataHut.connect("foo")
      assert File.exists?("foo.db")
    end
  end

  describe "extract" do
    it "should support extracting data" do
      dh = DataHut.connect("foo")

      data = [{name: "barney", age: 27},
              {name: "phil", age: 31},
              {name: "fred", age: 44}]
              
      dh.extract(data) do |r, d|
        r.name = d[:name]
        r.age = d[:age]
      end

      assert_equal 3, dh.dataset.count

      dh.dataset.each_with_index do |r,i|
        assert_equal data[i][:name], r.name
        assert_kind_of(data[i][:name].class, r.name)
        assert_equal data[i][:age], r.age 
        assert_kind_of(data[i][:age].class, r.age)
      end
    end

    it "should prevent duplicates from being extracted" do
      dh = DataHut.connect("foo")

      data = [{name: "barney", age: 27},
              {name: "barney", age: 27},
              {name: "phil", age: 31},
              {name: "phil", age: 31},
              {name: "fred", age: 44}]
 
      dh.extract(data) do |r, d|
        r.name = d[:name]
        r.age = d[:age]
      end

      assert_equal 3, dh.dataset.count
    end

    it "should support early skipping" do
      dh = DataHut.connect("foo")

      data = [{name: "barney", age: 27},
              {name: "barney", age: 27},
              {name: "phil", age: 31},
              {name: "phil", age: 31},
              {name: "fred", age: 44}]
 
      called = 0
      dh.extract(data) do |r, d|
        next if dh.not_unique(name: d[:name])
        r.name = d[:name]
        r.age = d[:age]
        called += 1
      end

      assert_equal 3, dh.dataset.count
      assert_equal 3, called
    end


    it "should add new records on subsequent extracts" do
      dh = DataHut.connect("foo")

      # first data pull 
      data = [{name: "barney", age: 27},
              {name: "phil", age: 31},
              {name: "fred", age: 44}]
 
      dh.extract(data) do |r, d|
        r.name = d[:name]
        r.age = d[:age]
      end

      assert_equal 3, dh.dataset.count

      # later on, a second data pull is run with new data...
      data = [{name: "lisa", age: 27},
              {name: "mary", age: 19},
              {name: "jane", age: 33}]
 
      dh.extract(data) do |r, d|
        r.name = d[:name]
        r.age = d[:age]
      end

      assert_equal 6, dh.dataset.count
    end
  end

  describe "transform" do 
    def setup
      @dh = DataHut.connect("foo")

      data = [{name: "barney", age: 27},
              {name: "phil",   age: 31},
              {name: "fred",   age: 44},
              {name: "lisa",   age: 27},
              {name: "mary",   age: 19},
              {name: "jane",   age: 15}]
      
      @dh.extract(data) do |r, d|
        r.name = d[:name]
        r.age = d[:age]
      end
    end

    it "should support transforming existing data" do
      @dh.transform do |r|
        r.eligible = r.age > 18 && r.age < 35
      end

      assert_equal 27.166666666666668, @dh.dataset.avg(:age)
      sorted_by_name = @dh.dataset.order(:name)
      eligible = sorted_by_name.where(eligible:true)
      ineligible = sorted_by_name.where(eligible:false)
      assert_equal 4, eligible.count
      assert_equal 2, ineligible.count

      assert_equal ["barney", "lisa", "mary", "phil"], eligible.collect{|d| d.name}
      assert_equal ["fred", "jane"], ineligible.collect{|d| d.name}
    end

    it "should support ignoring processed records" do
      @dh.transform_complete

      called = false
      @dh.transform do |r|
        r.eligible = r.age > 18 && r.age < 35
        called = true
      end

      refute called
    end

  end


  describe "nice usage" do  

    it "should provide logging services to see or debug underlying Sequel" do
      dh = DataHut.connect("foo")

      dh.logger = ::Logger.new(STDOUT)

      assert_raises(ArgumentError) do
        dh.logger = Foo.new
      end

    end

    it "should handle type errors" do
      dh = DataHut.connect("foo")

      data = [{name: "fred", birthday: '1978-02-11'}]

      # how about dates?
      dh.extract(data) do |r, d|
        r.name = d[:name]
        r.birthday = Date.parse(d[:birthday])
      end

      # ok, but what about a custom type... that's guaranteed to fail!
      assert_raises(ArgumentError) do
        dh.transform do |r|
          r.my_foo = Foo.new
        end
      end

    end

    it "should handle nils" do
      dh = DataHut.connect("foo")

      data = [{name: nil, birthday: '1978-02-11'},
              {name: "fred", birthday: '1988-02-11'},
              {name: "larry", birthday: nil}]

      # here we have an unsanitized datasource with some nils.
      dh.extract(data) do |r, d|
        r.name = d[:name]
        r.birthday = Date.parse(d[:birthday]) rescue nil
      end

      # make sure additional transforms also behave well.
      dh.transform do |r|
        r.my_nil = r.name
      end
    end

  end


  describe "support adding and retrieving possibly useful metadata" do

    it "should store and retrieve metadata" do
      dh = DataHut.connect("foo")

      val1 = "wizard"
      val2 = ["larry", "steve", "barney"]
      val3 = {one: "for the money", two: "for the show"}
      val4 = Foo.new
      
      dh.store_meta(:harry, val1)
      dh.store_meta(:users, val2)
      dh.store_meta(:my_little_hash, val3)
      dh.store_meta(:an_object, val4)
      
      assert_equal val1, dh.fetch_meta(:harry)
      assert_equal val2, dh.fetch_meta(:users)
      assert_equal val3, dh.fetch_meta(:my_little_hash)

      assert_raises(MiniTest::Assertion) do 
        assert_equal val4, dh.fetch_meta(:an_object)
      end

      assert_equal nil, dh.fetch_meta(:not_there)

      val5 = "muggle"
      dh.store_meta(:harry, val5)
      assert_equal val5, dh.fetch_meta(:harry)

      val6 = nil
      dh.store_meta(:harry, val6)
      assert_equal val6, dh.fetch_meta(:harry)

    end

  end


  describe "json export" do
    def setup
      @dh = DataHut.connect("foo")

      # first data pull 
      data = [{name: "barney", age: 27},
              {name: "barney", age: 17},
              {name: "barney", age: 37},
              {name: "phil", age: 35},
              {name: "phil", age: 31},
              {name: "fred", age: 44}]
 
      @dh.extract(data) do |r, d|
        r.name = d[:name]
        r.age = d[:age]
      end
    end

    it "should provide json export" do
      json = @dh.dataset.all.to_json

      # should be valid json
      result = JSON.parse(json)
      assert(Array, result.class)
      assert(Hash, result.first.class)
      assert({"dw_id"=>1, "dw_processed"=>false, "name"=>"barney", "age"=>27}, result.first)
    end

    it "should provide json for calcs" do
      # this collection doesn't convert to json using the Sequel :json_serializer plugin
      # so using default json instead. see lib/data_hut/data_warehouse.rb:67
      json = @dh.dataset.group_and_count(:name).all.to_json
      
      # should be valid json
      result = JSON.parse(json)

      assert(3,result.select{|r| r["name"] == "barney"}.first["count"])
      assert(2,result.select{|r| r["name"] == "phil"}.first["count"])
      assert(1,result.select{|r| r["name"] == "fred"}.first["count"])
    end
  end

end

