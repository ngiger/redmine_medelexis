# Copyright 2013 by Niklaus Giger and Medelexis AG
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

module RedmineMedelexis  
  def self.debug(msg)
    puts "#{Time.now} dbg: #{msg}"
  end
  
  def self.log_to_system(msg)
    self.debug(msg)
    system("logger #{File.basename(__FILE__)}: #{msg.gsub(/[\n'"]/,'')}")
  end

  def self.get_api_key(username)
    user = User.find_by_login(username)    
    token = Token.find_by_user_id_and_action(user.id, :api)
    token ? token.value : nil
  end
  
  def self.license_info_for_user(user)
    RedmineMedelexis.debug "#{__LINE__}: user #{user.inspect}"
    project = RedmineMedelexis.get_project(user)
    
    RedmineMedelexis.debug "#{__LINE__}: project #{project.inspect}"
    return nil unless project
    info = {}
    info['ownerdata'] =  RedmineMedelexis.get_ownerdata(user)
    info['license']    = RedmineMedelexis.get_license(project)
    info
  end
  
  private

  # Resumen of project mmustermann
  # projects_trackers project_id 3 -> tracker_id: 4
  # contacts_projects_003:  project_id: 3  contact_id: 3  created_on: 2013-10-23 08:28:25.000000000 +02:00
  # custom_fields_trackers_001:  custom_field_id: 2  tracker_id: 4
  # users_005:  id: 5 login: mmustermann mail: mmustermann@medevit.at
  # issues_001:  id: 1  tracker_id: 4  project_id: 3 #  subject: ch.medelexis.application.feature
  # contacts_004:  id: 4  first_name: Praxis Dr. Mustermann  is_company: true created_on: 2013-11-15 14:30:21.000000000 +01:00
  # contacts_002:  id: 2  first_name: Max  last_name: Mustermann  is_company: false created_on: 2013-10-23 08:35:17.000000000 +02:00
  # members_001:  id: 1  user_id: 5  project_id: 3
  
    Zeitformat        = '%Y-%m-%d%z'
    EwigesAblaufdatum = Time.new(2099, 12, 31).strftime(Zeitformat)
    TrialTime         = 31 # Days
  def self.get_member(user)
    members =  Member.find_all_by_user_id(user.id)
    RedmineMedelexis.debug "#{__LINE__}: members #{members.inspect}"
    if members.size == 1
      members.first
    else
      kundenRolle = Role.where("name = 'Kunde'")
      members =  Member.find_all_by_user_id(user.id)
      RedmineMedelexis.debug "#{__LINE__}: members #{members.inspect}"
      return nil unless members.size == 1
      return members.first
    end
  end
  
  def self.get_project(user)
    # Project.all.each{|p| pp puts "Project id #{p.id} identifier #{p.identifier} name #{p.name}" }
    return nil unless user
    project = Project.find_by_identifier(user.name) || Project.find_by_name(user.name)
    RedmineMedelexis.debug "#{__LINE__}: project #{project.inspect}"
    return project if project
    member = get_member(user)
    return nil unless member
    Project.find(member.project_id)
  end
  
  def self.get_ownerdata(user)
    return nil unless user
    return nil if user.anonymous?
    members =  Member.find_all_by_user_id(user.id)
    member = members[0]
    condition = "project_id = #{member.project_id}"
    contact =  Contact.joins(:projects).where(condition)[0]
    return nil unless contact
    ownerData = { "customerId"             => user.login,
                  "misApiKey"              => get_api_key(user.login),
                  "projectId"              => member.project_id,
                  "organization"           => contact.company,
                  "numberOfStations"       => "0",
                  "numberOfPractitioners"  => "1"}
  end
  
  def self.get_license(project)
    return nil unless project
    condition = "project_id = #{project.id}"
    issues = Issue.where(condition, Date.today)
    licenses = []
    issues.each{ |issue|  #>"2013-12-12+01:00",
                  endOfLicense = issue.due_date ? issue.due_date.strftime(Zeitformat) : Time.new(2099, 12, 31)
                  if /TRIAL/i.match(issue.custom_field_values[0].to_s)
                    endOfLicense = (issue.start_date + TrialTime)
                    next if endOfLicense < Date.today
                  end
      licenses<< {  "endOfLicense"    => endOfLicense.strftime(Zeitformat),
                    "id"              => issue.subject,
                    "licenseType"     => issue.custom_field_values[0].to_s,
                    "startOfLicense"  => issue.start_date.strftime(Zeitformat),
      }
               }
    licenses
  end
  
end
