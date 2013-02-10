# sample helper takes care of loading the gem from source without requiring it to be rebuilt and installed.
# this is useful in allowing the samples in this directory to evolve the behavior of the actual gem.

lp = File.expand_path(File.join(*%w[.. lib]), File.dirname(__FILE__))
unless $LOAD_PATH.include?(lp)
  $LOAD_PATH.unshift(lp)
end