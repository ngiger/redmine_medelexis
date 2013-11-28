class LicenseController < ApplicationController
  unloadable
  layout 'base'
  skip_before_filter :check_if_login_required
  
  # Zum Testen 0.0.0.0:30001/my/license/fe2167a329f3c22799b1bcc3cb8cf93e7688f136.xml
  def gen_license_xml_via_api
    user = User.find_by_api_key(params['api_key'])
    if user
      gen_license_file(User.find_by_api_key(params['api_key']))
    else
      render :xml =>  get_error_xml(['Wrong api_key?']) 
    end
  end
  
  # Erstelle MedelexisLicenseFile.xml auf Basis MedelexisLicenseFile.xsd mit Enveloped Template MedelexisLicenseFileWithSignatureTemplate.xml
  # Signiere Datei 
  # Verschlüsselte Datei
  def gen_license_file(user)
    @errors = []
    @errors << "Could not determine userid" unless user
    @errors << "Cannot create license for user anonymous" if user and user.anonymous?
    data_dir = File.expand_path(File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'data'))
    keystore          = '/srv/distribution-keys'
    signingKey        = "#{keystore}/signingKey.pem"
    encryptionKeyPub  = "#{keystore}/encryptionKeyPub.pem"
    template          = "#{keystore}/session-key-template.xml"
    [signingKey, encryptionKeyPub, template].each{ |f| @errors << "Missing file #{f}" unless File.exists?(f) } # unless `hostname`.chomp.eql?('ng-tr')
    if @errors.size == 0 and user
      userName          = user.login
      license           = "#{data_dir}/#{userName}.xml"
      FileUtils.cp("#{data_dir}/default.xml", license, :verbose => true, :preserve => true) unless File.exists?(license)
      signed            = "#{data_dir}/#{userName}_signed.xml"
      crypted           = "#{data_dir}/#{userName}_crypted.xml"
      cmd_1 =  "xmlsec1 sign --privkey-pem #{signingKey} #{license} > #{signed}"
      cmd_2 =  "xmlsec1 encrypt --pubkey-pem #{encryptionKeyPub} --session-key des-192 --xml-data  #{signed} --output #{crypted}  #{template}"
      okay = system(cmd_1) and system(cmd_2) and
          system("logger #{File.basename(__FILE__)}: from IP #{request.remote_ip} signed  #{crypted} #{File.size(crypted)} bytes #{File.ctime(crypted)}")
      respond_to do |format|
      format.xml  { render :xml => IO.read(crypted) }
      end
    else
      system("logger #{File.basename(__FILE__)}: from IP #{request.remote_ip} had #{@errors.size} errors for user: #{user ? user.login : 'anonymous'}")
      respond_to do |format|
        format.xml  { render :xml => get_error_xml(@errors) }
      end
    end
  end
  
  def gen_license_xml
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
