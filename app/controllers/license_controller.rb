require 'tmpdir'
require 'xmlsimple'

class LicenseController < ApplicationController
  unloadable
  layout 'base'
  skip_before_filter :check_if_login_required
  # Zum Testen http://0.0.0.0:30001/my/license/fe2167a329f3c22799b1bcc3cb8cf93e7688f136.xml # development
  # http://0.0.0.0:30001/my/license?e631d4560a13047970cc2ba4a95519782bdd4106.xml
  def gen_license_xml_via_api
    # puts "gen_license_xml_via_api #{params}\napi_key is #{params['key']} action_name #{action_name} enabled?#{Setting.rest_api_enabled?}  api_key_from_request #{api_key_from_request}"
    user = User.find_by_api_key(params['key'])
    if user
      gen_license_file(user)
    else
      render :status => 403  #  forbidden
    end
  end

  # projects_trackers project_id 3 -> tracker_id: 4
  # contacts_projects_003:  project_id: 3  contact_id: 3  created_on: 2013-10-23 08:28:25.000000000 +02:00
  # custom_fields_trackers_001:  custom_field_id: 2  tracker_id: 4
  # users_005:  id: 5 login: mmustermann mail: mmustermann@medevit.at
  # issues_001:  id: 1  tracker_id: 4  project_id: 3 #  subject: ch.medelexis.application.feature
  # contacts_004:  id: 4  first_name: Praxis Dr. Mustermann  is_company: true created_on: 2013-11-15 14:30:21.000000000 +01:00
  # contacts_002:  id: 2  first_name: Max  last_name: Mustermann  is_company: false created_on: 2013-10-23 08:35:17.000000000 +02:00

  def get_license_issues(user)
    if false
    puts "get_project for #{user} with id #{user.id} current #{User.current}"
      # Valid options:
  # * :project => limit the condition to project
  # * :with_subprojects => limit the condition to project and its subprojects
  # * :member => limit the condition to the user projects
#    pp Contact.visible.find(:all, :conditions => {:assigned_to_id  => user.id}, :limit => 20)
#    contact = Contact.visible.find(:all, :conditions => {:author_id  => user.id}, :limit => 20)
##    contact = Contact.find_by_emails([user.mail]) return project 2 the wrong one
##    pp contact
##    contact = Contact.find(user.id) throws error notne find
    contact = Contact.find(1)
    pp contact
    pp Contact.find_by_id(3)
#    contact = Contact.find(user.id) throws error notne find
#    project = Project.find_by_contact_id(contact.id) 3  NoMethodError (undefined method `find_by_contact_id' for 
    project = Project.find(1)
    # pp Project.where(
    pp project
    pp Project.visible_condition(User.current)   #     => "projects.status = 1"
    pp Project.visible_condition(user)   #     => "projects.status = 1"
    pp Project.where(Project.visible_condition(user))   #     => "projects.status = 1"
#    pp Issue.where(Issue.visible_condition(user))   #     => "projects.status = 1"
    
#    issues = Issue.find_by_project_id(project.id) 
#    pp issues
    end 
    true
  end
  # Erstelle MedelexisLicenseFile.xml auf Basis MedelexisLicenseFile.xsd mit Enveloped Template MedelexisLicenseFileWithSignatureTemplate.xml
  def gen_xml_content(user, filename)
    # puts "gen_xml_content #{user} cur  #{User.current} -> #{filename}"
    licenses = get_license_issues(user)
    unless licenses
      @errors << 'No project found'
      return false
    end
    out = File.open(filename, 'w+')
    ownerData =  [{"customerId"=>["mmustermann"],
                   "misApiKey"=>["encryptedMisApiKey"],
                   "organization"=>["Praxis Dr. Mustermann"],
                   "numberOfStations"=>["0"],
                   "numberOfPractitioners"=>["1"]}]

    licenses =[{
                   "endOfLicense"=>"2013-12-12+01:00",
                   "id"=>"ch.medelexis.application.feature",
                   "licenseType"=>"TRIAL",
                   "startOfLicense"=>"2013-11-12+01:00"},
               {"endOfLicense"=>"2013-12-12+01:00",
                "id"=>"ch.elexis.base.textplugin.feature",
                "licenseType"=>"TRIAL",
                "startOfLicense"=>"2013-11-12+01:00"
               }
    ]
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
    out.write(XmlSimple.xml_out(all_xml, {'RootName' => 'medelexisLicense' ,'XmlDeclaration' => '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>' }))
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
        system("logger #{File.basename(__FILE__)}: from IP #{request.remote_ip} had xml-errors for user: #{user ? user.login : 'anonymous'}")
        render :status => 403
        return
      end
      # FileUtils.cp("#{data_dir}/default.xml", license, :preserve => true)  # unless File.exists?(license)
      signed            = "#{dest_dir}/#{userName}_signed.xml"
      crypted           = "#{dest_dir}/#{userName}_crypted.xml"
      cmd_1 =  "xmlsec1 sign --privkey-pem #{signingKey} #{license} > #{signed}"
      cmd_2 =  "xmlsec1 encrypt --pubkey-pem #{encryptionKeyPub} --session-key des-192 --xml-data  #{signed} --output #{crypted}  #{template}"
      okay = system(cmd_1) and system(cmd_2) and
          system("logger #{File.basename(__FILE__)}: from IP #{request.remote_ip} signed  #{crypted} #{File.size(crypted)} bytes #{File.ctime(crypted)}")
      content = IO.read(crypted)
      respond_to do |format|
        format.xml  { render :xml => content }
      end
      FileUtils.rm_f([signed, crypted, license]) unless defined?(MiniTest)
    else
      system("logger #{File.basename(__FILE__)}: from IP #{request.remote_ip} had #{@errors.size} errors for user: #{user ? user.login : 'anonymous'}")
      render :status => 403  #  forbidden
      # render(:file => File.join(Rails.root, 'public/403.html'), :status => 403, :layout => false)
    end
  end

  def gen_license_xml
    # puts "gen_license_xml #{params}"
    gen_license_file(find_user(params))
  end

private
  def find_user(params)
    user_by_session = User.find_by_id(request.session[:user_id])
    msg =  "find_user: User.current '#{User.current}' by session '#{user_by_session}' params #{params}"
    system("logger #{File.basename(__FILE__)}: #{msg}")
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

