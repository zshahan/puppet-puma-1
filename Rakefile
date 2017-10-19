require 'rubygems'

desc "Validate manifests, templates, and ruby files"
task :lint do
  sh "puppet lint manifests/"
end
task :validate do
  sh "puppet parser validate manifests/"
  Dir['templates/**/*.erb'].each do |template|
    sh "erb -P -x -T '-' #{template} | ruby -c"
  end
end
