require 'tmpdir'
require 'xmlsimple'
require 'medelexis_invoices'

class LicenseController < ApplicationController
  unloadable
  layout 'base'
  accept_rss_auth :index
  accept_api_auth :index, :show, :create, :update, :destroy
  skip_before_filter :check_if_login_required

  helper :invoices
  include InvoicesHelper

# Zum Testen http://0.0.0.0:30001/my/license.xml?key=fe2167a329f3c22799b1bcc3cb8cf93e7688f136 # development
# http://0.0.0.0:30001/my/license?e631d4560a13047970cc2ba4a95519782bdd4106.xml
  def show
    RedmineMedelexis.log_to_system("show from IP #{request.remote_ip} via #{request.protocol}#{request.host_with_port}#{request.fullpath} user #{User.current} : api_key is #{params['key']} action_name #{action_name} enabled?#{Setting.rest_api_enabled?}  api_key_from_request #{api_key_from_request}")
    @user = find_user(params)
    find_license_info
    respond_to do |format|
      format.html { render template: "license/show"; }
      format.xml  { if  @info then render :xml => @encrypted else render_error(:status => :unauthorized) end; }
      format.api  { render template: "license/show"; }
    end
  end

  def rechnungen_erstellt
    RedmineMedelexis.log_to_system("show from IP #{request.remote_ip} via #{request.protocol}#{request.host_with_port}#{request.fullpath} user #{User.current} : rechnungen_erstellt #{params['key']} action_name #{action_name}")
    # @order_status = OrderStatus.new(params[:order_status])
    if request.post?
      # redirect_to :controller => "license", :action => 'rechnungen_erstellt'
      puts "params are #{params} "
      data =params['rechnungslauf_form']
      string = "#{data['release_date(1i)']}-#{data['release_date(2i)']}-#{data['release_date(3i)']}"
      @stichtag = Date.parse(string)
      puts "project_to_invoice are #{params['project_to_invoice'].inspect} "
      if params['project_to_invoice'] and params['project_to_invoice'].length > 0
        puts "Nothing invoiced at the moment"
      else
        MedelexisInvoices.startInvoicing(@stichtag)
      end
      # render :action => 'rechnungen_erstellt'
      redirect_to :controller => 'invoices' # , :action => '/invoices'
    end
  end
  
private
  def find_user(params)
    check_if_login_required if params['key'] == nil
    if params['key'] == nil and params['login']
      @user = User.find_by_login(params['login'])
      RedmineMedelexis.log_to_system("#{__LINE__}: Must use user passed as login #{params['login']} is #{@user}. current User #{User.current}")
    elsif params['key'] == nil and not User.current.anonymous?
      RedmineMedelexis.log_to_system("#{__LINE__}: Must use current User #{User.current} login #{User.current.login} id #{User.current.id}")
      @user = User.current
    else
      @user = User.find_by_api_key(params['key'])
      RedmineMedelexis.log_to_system("#{__LINE__}: Found user #{@user.inspect} by apikey #{params['key'].inspect}")
    end
    RedmineMedelexis.debug("#{__LINE__}: user ist #{@user.inspect}")
    @user
  end
  
  def find_license_info
    if @user
      @api_key =  RedmineMedelexis.get_api_key(@user.login)
      RedmineMedelexis.debug("#{__LINE__}: user ist #{@user.login}")
      @info = RedmineMedelexis.license_info_for_user(@user)
      RedmineMedelexis.debug("#{__LINE__}: @info ist #{@info.inspect}")
      @encrypted = RedmineMedelexis.encrypt(@info, @user.login)
    else
      @api_key = nil
      @info = nil
    end
  end
end

