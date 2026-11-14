# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.pattern = 'test/**/*_test.rb'
end

# Cookie policy specs run against Community Engine's registries; they skip when those are absent.
# Set BETTER_TOGETHER_CE_LIB to a Community Engine checkout's lib directory to run them for real.
task :spec do
  sh 'rspec'
end

task default: %i[test spec]
