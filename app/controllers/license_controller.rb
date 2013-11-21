class LicenseController < ApplicationController
  unloadable
  layout 'base'
#  before_filter :find_user
  
  def gen_license_xml
    # Erstelle MedelexisLicenseFile.xml auf Basis MedelexisLicenseFile.xsd mit Enveloped Template MedelexisLicenseFileWithSignatureTemplate.xml
    # Signiere Datei 
    # Verschlüsselte Datei
    @errors = []
    @curUser = find_user
    @errors << "Could not determine userid" unless @curUser
    @errors << "Cannot create license for user anonymous" if @curUser and @curUser.anonymous?
    data_dir = File.expand_path(File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', 'data'))
    keystore          = '/srv/distribution-keys'
    signingKey        = "#{keystore}/signingKey.pem"
    encryptionKeyPub  = "#{keystore}/encryptionKeyPub.pem"
    template          = "#{keystore}/session-key-template.xml"
    [signingKey, encryptionKeyPub, template].each{ |f| @errors << "Missing file #{f}" unless File.exists?(f) }
    @errors << "Cannot create license for user anonymous" if @curUser and @curUser.anonymous?
    if @errors.size == 0 and @curUser
      license           = "#{data_dir}/#{@login_name}.xml"
      FileUtils.cp("#{data_dir}/default.xml", license, :verbose => true, :preserve => true) unless File.exists?(license)
      signed            = "#{data_dir}/#{@login_name}_signed.xml"
      crypted           = "#{data_dir}/#{@login_name}_crypted.xml"
      cmd_1 =  "xmlsec1 sign --privkey-pem #{signingKey} #{license} > #{signed}"
      cmd_2 =  "xmlsec1 encrypt --pubkey-pem #{encryptionKeyPub} --session-key des-192 --xml-data  #{signed} --output #{crypted}  #{template}"
      okay = system(cmd_1) and system(cmd_2) and
          system("logger #{File.basename(__FILE__)}: from IP #{request.remote_ip} signed  #{crypted} #{File.size(crypted)} bytes #{File.ctime(crypted)}")
      respond_to do |format|
        format.xml  { render :xml => IO.read(crypted) }
      end
    else
      respond_to do |format|
        format.xml  { render :xml => get_error_xml(@login_name, @errors) }
        puts request.inspect
      end
    end
  end
  
private
  def find_user
    User.find_by_id(request.session[:user_id])
  end
  
  def get_error_xml(user, error)
    error_xml = %(
<note>
<heading>Error generating license for user '#{@login_name}'</heading>
<reasons>
  <reason>#{error.join("</reason>\n  <reason>")}
  </reason>
</reasons>
</note>
)
  end

end
