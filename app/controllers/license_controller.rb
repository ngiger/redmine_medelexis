require 'tmpdir'
require 'xmlsimple'

class LicenseController < ApplicationController
  unloadable
  layout 'base'
  skip_before_filter :check_if_login_required

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
  def get_ownerdata_and_license_issues(user)
    # puts "get_project for #{user} with id #{user.id} current #{User.current} #{user.name}"
    project = Project.find_by_identifier(user.name) || Project.find_by_name(user.name)
    unless project
      kundenRolle = Role.where("name = 'Kunde'")
      members =  Member.find_all_by_user_id(user.id)
      return nil, nil unless members.size == 1
      member = members[0]
      # Issue.all.each{|issue| pp issue}
      # pp ContactQuery.where(Contact.visible_condition(user))
      condition = "project_id = #{member.project_id}"
      contact =  Contact.joins(:projects).where(condition)[0]
      issues = Issue.where(condition, Date.today)
      # puts "Customfield von contact ist #{contact.custom_field_values.inspect} (Should be Abostatus)"
      ownerData = [
                    { "customerId"             => [user.login],
                      "misApiKey"              => [get_api_key(user.login)],
                      "projectId"              => member.project_id,
                      "organization"           => [contact.company],
                      "numberOfStations"       => ["0"],
                      "numberOfPractitioners"  => ["1"]}

                ]
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
      return ownerData, licenses
    end
    
    return nil, nil
  end
  
  # Erstelle MedelexisLicenseFile.xml auf Basis MedelexisLicenseFile.xsd mit Enveloped Template MedelexisLicenseFileWithSignatureTemplate.xml
  def gen_xml_content(user, filename)
    # puts "gen_xml_content #{user} cur  #{User.current} -> #{filename}"
    ownerData, licenses = get_ownerdata_and_license_issues(user)
    unless ownerData
      @errors << 'No ownerData found'
      return false
    end
    unless licenses
      @errors << 'No licenses found'
      return false
    end
    out = File.open(filename, 'w+')
    all_xml = {"xmlns"=>"http://www.medelexis.ch/MedelexisLicenseFile",
  "generatedOn"=> Time.now.utc,
  "license"=>licenses,
  "ownerData"=> ownerData,
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

#    all_xml[:ownerDate] =  ownerData
    out.write(XmlSimple.xml_out(all_xml, {'RootName' => 'medelexisLicense' ,'XmlDeclaration' => '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' }))
    out.close
    true
  end

  # Signiere Datei
  # Verschlüsselte Datei
  def gen_license_file(user)
    @errors = []
    @errors << "Could not determine userid" unless user
    @errors << "Cannot create license for user anonymous" if user and user.anonymous?
    data_dir = File.expand_path(File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'data'))
    dest_dir = File.join(Dir.tmpdir, 'redmine_medelexis')
    FileUtils.makedirs(dest_dir)
    keystore          = '/srv/distribution-keys'
    signingKey        = "#{keystore}/signingKey.pem"
    encryptionKeyPub  = "#{keystore}/encryptionKeyPub.pem"
    template          = "#{keystore}/session-key-template.xml"
    [signingKey, encryptionKeyPub, template].each{ |f| @errors << "Missing file #{f}" unless File.exists?(f) }
    if @errors.size == 0 and user
      userName          = user.login
      license           = "#{dest_dir}/#{userName}.xml"
      xml = gen_xml_content(user, license)
      unless xml
        RedmineMedelexis.log_to_system(request, " had xml-errors for user: #{user ? user.login : 'anonymous'}")
        render :status => 403
        return
      end
      # FileUtils.cp("#{data_dir}/default.xml", license, :preserve => true)  # unless File.exists?(license)
      signed            = "#{dest_dir}/#{userName}_signed.xml"
      crypted           = "#{dest_dir}/#{userName}_crypted.xml"
      cmd_1 =  "xmlsec1 sign --privkey-pem #{signingKey} #{license} > #{signed}"
      cmd_2 =  "xmlsec1 encrypt --pubkey-pem #{encryptionKeyPub} --session-key des-192 --xml-data  #{signed} --output #{crypted}  #{template}"
      okay = system(cmd_1) and system(cmd_2) and
        RedmineMedelexis.log_to_system(request, "signed  #{crypted} #{File.size(crypted)} bytes #{File.ctime(crypted)}")
      content = IO.read(crypted)
      respond_to do |format|
        format.xml  { render :xml => content }
      end
      FileUtils.rm_f([signed, crypted, license]) unless defined?(MiniTest)
    else
      RedmineMedelexis.log_to_system(request, "had #{@errors.size} errors for user: #{user ? user.login : 'anonymous'}")
      render :status => 403  #  forbidden
      # render(:file => File.join(Rails.root, 'public/403.html'), :status => 403, :layout => false)
    end
  end

# Zum Testen http://0.0.0.0:30001/my/license/fe2167a329f3c22799b1bcc3cb8cf93e7688f136.xml # development
# http://0.0.0.0:30001/my/license?e631d4560a13047970cc2ba4a95519782bdd4106.xml
  def gen_license_xml_via_api
    RedmineMedelexis.log_to_system(request, "gen_license_xml_via_api user #{User.current}: #{params.inspect}\napi_key is #{params['key']} action_name #{action_name} enabled?#{Setting.rest_api_enabled?}  api_key_from_request #{api_key_from_request}")
    check_if_login_required if params['key'] == nil
    if params['key'] == nil and not User.current.anonymous?
      RedmineMedelexis.log_to_system(request, "333: Must use current User #{User.current}")
      user = User.current
    else
      user = User.find_by_api_key(params['key'])
      RedmineMedelexis.log_to_system(request, "333: Found user #{user.inspect} by apikey #{params['key'].inspect}")
    end
    if user
      gen_license_file(user)
    else
      render :status => 403  #  forbidden
    end
  end

  def gen_license_xml
    # require 'pry'; binding.pry
    RedmineMedelexis.log_to_system(request, "gen_license_xml #{params}")
    gen_license_file(find_user(params))
  end

private
  def find_user(params)
    user_by_session = User.find_by_id(request.session[:user_id])
    msg =  "find_user: User.current '#{User.current}' by session '#{user_by_session}' params #{params}"
    RedmineMedelexis.log_to_system(request, msg)
    return nil unless user_by_session
    return User.find_by_id(user_by_session) if params[:login].eql?('current')
    return User.find_by_login(params[:login]) if params[:login].eql?(user_by_session.login)
    return nil unless user_by_session.admin?
    return User.find_by_login(params[:login]) if params[:login]
    nil
  end

  def get_error_xml(error)
    error_xml = %(
<note>
<heading>User #{User.current}/#{User.find_by_id(request.session[:user_id])} cannot generate license.</heading>
<reasons>
  <reason>#{error.join("</reason>\n  <reason>")}
  </reason>
</reasons>
</note>
)
  end
  end

