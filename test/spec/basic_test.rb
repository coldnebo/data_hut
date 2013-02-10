require_relative File.join(*%w[.. test_helper])


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

    class Foo
    end

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

  end

end

