# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{jdi_hook}
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Eric Monti"]
  s.date = %q{2009-05-15}
  s.description = %q{JdiHook is a ruby-scriptable Java debugger based on and around Sun's Java  Debugging Interface (JDI) API.}
  s.email = %q{emonti@matasano.com}
  s.extra_rdoc_files = ["History.txt", "README.rdoc"]
  s.files = ["History.txt", "README.rdoc", "Rakefile", "jdi_hook.gemspec", "lib/jdi_hook.rb", "lib/jdi_hook/base_debugger.rb", "lib/jdi_hook/event_thread.rb", "lib/jdi_hook/method_tracer.rb", "lib/jdi_hook/stream_redirect_thread.rb", "samples/base_test.rb", "samples/meth_test.rb", "tasks/ann.rake", "tasks/bones.rake", "tasks/gem.rake", "tasks/git.rake", "tasks/notes.rake", "tasks/post_load.rake", "tasks/rdoc.rake", "tasks/rubyforge.rake", "tasks/setup.rb", "tasks/spec.rake", "tasks/svn.rake", "tasks/test.rake", "tasks/zentest.rake"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/emonti/jdi_hook}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jdi_hook}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{JdiHook is a ruby-scriptable Java debugger based on and around Sun's Java  Debugging Interface (JDI) API}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bones>, [">= 2.5.0"])
    else
      s.add_dependency(%q<bones>, [">= 2.5.0"])
    end
  else
    s.add_dependency(%q<bones>, [">= 2.5.0"])
  end
end
