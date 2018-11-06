require 'tmpdir'
require 'xmlsimple'
require 'medelexis_helpers'
# require 'ostruct'

class MedelexisController < ApplicationController
  unloadable
  layout 'base'
  accept_rss_auth :rechnungen_erstellt
  accept_api_auth :rechnungen_erstellt
  accept_rss_auth :correct_invoice_lines
  accept_api_auth :correct_invoice_lines
  accept_rss_auth :confirm_invoice_lines
  accept_api_auth :confirm_invoice_lines
  accept_rss_auth :alle_rechnungen
  accept_api_auth :alle_rechnungen
  accept_rss_auth :alle_kunden
  accept_api_auth :alle_kunden

  MEDELEXIS_SETTINGS = '/settings/plugin/redmine_medelexis'
  MEDELEXIS_CSV_CONG = {col_sep: ";",
              row_sep: "\n",
              headers: true,
              encoding: Encoding::UTF_8
             }
  def alle_kunden
    respond_to do |format|
      format.csv { return alle_kunden }
    end
  end

  def alle_kunden
    @kunden = []
    Project.all.each do |project|
      begin
        kontakt = RedmineMedelexis.getHauptkontakt(project.id)
      rescue
        kontakt = nil
      end
      next unless kontakt
      kunde = OpenStruct.new
      kunde.project = project
      kunde.kontakt =kontakt
      @kunden << kunde
    end
    csv_string = CSV.generate(MEDELEXIS_CSV_CONG) do |csv|
      csv << ['Project-Id', 'Project-Name', 'Kunden-Id', 'Status', 'Verrechnen', 'Mandanten', 'Stationen', 'Telefon', 'E-Mail', 'Web-Seite', 'Strasse', 'Strasse2', 'Land', 'PLZ', 'Ort' ]
      @kunden.each do |kunde|
        csv << [ kunde.project.id,
          kunde.project.name,
          kunde.kontakt.id,
          kunde.project.kundenstatus,
          kunde.project.keineVerrechnung ? 'Keine Verrechnung' : '',
          kunde.project.nrDoctors,
          kunde.project.nrStations,
          kunde.kontakt.phone ? kunde.kontakt.phone.gsub(',', ' / ').gsub('"','') : '',
          kunde.kontakt.email,
          kunde.kontakt.website,
          kunde.kontakt.address.street1 ? kunde.kontakt.address.street1.gsub('"','') : '',
          kunde.kontakt.address.street2 ? kunde.kontakt.address.street2.gsub('"','') : '',
          kunde.kontakt.address.country,
          kunde.kontakt.address.postcode,
          kunde.kontakt.address.city 
        ]
      end
    end
    send_data(
      csv_string,
      :type => 'text/csv',
      :filename => 'alle_kunden.csv',
      :disposition => 'attachment'
    )
  end

  def alle_rechnungen
    respond_to do |format|
      format.csv { return alle_rechnungen }
    end
  end

  def alle_rechnungen
    @invoices=Invoice.all
    csv_string = CSV.generate(MEDELEXIS_CSV_CONG) do |csv|
      csv << ['Project-Id', 'Project-Name', 'Rechnungs-Id', 'Status', 'Betrag', 'Fällig am','Titel', 'Zeile 1', 'Zeile 2', 'Zeile 3']
      @invoices.sort_by{|x| x.project_id }.each do |invoice|
        lines = invoice.description.split(/[\r\n]+/)
        line_1 = lines[0]
        line_2 = lines[1]
        line_3 = lines[2]
        csv << [invoice.id,
                Project.find(invoice.project_id).name,
                invoice.number,
                invoice.status_id,
                invoice.amount,
                [Invoice::PAID_INVOICE, Invoice::CANCELED_INVOICE].index(invoice.status_id) ? '' : (invoice.due_date ? invoice.due_date.strftime('%Y.%m.%d') : 'nil'),
                invoice.subject,
                # /\d{4}-\d{2}-\d{2}/.match(invoice.description.split(/[\r\n]+/)[-1]),
                line_1,
                line_2,
                line_3,
          ]
      end
    end
    send_data(
      csv_string,
      :type => 'text/csv',
      :filename => 'alle_rechnungen.csv',
      :disposition => 'attachment'
    )
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


  def correct_invoice_lines
    RedmineMedelexis.log_to_system("correct_invoice_lines from IP #{request.remote_ip} via #{request.protocol}#{request.host_with_port}#{request.fullpath} user #{User.current} : rechnungen_erstellt #{params['key']} action_name #{action_name}")
    @name_to_search = params[:name_to_search]
    if request.post?
      @name_to_search = params['search_invoice_lines']['name_to_search']
      begin
        @found_lines =  MedelexisInvoices.get_lines(@name_to_search)
        if @found_lines.sort.uniq.size == 1
          redirect_to :controller => "medelexis", :action => "confirm_invoice_lines", :name_to_search => @name_to_search
        else
          render :action => 'correct_invoice_lines', :search => @name_to_search
        end
      rescue => exception
        flash[:notice] = exception.to_s + "\n<br> Stacktrace is\n<br>" +  exception.backtrace[0..9].join("\n<br>")
        redirect_to MEDELEXIS_SETTINGS
      end
    else
      render :action => 'correct_invoice_lines'
    end
  end

  def confirm_invoice_lines
    RedmineMedelexis.log_to_system("confirm_invoice_lines from IP #{request.remote_ip} via #{request.protocol}#{request.host_with_port}#{request.fullpath} user #{User.current} : rechnungen_erstellt #{params['key']} action_name #{action_name}")
    if request.post?
      @change_name_to = params['change_invoice_lines']['change_name_to']
      @name_to_search = params['change_invoice_lines']['name_to_search']
      begin
        @found_lines =  MedelexisInvoices.get_lines(@name_to_search)
        changed_lines =  MedelexisInvoices.change_line_items(@name_to_search, @change_name_to)
        redirect_to :controller => "medelexis", :action => "changed_invoice_lines",
            :name_to_search => @name_to_search,
            :change_name_to => @change_name_to,
            :cl => changed_lines
      rescue => exception
        flash[:notice] = exception.to_s + "\n<br> Stacktrace is\n<br>" +  exception.backtrace[0..9].join("\n<br>")
        redirect_to MEDELEXIS_SETTINGS
      end
    else
      render :action => 'confirm_invoice_lines'
    end
  end

end

