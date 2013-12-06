require 'tmpdir'
require 'xmlsimple'

class LicenseController < ApplicationController
  unloadable
  layout 'base'
  accept_rss_auth :index
  accept_api_auth :index, :show, :create, :update, :destroy
  skip_before_filter :check_if_login_required
# Zum Testen http://0.0.0.0:30001/my/license.xml?key=fe2167a329f3c22799b1bcc3cb8cf93e7688f136 # development
# http://0.0.0.0:30001/my/license?e631d4560a13047970cc2ba4a95519782bdd4106.xml
  def show
    RedmineMedelexis.log_to_system("show from IP #{request.remote_ip} user #{User.current} : api_key is #{params['key']} action_name #{action_name} enabled?#{Setting.rest_api_enabled?}  api_key_from_request #{api_key_from_request}")
    @user = find_user(params)
    find_license_info
    respond_to do |format| 
      format.html { render template: "license/show"; RedmineMedelexis.debug("#{__LINE__}: html") } 
      format.xml  { if  @xml then render :xml => @xml else render_error(:status => :unauthorized) end;  RedmineMedelexis.debug("#{__LINE__}: xml #{@xml.inspect} end")  } 
      format.api  { render template: "license/show"; RedmineMedelexis.debug("#{__LINE__}: api") } 
    end
  end
  
private
  def find_user(params)
    check_if_login_required if params['key'] == nil
    if params['key'] == nil and not User.current.anonymous?
      RedmineMedelexis.log_to_system("333: Must use current User #{User.current}")
      @user = User.current
    else
      @user = User.find_by_api_key(params['key'])
      RedmineMedelexis.log_to_system("3334: Found user #{@user.inspect} by apikey #{params['key'].inspect}")
    end
    RedmineMedelexis.debug("#{__LINE__}: user ist #{@user.inspect}")
    @user
  end
  
  def find_license_info
    if @user
      @api_key =  RedmineMedelexis.get_api_key(@user.login)
      RedmineMedelexis.debug("#{__LINE__}: user ist #{@user.inspect}")
      @info = RedmineMedelexis.license_info_for_user(@user)
      RedmineMedelexis.debug("#{__LINE__}: @info ist #{@info.inspect}")
      @xml  = RedmineMedelexis.xml_content(@info)
      RedmineMedelexis.debug("#{__LINE__}: @xml ist #{@xml.inspect}")
    else
      @api_key = nil
      @info = nil
      @xml = nil
    end
  end
end

