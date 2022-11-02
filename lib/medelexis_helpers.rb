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
require 'csv'

class Issue
  TrialDays         = 31 # Days
  def isTrial?
    statusField = custom_field_values.find{|x| x.custom_field.name.eql?('Abostatus')}.value
    !!/TRIAL/i.match(statusField)
  end

  def get_end_of_license
    endOfLicense = due_date ? due_date : Time.new(2099, 12, 31)
    if isTrial?
      endOfLicense = (start_date + TrialDays)
    end
    endOfLicense
  end
end

module RedmineMedelexis
  @@idFromTials2License ||= []
  Tracker_Is_Service      = 4

  if ENV['LOG_FILE_NAME']
    LogName = ENV['LOG_FILE_NAME']
  else
    LogBase  = File.dirname(Rails.configuration.paths['log'].first)
    LogName  = File.join( (FileTest.directory?(LogBase) && FileTest.writable?(LogBase)) ? LogBase : Dir.pwd, "medelexis-" +`hostname -f`.strip + '.log')
  end
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
    unclosed_issues = Issue.where(tracker_id: Tracker_Is_Service, closed_on: nil)
    trial2order = unclosed_issues.find_all{|x| x.valid? && x.isTrial? && x.get_end_of_license < (Date.today+3) } # convert to ordered after 28 days
  end

  def self.issue_to_licensed(issue)
    statusField = issue.custom_field_values.find{|x| x.custom_field.name.eql?('Abostatus')}
    aboStatus = statusField.value.clone
    msg ="Issue #{issue.id} valid? #{issue.valid?} isTrial #{issue.isTrial?} eol #{issue.get_end_of_license} #{File.basename(__FILE__)}: #{aboStatus} -> LICENSED"
    statusField.value = 'LICENSED'
    issue.save_custom_field_values
    issue.save!
    self.log_to_system("issue_to_licensed id #{msg}")
    addJournal('Issue', issue.id, msg)
    @@idFromTials2License << issue.id unless @@idFromTials2License.index(issue.id)
  end

  def self.convertExpiredTrial2License
    self.log_to_system("starting issue_to_licensed")
    ActiveRecord::Base.transaction do
      startTime = Time.now
      getExpiredTrialIssues.each{|issue| issue_to_licensed(issue) }
      duration = (Time.now-startTime).to_i
      self.log_to_system("issue_to_licensed took #{duration} second for issues with ids #{@@idFromTials2License.join(',')}")
    end
    @@idFromTials2License
  end

  def self.getHauptkontakt(project_id)
    contacts = Project.find(project_id).contacts
    if contacts.size != 1
      hauptkontakt = contacts.where(cached_tag_list: 'Hauptkontakt')
      if hauptkontakt.size != 1
        raise "Don't know how to handle Project with id #{project_id} and not exactly one Hauptkontakt (actually we have #{contacts.size})."
      end
      return hauptkontakt.first
    else
      return contacts.first
    end
  end

  StatEntry = Struct.new(:id, :basePrice, :nrClients, :nrDoctors, :value) do
    def showStat
      "#{id} used  by #{nrClients}/#{nrDoctors} generating #{value}/year"
    end
  end

  def self.genStatistics(withValue = true)
    ActiveRecord::Base.transaction do
      startTime = Time.now
      stats = {}
      allProjects = Project.all
      puts "#{startTime}: Generating statistics for #{allProjects.size} projects"
      nrClients = 0
      nrDoctors = 0
      allProjects.each do | project|
        status = project.kundenstatus
        next if project.keineVerrechnung
        next unless status && ['Neukunde', 'Kunde'].index(status)
        issues = MedelexisInvoices.findAllOpenServicesForProjectID(project.id, Date.today.end_of_year.to_date, Date.today.beginning_of_year)
        next if issues.size == 0
        nrClients += 1
        nrDoctors += project.nrDoctors
        multiplier = MedelexisInvoices.getMultiplier(project)
        issues.each do |issue|
          next unless MedelexisInvoices.getProduct(issue)
          grund_price = MedelexisInvoices.getProduct(issue).price.to_f
          issueId = issue.subject.gsub('.group','').gsub('.feature','')
          if stats[issueId]
            stats[issueId].nrClients += 1
            stats[issueId].nrDoctors += project.nrDoctors
            stats[issueId].value += grund_price * multiplier
          else
            stats[issueId] ||= StatEntry.new(issueId, grund_price, 1, project.nrDoctors, grund_price * multiplier)
          end
        end
      end
      CSV.open('statistics.csv', 'wb') do |csv|
        csv << ['issueId', 'grund_price', 'nrClients', 'nrDoctors', withValue ? 'value' : nil]
        stats.values.each do |entry|
          csv <<  [entry.id, entry.basePrice, entry.nrClients, entry.nrDoctors, withValue ? sprintf('%0.f', entry.value) : nil ]
        end
      end
      duration = (Time.now-startTime).to_i
      msg ="Generating statistics for #{allProjects.size} projects with #{nrClients} active practices (#{nrDoctors} doctors) took #{duration} second found #{stats.size} features"
      puts "#{Time.now}: #{msg}"
      self.log_to_system(msg)
    end
  end
end
