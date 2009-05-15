# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  begin
    load 'tasks/setup.rb'
  rescue LoadError
    raise RuntimeError, '### please install the "bones" gem ###'
  end
end

ensure_in_path 'lib'
require 'jdi_hook'

task :default => 'spec:run'

PROJ.name = 'jdi_hook'
PROJ.authors = 'Eric Monti'
PROJ.email = 'emonti@matasano.com'
PROJ.url = 'http://github.com/emonti/jdi_hook'
PROJ.version = JdiHook::VERSION
PROJ.rubyforge.name = 'jdi_hook'
PROJ.readme_file = 'README.rdoc'

PROJ.spec.opts << '--color'

# EOF
