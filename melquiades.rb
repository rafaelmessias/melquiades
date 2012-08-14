#!/usr/bin/env ruby

# Copyright 2012 Rafael Martins
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

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

# FOR DEBUGGING PURPOSES; PLEASE DON'T COMMIT
DEBUG_MAX_PROJECTS = 10
debug_project_count = 0

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
    if File.exists? project_path + '/' + filename
      puts "  Already exists: #{filename}"
    else
      puts "  #{filename}"
      File.open(project_path + '/' + filename, 'w') do |f|      
        f.write(URI.parse(dump['dump_url']).read)
      end    
    end
  end
  puts "ok"

  print "Getting resources (.json)... "
  resources_url = base_url + project['url'] + '/resources.json'
  resources_json = URI.parse(resources_url).read
  File.open(project_path + '/resources.json', 'w') {|f| f.write(resources_json)}
  puts "ok"

  puts "Trying to get the code..."
  JSON(resources_json).each do |resource|
    if resource['type'] == 'svn'
      svn_path = project_path + '/svn'
      if File.directory? svn_path
        puts "  SVN already checked out"
      else
        svn_url = resource['url']
        # When there's a trunk, download only that
        `svn list #{svn_url}`.split("\n").each do |line|
          if line.chomp.strip == 'trunk/'
            svn_url = svn_url + '/trunk'
            break
          end
        end
        puts "  Checking out SVN: #{svn_url}"
        `svn checkout #{svn_url} #{svn_path}`
      end
    end
  end
  puts "ok"

  print "Running 'analizo' (if applicable)... "
  if File.directory? project_path + '/svn'
    `analizo metrics --output #{project_path}/analizo.out #{project_path}/svn`
  end
  puts "ok"

  # FOR DEBUGGING PURPOSES; PLEASE DON'T COMMIT
  debug_project_count = debug_project_count + 1
  if debug_project_count == DEBUG_MAX_PROJECTS
    break
  end
end
