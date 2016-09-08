# Sequel gives a lot of warnings like 
#   gems/sequel-4.38.0/lib/sequel/dataset/query.rb:80: warning: instance variable @... not initialized
# this is for a good reason defined here: https://github.com/jeremyevans/sequel/issues/1184
# until ruby 2.4.0 I decided to suppress these warnings by following an idea I found here: https://gist.github.com/rkh/9130314

require 'delegate'

module Support
  class WarningFilter < DelegateClass(IO)
    def write(line)
      not_found   = line !~ %r{^.*gems/sequel-[^/]*/lib/sequel.*: warning: private attribute\?$} 
      not_found &&= line !~ %r{^.*gems/sequel-[^/]*/lib/sequel.*: warning: instance variable @\w+ not initialized$} 
      super if not_found
    end
  end
end

$stderr = Support::WarningFilter.new($stderr)
