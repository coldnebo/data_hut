require_relative File.join(*%w[.. test_helper])


describe DataHut do
  def teardown
    FileUtils.rm("foo.db", force: true, verbose: true)
  end

  describe "gem loading" do
    it "must be defined" do
      DataHut::VERSION.wont_be_nil
    end
  end

  describe "connect" do 
    it "should create a database if none exists" do
      FileUtils.rm("foo.db", force: true, verbose: true)
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

      # ignore dups!!
      data2 = [{name: "barney", age: 27},
              {name: "phil", age: 31},{name: "phil", age: 31},
              {name: "fred", age: 44}]
              
      # the idea of the extract phase is that you control exactly how an element of your data 'd' is 
      # extracted into a transactional record 'r' in the data warehouse.
      dh.extract(data2) do |r, d|
        r.name = d[:name]
        r.age = d[:age]
      end

      dh.dataset.each_with_index do |r,i|
        assert r.name == data[i][:name]
        assert_kind_of(data[i][:name].class, r.name)
        assert r.age == data[i][:age]
        assert_kind_of(data[i][:age].class, r.age)
      end
    end
  end

end

