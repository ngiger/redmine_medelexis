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
require 'xmlsimple'
require 'medelexis_helpers'
require 'medelexis_invoices'

Rails.configuration.to_prepare do
  require 'redmine_products/hooks/views_issues_hook'
  require 'redmine_products/patches/issue_query_patch'
  require 'redmine_products/hooks/views_custom_fields_hook'
  require 'redmine_products/patches/issue_patch'
  require 'redmine_products/patches/custom_fields_helper_patch'
  require 'redmine_products/patches/invoices_controller_patch'
  require 'redmine_products/hooks/views_invoices_hook'
  require 'redmine_products/hooks/views_contacts_hook'
  require 'redmine_products/patches/add_helpers_for_products_patch'
  require 'redmine_products/patches/contact_patch'
  require 'redmine_products/patches/project_patch'
  require 'redmine_products/patches/contacts_helper_patch'
  require 'redmine_products/patches/queries_helper_patch'
  require 'redmine_products/patches/notifiable_patch'
  require 'redmine_products/patches/auto_completes_controller_patch'
  require 'redmine_products/hooks/views_layouts_hook'
  require 'redmine_products/hooks/controller_contacts_duplicates_hook'
end

module RedmineMedelexisSettings

  def self.invoices_plugin_installed?
    @@invoices_plugin_installed ||= (Redmine::Plugin.installed?(:redmine_contacts_invoices) && Redmine::Plugin.find(:redmine_contacts_invoices).version >= "2.2.3" )
  end

end

module RedmineMedelexis
  Keystore          = '/srv/distribution-keys'
  LicenseStore      = File.join(Dir.tmpdir, 'redmine_medelexis')

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
    info['ownerdata'] =  RedmineMedelexis.get_ownerdata(user, project)
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

    Zeitformat        = '%Y-%m-%d%:z'
    EwigesAblaufdatum = Time.new(2099, 12, 31).strftime(Zeitformat)
  def self.get_member(user)
    members =  Member.where(id: user.id)
    RedmineMedelexis.debug "#{__LINE__}: members #{members.inspect}"
    if members.size == 1
      members.first
    else
      kundenRolle = Role.where("name = 'Kunde'")
      members =  Member.where(user.id)
      RedmineMedelexis.debug "#{__LINE__}: members #{members.inspect}"
      return nil unless members.size == 1
      return members.first
    end
  end

  def self.get_project(user)
    # Project.all.each{|p| pp puts "Project id #{p.id} identifier #{p.identifier} name #{p.name}" }
    return nil unless user
    project = nil
    Project.all.each do |proj|
      if proj.identifier == user.login
        project = proj
        break
      end
    end
    RedmineMedelexis.debug "#{__LINE__}: user #{user.name} #{user.name} > project #{project.inspect}"
    return project if project
  end

  def self.get_ownerdata(user, project)
    return nil unless user
    return {'customerId' => 'anonymous?' } if user.anonymous?
    member = Member.find_by_project_id_and_user_id(project.id, user.id)
    condition = "project_id = #{member.project_id}"
    RedmineMedelexis.debug "#{__LINE__}: member #{member.inspect}"
    ownerData = { "customerId"             => user.login,
                  "misApiKey"              => get_api_key(user.login),
                  "projectId"              => project.id,
                  "organization"           => project.name,
                  "numberOfStations"       => project.nrDoctors,
                  "numberOfPractitioners"  => project.nrStations,
                  "systemProperties"       => project.systemProperties,
                  }
  end

  def self.get_license(project)
    return nil unless project
    condition = "project_id = #{project.id}"
    issues = Issue.where(condition, Date.today)
    eternal = Issue.where(project_id: 1, closed_on: nil)
    licenses = []
    uniq_ids = []
    (issues+eternal).each do  |issue|  #>"2013-12-12+01:00",
      next unless issue.tracker_id == Tracker_Is_Service
      next if uniq_ids.index(issue.subject)
      next unless statusField = issue.custom_field_values.find{|x| x.custom_field.name.eql?('Abostatus')}
      uniq_ids << issue.subject
      endOfLicense = issue.get_end_of_license + 1
      puts  "TRIAL issue #{issue.id} of #{issue.due_date} endOfLicense #{endOfLicense} is expired? #{endOfLicense < Date.today}" if issue.isTrial? && $VERBOSE
      next if issue.isTrial? && endOfLicense < Date.today
      licenses<< {  "endOfLicense"    => endOfLicense.strftime(Zeitformat),
                    "id"              => issue.subject,
                    "licenseType"     => issue.custom_field_values[0].to_s,
                    "startOfLicense"  => issue.start_date.strftime(Zeitformat),
      }
    end
    # ids = licenses.collect{ |x| x['id']}.sort
    # File.open('/home/niklaus/ids.txt', 'w') {|f| ids.each{|x| f.puts x}}
    #  	17538 	Service-ES 	Neu 	TRIAL 	Normal 	at.medevit.elexis.agenda.reminder.es.feature.feature.group 	Max Mustermann 	17.10.2022 13:52 	Aktionen
    licenses
  end

  def self.write_unencrypted_xml(license, info)
    info ?  owner   = info['ownerdata'] : owner   = {}
    info ?  licInfo = info['license']   : licInfo = [ {} ]
    all_xml = {"xmlns"=>"http://www.medelexis.ch/MedelexisLicenseFile",
    "generatedOn"=> Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%L%:z"),
    "license"=> licInfo,
    "ownerData"=> [
                    { "customerId"            => [owner["customerId"]],
                      "misApiKey"             => [owner["misApiKey"]],
                      "projectId"             => [owner["projectId"]],
                      "organization"          => [owner["organization"]],
                      "numberOfStations"      => [owner["numberOfStations"]],
                      "numberOfPractitioners" => [owner["numberOfPractitioners"]],
                      "systemProperties"      => [owner["systemProperties"]],
                   }
                  ] ,
    "Signature"=>
      [{"xmlns"=>"http://www.w3.org/2000/09/xmldsig#",
        "SignedInfo"=>
        [{"CanonicalizationMethod"=>
            [{"Algorithm"=>"http://www.w3.org/TR/2001/REC-xml-c14n-20010315"}],
          "SignatureMethod"=>
            [{"Algorithm"=>"http://www.w3.org/2000/09/xmldsig#rsa-sha1"}],
          "Reference"=>
            [{"URI"=>"",
              "Transforms"=>
              [{"Transform"=>
                  [{"Algorithm"=>
                    "http://www.w3.org/2000/09/xmldsig#enveloped-signature"}]}],
              "DigestMethod"=>
              [{"Algorithm"=>"http://www.w3.org/2000/09/xmldsig#sha1"}],
              "DigestValue"=>[{}]}]}],
      "SignatureValue"=>[{}]}]}
    FileUtils.makedirs(File.dirname(license))
    out = File.open(license, 'w+')
    out.write(XmlSimple.xml_out(all_xml, {'RootName' => 'medelexisLicense' ,'XmlDeclaration' => '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' }))
    out.close
    all_xml = XmlSimple.xml_out(all_xml, {'RootName' => 'medelexisLicense' ,'XmlDeclaration' => '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' })
    all_xml
  end

  def self.encrypt(info, userName)
    data_dir = File.expand_path(File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'data'))
    signingKey        = "#{Keystore}/signingKey.pem"
    encryptionKeyPub  = "#{Keystore}/encryptionKeyPub.pem"
    template          = "#{Keystore}/session-key-template.xml"
    license           = "#{LicenseStore}/#{userName}.xml"
    signed            = "#{LicenseStore}/#{userName}_signed.xml"
    crypted           = "#{LicenseStore}/#{userName}_crypted.xml"
    cmd_1 =  "xmlsec1 sign --privkey-pem #{signingKey} #{license} > #{signed}"
    cmd_2 =  "xmlsec1 encrypt --pubkey-pem #{encryptionKeyPub} --session-key des-192 --xml-data  #{signed} --output #{crypted}  #{template}"
    FileUtils.makedirs(LicenseStore)
    # RedmineMedelexis.log_to_system("encrypting  #{license} #{info.inspect}")
    unencrypted = write_unencrypted_xml(license, info)
    # RedmineMedelexis.log_to_system("unencrypted  #{license} #{File.size(license)} bytes #{File.ctime(license)}")
    okay = system(cmd_1) && system(cmd_2)
    unless okay && File.exist?(crypted)
      RedmineMedelexis.log_to_system("Could not generate a license file. Are xmlsec1 and private key installed?")
      return ""
    end
    RedmineMedelexis.log_to_system("signed  #{crypted} #{File.size(crypted)} bytes #{File.ctime(crypted)}")
    content = IO.read(crypted)
    FileUtils.rm_f([signed, crypted, license]) unless defined?(MiniTest) or Setting.plugin_redmine_medelexis['keep_temp_license_files'].to_i == 1
    content
  end

end
