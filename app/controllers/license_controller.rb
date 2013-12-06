require 'tmpdir'
require 'xmlsimple'

class LicenseController < ApplicationController
  unloadable
  layout 'base'
#  before_filter :authorize, :except => [ :index, :list, :new, :create, :copy, :archive, :unarchive, :destroy]
#  before_filter :authorize_global, :only => [:new, :create]
  accept_rss_auth :index, :gen_license
  accept_api_auth :index, :show, :create, :update, :destroy, :gen_license
  skip_before_filter :check_if_login_required
# Zum Testen http://0.0.0.0:30001/my/license/fe2167a329f3c22799b1bcc3cb8cf93e7688f136.xml # development
# http://0.0.0.0:30001/my/license?e631d4560a13047970cc2ba4a95519782bdd4106.xml
  def gen_license
    RedmineMedelexis.log_to_system("gen_license_xml_via_api from IP #{request.remote_ip} user #{User.current} : api_key is #{params['key']} action_name #{action_name} enabled?#{Setting.rest_api_enabled?}  api_key_from_request #{api_key_from_request}")
    check_if_login_required if params['key'] == nil
    if params['key'] == nil and not User.current.anonymous?
      RedmineMedelexis.log_to_system("333: Must use current User #{User.current}")
      user = User.current
    else
      user = User.find_by_api_key(params['key'])
      RedmineMedelexis.log_to_system("3334: Found user #{user.inspect} by apikey #{params['key'].inspect}")
    end
    info = RedmineMedelexis.license_info_for_user(user)
    xml  = RedmineMedelexis.xml_content(info)
    respond_to do |format|
      format.html { render template: "license/show.html.erb" }
#      format.api
      format.xml  { render :xml => xml; }
    end
  end
private

  def find_user(params)
    user_by_session = User.find_by_id(request.session[:user_id])
    return nil unless user_by_session
    return User.find_by_id(user_by_session) if params[:login].eql?('current')
    return User.find_by_login(params[:login]) if params[:login].eql?(user_by_session.login)
    return nil unless user_by_session.admin?
    return User.find_by_login(params[:login]) if params[:login]
    nil
  end
end

