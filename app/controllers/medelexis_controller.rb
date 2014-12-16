require 'tmpdir'
require 'xmlsimple'
require 'medelexis_helpers'

class MedelexisController < ApplicationController
  unloadable
  layout 'base'
  accept_rss_auth :rechnungen_erstellt
  accept_api_auth :rechnungen_erstellt

  def rechnungslauf
    render :action => 'rechnungslauf'
  end

  def rechnungen_erstellt
    RedmineMedelexis.log_to_system("show from IP #{request.remote_ip} via #{request.protocol}#{request.host_with_port}#{request.fullpath} user #{User.current} : rechnungen_erstellt #{params['key']} action_name #{action_name}")
    # @order_status = OrderStatus.new(params[:order_status])
    if request.post?
      # redirect_to :controller => "license", :action => 'rechnungen_erstellt'
      data =params['rechnungslauf_form']
      string = "#{data['release_date(1i)']}-#{data['release_date(2i)']}-#{data['release_date(3i)']}"
      @stichtag = Date.parse(string)
      if params['project_to_invoice'] and params['project_to_invoice'].length > 0
        MedelexisInvoices.invoice_for_project(params['project_to_invoice'], DateTime.now.end_of_year.to_date, BigDecimal.new('0.05'))
      else
        MedelexisInvoices.startInvoicing(@stichtag)
      end
      # render :action => 'rechnungen_erstellt'
      redirect_to :controller => 'invoices' # , :action => '/invoices'
    end
  end
end

