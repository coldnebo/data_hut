require_relative File.join(*%w[.. test_helper])


class DataWarehouseTest < MiniTest::Unit::TestCase
  def setup
  end

  def teardown
    FileUtils.rm("foo.db", force: true)
  end

  def test_cannot_instaniate
    assert_raises(NoMethodError) do
      DataHut::DataWarehouse.new  
    end
  end

  def test_bad_meta
    dh = DataHut.connect("foo")
    dh.store_meta(:bar, "good data")
    
    Marshal.expects(:dump).raises(RuntimeError.new("oh that was bad!"))
    assert_raises(ArgumentError) do
      dh.store_meta(:bar, "a bad thing")
    end

    Marshal.expects(:load).raises(RuntimeError.new("ouch!! again?"))
    assert_raises(RuntimeError) do
      dh.fetch_meta(:bar)
    end
  end

end