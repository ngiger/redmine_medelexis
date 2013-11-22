class LicenseController < ApplicationController
  unloadable
  layout 'base'
#  before_filter :find_user
  
  def gen_license_xml
    # Erstelle MedelexisLicenseFile.xml auf Basis MedelexisLicenseFile.xsd mit Enveloped Template MedelexisLicenseFileWithSignatureTemplate.xml
    # Signiere Datei 
    # Verschlüsselte Datei
    @errors = []
    userLogin = find_user(params)
    @errors << "Could not determine userid" unless userLogin
    @errors << "Cannot create license for user anonymous" if userLogin and userLogin.anonymous?
    data_dir = File.expand_path(File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'data'))
    keystore          = '/srv/distribution-keys'
    signingKey        = "#{keystore}/signingKey.pem"
    encryptionKeyPub  = "#{keystore}/encryptionKeyPub.pem"
    template          = "#{keystore}/session-key-template.xml"
    [signingKey, encryptionKeyPub, template].each{ |f| @errors << "Missing file #{f}" unless File.exists?(f) } # unless `hostname`.chomp.eql?('ng-tr')
    @errors << "Cannot create license for user anonymous" if userLogin and userLogin.anonymous? 
    if @errors.size == 0 and userLogin
      license           = "#{data_dir}/#{@login_name}.xml"
      FileUtils.cp("#{data_dir}/default.xml", license, :verbose => true, :preserve => true) unless File.exists?(license)
      signed            = "#{data_dir}/#{@login_name}_signed.xml"
      crypted           = "#{data_dir}/#{@login_name}_crypted.xml"
      cmd_1 =  "xmlsec1 sign --privkey-pem #{signingKey} #{license} > #{signed}"
      cmd_2 =  "xmlsec1 encrypt --pubkey-pem #{encryptionKeyPub} --session-key des-192 --xml-data  #{signed} --output #{crypted}  #{template}"
      okay = system(cmd_1) and system(cmd_2) and
          system("logger #{File.basename(__FILE__)}: from IP #{request.remote_ip} signed  #{crypted} #{File.size(crypted)} bytes #{File.ctime(crypted)}")
      respond_to do |format|
      # format.xml  { render :xml => IO.read("#{data_dir}/default.xml") }
      format.xml  { render :xml => IO.read(crypted) }
      end
    else
      respond_to do |format|
        format.xml  { render :xml => get_error_xml(params, @errors) }
        # puts request.inspect
      end
    end
  end
  
private
  def find_user(params)
    user_by_session = User.find_by_id(request.session[:user_id])
    msg =  "find_user: User.current '#{User.current}' by session '#{user_by_session}' params #{params}"
    puts msg
    puts params
    name = params[:login]
    name if params[:login] and params[:login].eql?('current')
    system("logger #{File.basename(__FILE__)}: #{msg}")
    return nil unless user_by_session 
    return User.find_by_id(user_by_session) if params[:login].eql?('current')
    return User.find_by_login(params[:login]) if params[:login].eql?(user_by_session.login)
    return nil unless user_by_session.admin?
    return User.find_by_login(params[:login]) if params[:login]
    nil
  end
  
  def get_error_xml(params, error)
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
