#!/usr/bin/env ruby

# This CLI tool can be used to:
#    a. search projects
#       $ ./gitlab_cli.rb --search --project "Project Name"
#    b. search groups
#       $ ./gitlab_cli.rb --search --group "Group Name"
#    c. share projects with a group
#       $ ./gitlab_cli.rb --project "Project Name" --group "Group Name" --access "Access Level"
#    d. list available access levels
#       $ ./gitlab_cli.rb --list-access-levels

require "table_print"
require "optparse"
require "gitlab"
require "envl"
require "json"

# Load environment variables.
Envl.auto_load
Gitlab.endpoint = ENV["GITLAB_URL"]
Gitlab.private_token = ENV["GITLAB_TOKEN"]

class GitlabCLI
  def initialize(options)
    @options = options
  end

  def run
    search_mode = false
    project_name = nil
    group_name = nil
    access_level = "reporter" # Default to reporter access level

    search_mode = @options[:search_mode] if @options[:search_mode]
    project_name = @options[:project_name] if @options[:project_name]
    group_name = @options[:group_name] if @options[:group_name]
    access_level = @options[:access_level] if @options[:access_level]

    return search(project_name, group_name) if search_mode
    return share(project_name, group_name, access_level)
  end

  def self.get_access_levels
    %w[NO_ACCESS GUEST REPORTER DEVELOPER MAINTAINER OWNER]
  end

  private

  def nil_or_empty?(value)
    value.nil? || value.empty?
  end

  def search(project_name, group_name)
    if nil_or_empty?(project_name) && nil_or_empty?(group_name)
      puts "Nothing to search for. Please use the `--project` or `--group` arguments."
      return
    end

    if not nil_or_empty?(project_name)
      projects = get_projects(project_name)

      if projects.empty?
        puts "No projects found matching '#{project_name}'"
        return
      end

      return
    end

    if not nil_or_empty?(group_name)
      groups = get_groups(group_name)

      if groups.empty?
        puts "No groups found matching '#{group_name}'"
        return
      end

      puts "Found #{groups.size} group(s) matching '#{group_name}':"
      tp groups
      puts

      return
    end
  end

  def share(project_name, group_name, access_level)
    if nil_or_empty?(project_name)
      puts "The `--project` argument was not specified."
      return
    end

    if nil_or_empty?(group_name)
      puts "The `--group` argument was not specified."
      return
    end

    if not GitlabCLI.get_access_levels.include? access_level.upcase
      puts "Invalid access level '#{access_level}' was specified."
      return
    end

    puts "Attempting to share projects matching '#{project_name}' with group '#{group_name}' using access level '#{access_level}'."
    projects = get_projects(project_name)
    groups = get_groups(group_name)

    if projects.empty?
      puts "No projects found matching '#{project_name}'"
      return
    end

    if groups.empty?
      puts "No groups found matching '#{group_name}'"
      return
    end

    valid_group_ids = groups.map { |g| g[:id] }
    selected_group_id = groups.first[:id]

    if groups.size > 1
      puts "Multiple groups found matching '#{group_name}':"
      tp groups
      puts
      print "Select a group to use by entering the Group ID: "
      selected_group_id = gets.chomp.to_i
      puts
    end

    if not valid_group_ids.include? selected_group_id
      puts "You have selected an invalid Group ID."
      return
    end

    share_projects_with_group(projects, selected_group_id, access_level)
  end

  def share_projects_with_group(projects, group_id, access_level)
    access_levels = GitlabCLI.get_access_levels
    selected_access_level = 0

    access_levels.each_with_index do |al, i|
      if al == access_level.upcase
        selected_access_level = 10 * i
        break
      end
    end

    if selected_access_level >= 30
      puts "You have selected above or equal to developer level access."
      puts "Are you sure you want to continue?"
      print "(y/N): "
      choice = gets.chomp

      exit if choice.upcase == "N"

      if choice.upcase != "Y"
        "You entered an invalid option."
        exit
      end
    end

    projects.each do |p|
      puts "Sharing project #{p[:name]} (id = #{p[:id]})"
      
      begin
        Gitlab.share_project_with_group(p[:id], group_id, selected_access_level)
      rescue
      end
    end
  end

  def get_projects(project_name)
    puts "Searching for projects matching '#{project_name}'"
    projects_found = []

    projects = Gitlab.projects(per_page: 20, search: project_name)
    projects.auto_paginate do |project|
      project_id = project.to_h["id"]
      project_name = project.to_h["name"]
      project_ns = project.to_h["namespace"]["name"]
      shared_with_groups = project.to_h["shared_with_groups"]
      groups = shared_with_groups.map { |g| g.to_h["group_name"] }

      projects_found << { :id => project_id, :namespace => project_ns, :name => project_name, :group_access => groups.join(", ") }
    end

    if projects_found.any?
      puts "Found #{projects.size} project(s) matching '#{project_name}':"
      tp projects_found, :id, :namespace, :name, { :group_access => { :width => 40 } }
      puts
    end

    projects_found
  end

  def get_groups(group_name)
    puts "Searching for groups matching '#{group_name}'"
    groups_found = []

    groups = Gitlab.group_search(group_name)
    groups.each do |g|
      groups_found << { :id => g.to_h["id"], :name => g.to_h["name"] }
    end

    groups_found
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gitlab_cli [options]"

  opts.on("-s", "--search", "Enable search mode") do
    options[:search_mode] = true
  end

  opts.on("-p", "--project PROJECT", "Specify a project name") do |project_name|
    options[:project_name] = project_name
  end

  opts.on("-g", "--group GROUP", "Specify a group name") do |group_name|
    options[:group_name] = group_name
  end

  opts.on("-a", "--access ACCESS_LEVEL", "Specify an access level name") do |access_level|
    options[:access_level] = access_level
  end

  opts.on("-l", "--list-access-levels", "Print a list of access levels") do
    puts "Access levels: #{GitlabCLI.get_access_levels.join(", ")}"
    exit
  end

  opts.on("-h", "--help", "Display this help message") do
    puts opts
    exit
  end
end.parse!

cli = GitlabCLI.new(options)
cli.run
