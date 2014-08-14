#!/usr/bin/env ruby
dir = File.expand_path('../../lib', __FILE__)
$: << dir unless $:.index(dir)
require 'medelexis_helpers'
require 'active_record'

def shortenSubject(subject)
  subject.sub('feature.feature.group', 'feature')
end

def showProblems(ausgabe = File.open('problems.txt', 'w+'))
  nrProblems = 0
  ausgabe.puts "Here is a list of all Service tickets which do not have exactly one attached product"
  ausgabe.puts "Created by #{__FILE__} at #{Time.now}"
  missingSubjects = []
  
   Issue.find(:all, :conditions => {:tracker_id => 4, :closed_on => nil}).each{
     |issue| 
    next unless issue.tracker_id == 4
    nrProducts = Product.find(:all, :conditions => { :code => shortenSubject(issue.subject) }).size
    next if nrProducts == 1
    ausgabe.puts "Issue #{issue.id} changed #{issue.updated_on} #{issue.subject} has #{nrProducts} products"
    nrProblems += 1
    missingSubjects << shortenSubject(issue.subject) if nrProducts << 0
  }
  nrServiceIssues = Issue.find(:all, :conditions => { :tracker_id => 4} ).size
  ausgabe.puts "#{nrProblems} out of #{nrServiceIssues} service issues had problems #{missingSubjects.sort.uniq.size}/#{missingSubjects.size} missing"
  ausgabe.puts "   Add the following subjects to fix the problem"
  ausgabe.puts missingSubjects.sort.uniq.join("\n")
end

def correctStartdate(ausgabe = File.open('problems.txt', 'w+'))
  nrProblems = 0
  augustFirst  = Date.new(2014,8,1)
  januaryFirst = Date.new(2014,1,1)
  issues = Issue.find(:all, :conditions => {:tracker_id => 4, :closed_on => nil})
  issues = issues.find_all{ |x| x.start_date < augustFirst and x.start_date > januaryFirst}
  ActiveRecord::Base.transaction do
    startTime = Time.now
    issues.each{ 
      |issue|
      msg = "Changed start_date from #{issue.start_date} => #{januaryFirst}"
      RedmineMedelexis.addJournal('Issue', issue.id, msg)
      ausgabe.puts "Issue #{issue.id}: #{msg}"
      nrProblems += 1
      issue.start_date = januaryFirst
      issue.save!               
    }
    duration = (Time.now-startTime).to_i
  end
  ausgabe.puts "correctStartdate corrected #{nrProblems} problems"
end

def deleteProjectsWithoutIssues(ausgabe = File.open('problems.txt', 'w+'))
  nrDeletes = 0
  ActiveRecord::Base.transaction do
    Project.all.each {
      |project|
        next unless  project.issues.size == 0
        ausgabe.puts "Deleting project #{project.id}: #{project.identifier} #{project.name} which has no issues"
        project.delete
        nrDeletes += 1
    }
  end
  ausgabe.puts "deleteProjectsWithoutIssues deleted #{nrDeletes} projects"
end

def deleteDuplicatedServiceIssues(ausgabe = File.open('duplicates.txt', 'w+'))
  ausgabe.puts "Here is a list of all service tickets which have duplicates"
  ausgabe.puts "Created by #{__FILE__} at #{Time.now}"
  problems = []
  ActiveRecord::Base.transaction do
    Issue.find(:all, :conditions => {:tracker_id => 4, :closed_on => nil}).each {
      |issue|
        sameIssues = Issue.find(:all, :conditions => 
                                  {:tracker_id => 4, :closed_on => nil,
                                  :project_id => issue.project_id, :subject => issue.subject})
        next if sameIssues.size == 1 
        ausgabe.puts "issue #{issue.id} found #{sameIssues.size} times"
        sameIssues.sort! { |a,b| a.created_on <=> b.created_on }
        sameIssues.each{ |x| ausgabe.puts "#{x.id} #{x.created_on}"}
        sameIssues[1..-1].each{ 
                              |x| 
                              ausgabe.puts "Deleting #{x.id} #{x.created_on}"
                              x.delete
                                }
        problems << issue.id  
    }
  end
  ausgabe.puts "deleteDuplicatedServiceIssues deleted #{problems.size} duplicated service"
  problems
end

ausgabe = File.open("cleanup_#{Time.now.strftime('%Y%m%d-%H%M')}.txt", 'w+')
deleteProjectsWithoutIssues(ausgabe)
deleteDuplicatedServiceIssues(ausgabe)
correctStartdate(ausgabe)
showProblems(ausgabe)
