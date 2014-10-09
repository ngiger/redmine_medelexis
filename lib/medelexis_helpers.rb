# Copyright 2014 by Niklaus Giger and Medelexis AG
#
# redmine_medelexis is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_medelexis is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_medelexis.  If not, see <http://www.gnu.org/licenses/>.

# Some helper for scripts and other stuff
require 'logger'
require 'uri'
require 'socket'

module RedmineMedelexis
  @@idFromTials2License ||= []
  LogName  = File.join(FileTest.writable?('/var/log') ? '/var/log' : Dir.pwd, `hostname -f`.strip + '.log')
  @@logger = Logger.new(LogName) # for more options see http://www.ruby-doc.org/stdlib-2.1.3/libdoc/logger/rdoc/Logger.html#method-c-new

  def self.debug(msg)
    return unless defined?(Setting) and Setting.plugin_redmine_medelexis['debug'].to_i == 1
    log_to_system(msg)
  end

  def self.log_to_system(msg, debug=false)
    return if debug and defined?(Setting) and Setting.plugin_redmine_medelexis['debug'].to_i == 0
    @@logger.info "#{Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S')}: #{msg.gsub(/[\n'"]/,'')}"
  end

  def self.shortenSubject(subject)
    subject.sub('feature.feature.group', 'feature')
  end

  def self.addJournal(type, id, msg)
    journal = Journal.new
    journal.journalized_id = id
    journal.journalized_type = type
    journal.notes = "#{File.basename(__FILE__)}: #{msg}"
    journal.save
  end

  def self.getExpiredTrialIssues
    unclosed_issues = Issue.find(:all, :conditions => {:tracker_id => 4, :closed_on => nil})
    trial2order = unclosed_issues.find_all{|x| x.valid? and x.start_date < -1.month.from_now.to_date and x.custom_field_values.first.value == 'TRIAL'}
  end

  def self.issue_to_licensed(issue)
    issue.custom_field_values.first.value = 'LICENSED'
    issue.save_custom_field_values
    issue.save!
    addJournal('Issue', issue.id, "#{File.basename(__FILE__)}: TRIAL -> LICENSED")
    @@idFromTials2License << issue.id
  end

  def self.convertExpiredTrial2License
    self.log_to_system("starting issue_to_licensed")
    ActiveRecord::Base.transaction do
      startTime = Time.now
      getExpiredTrialIssues.each{|issue| issue_to_licensed(issue) }
      duration = (Time.now-startTime).to_i
      self.log_to_system("issue_to_licensed took #{duration} second for ids #{@@idFromTials2License.join(',')}")
    end
    @@idFromTials2License
  end

  def getHauptkontakt(project_id)
    Project.find(project_id).contacts.find(:all, :conditions => { :cached_tag_list => 'Hauptkontakt'} ).first
  end

end
