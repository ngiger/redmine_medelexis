require 'tmpdir'
require 'xmlsimple'
require 'medelexis_helpers'

class MedelexisController < ApplicationController
  unloadable
  layout 'base'
  accept_rss_auth :rechnungen_erstellt
  accept_api_auth :rechnungen_erstellt
  def alle_rechnungen
    @invoices=Invoice.find(:all)
  end

  def rechnungslauf
    RedmineMedelexis.log_to_system("rechnungslauf from IP #{request.remote_ip} via #{request.protocol}#{request.host_with_port}#{request.fullpath} user #{User.current} : rechnungen_erstellt #{params['key']} action_name #{action_name}")
    if request.post?
      data =params['rechnungslauf_form']
      string = "#{data['release_date(1i)']}-#{data['release_date(2i)']}-#{data['release_date(3i)']}"
      begin
        @stichtag = Date.parse(string)
      rescue ArgumentError => e
        msg = "Konnte Datum #{string} nicht umwandeln #{e}"
        redirect_to home_path,
          error: msg
      end
      since = "#{data['invoice_since(1i)']}-#{data['invoice_since(2i)']}-#{data['invoice_since(3i)']}"
      begin
        @since = Date.parse(since)
      rescue ArgumentError => e
        msg = "Konnte Datum #{since} nicht umwandeln #{e}"
        redirect_to home_path,
          error: msg
      end
      begin
        project_to_invoice = data['project_to_invoice']
        if project_to_invoice and project_to_invoice.length > 0
          MedelexisInvoices.invoice_for_project(project_to_invoice, @stichtag, @since)
        else
          MedelexisInvoices.startInvoicing(@stichtag, @since)
        end
        redirect_to :controller => 'invoices' # , :action => '/invoices'
      rescue => exception
        flash[:notice] = exception.to_s + "\n<br> Stacktrace is\n<br>" +  exception.backtrace[0..9].join("\n<br>")
        redirect_to "/medelexis/rechnungslauf"
      end
    else
      render :action => 'rechnungslauf'
    end
  end
end

