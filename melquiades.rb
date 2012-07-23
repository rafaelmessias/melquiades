#!/usr/bin/env ruby

require 'json'
require 'open-uri'

base_url = 'http://melquiades.flossmetrics.org'

projects_dir = "#{Dir.pwd}/projects"
begin
  Dir.mkdir(projects_dir)
rescue
  puts "Warning: '#{projects_dir}' already exists."
end

print "Getting project list... "
projects_json = URI.parse("#{base_url}/projects.json").read
File.open("#{projects_dir}/00_list.json", 'w') {|f| f.write(projects_json) }
puts "ok"

JSON(projects_json).each do |project|
  puts "Current project: '#{project['name']}'"
  project_path = projects_dir + '/' + project['name']
  begin
    Dir.mkdir(project_path)
  rescue
    puts "Warning: '#{project_path}' already exists."
  end

  print "Getting info (.json)... "
  info_url = base_url + project['url'] + '.json'
  info_json = URI.parse(info_url).read
  File.open(project_path + '/info.json', 'w') {|f| f.write(info_json)}
  puts "ok"

  puts "Getting dumps (.json)..."
  dumps_url = base_url + project['url'] + '/dumps.json'
  dumps_json = URI.parse(dumps_url).read
  File.open(project_path + '/dumps.json', 'w') {|f| f.write(dumps_json)}
  JSON(dumps_json).each do |dump|
    filename = File.basename(dump['dump_url'])
    puts '  ' + filename
    File.open(project_path + '/' + filename, 'w') do |f|      
      f.write(URI.parse(dump['dump_url']).read)
    end    
  end
  puts "ok"

  print "Getting resources (.json)... "
  resources_url = base_url + project['url'] + '/resources.json'
  resources_json = URI.parse(resources_url).read
  File.open(project_path + '/resources.json', 'w') {|f| f.write(resources_json)}
  puts "ok"

  break
end
