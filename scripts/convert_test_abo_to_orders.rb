#!/usr/bin/env ruby

LoggingHeader = 'redmine_medelexis:'

Issue.first
# Issue 402 Max Mustermann at.medevit.elexis.rdus.feature.feature.group from late july 2014
# Issue.find(402).custom_field_values.first.value

unclosed_issues = Issue.find(:all, :conditions => {:tracker_id => 4, :closed_on => nil})
trial2order = unclosed_issues.find_all{|x| x.start_date < -1.month.from_now.to_date and x.custom_field_values.first.value == 'TRIAL'}

def issue_to_licensed(issue)
	$idFromTials2License ||= []
	issue.custom_field_values.first.value = 'LICENSED'
	issue.save_custom_field_values
	issue.save!
	$idFromTials2License << issue.id
end

cmd = "logger #{LoggingHeader} starting issue_to_licensed"
system(cmd)

ActiveRecord::Base.transaction do
	startTime = Time.now
	trial2order.each{|issue| issue_to_licensed(issue) }
	duration = (Time.now-startTime).to_i
	cmd = "logger #{LoggingHeader} issue_to_licensed took #{duration} second for ids #{$idFromTials2License.join(',')}"
	system(cmd)
end
