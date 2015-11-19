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
      @invoice_since= verify_date(data, 'invoice_since')
      @invoice_til = verify_date(data, 'release_date')
      project_to_invoice = data['project_to_invoice']

      if project_to_invoice and project_to_invoice.length > 0
        MedelexisInvoices.invoice_for_project(project_to_invoice, @invoice_til, @invoice_since)
      else
        MedelexisInvoices.startInvoicing(@invoice_til)
      end
      redirect_to :controller => 'invoices' # , :action => '/invoices'
    else
      render :action => 'rechnungslauf'
    end
  end
  private
  def verify_date(data, name)
    string = "#{data[name + '(1i)']}-#{data[name + '(2i)']}-#{data[name + '(3i)']}"
    begin
      return Date.parse(string)
    rescue ArgumentError => e
      msg = "Konnte Datum #{string} nicht umwandeln #{e}"
      redirect_to home_path,
        error: msg
    end
  end
end

