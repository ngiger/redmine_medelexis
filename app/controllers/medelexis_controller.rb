require 'tmpdir'
require 'xmlsimple'
require 'medelexis_helpers'

class MedelexisController < ApplicationController
  unloadable
  layout 'base'
  accept_rss_auth :rechnungen_erstellt
  accept_api_auth :rechnungen_erstellt
  def rechnungslauf
    RedmineMedelexis.log_to_system("rechnungslauf from IP #{request.remote_ip} via #{request.protocol}#{request.host_with_port}#{request.fullpath} user #{User.current} : rechnungen_erstellt #{params['key']} action_name #{action_name}")
    if request.post?
      data =params['rechnungslauf_form']
      string = "#{data['release_date(1i)']}-#{data['release_date(2i)']}-#{data['release_date(3i)']}"
      @stichtag = Date.parse(string)
      project_to_invoice = data['project_to_invoice']

      if project_to_invoice and project_to_invoice.length > 0
        MedelexisInvoices.invoice_for_project(project_to_invoice, @stichtag)
      else
        MedelexisInvoices.startInvoicing(@stichtag)
      end
      redirect_to :controller => 'invoices' # , :action => '/invoices'
    else
      render :action => 'rechnungslauf'
    end
  end
end

