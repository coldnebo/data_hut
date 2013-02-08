require_relative File.join(*%w[.. test_helper])


class DataWarehouseTest < MiniTest::Unit::TestCase
  def setup
  end

  def test_cannot_instaniate
    assert_raises(NoMethodError) do
      dw = DataHut::DataWarehouse.new  
    end
    
  #  assert_equal "OHAI!", @meme.i_can_has_cheezburger?
  end

end