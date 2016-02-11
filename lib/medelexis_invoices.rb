#!/usr/bin/env ruby
#encoding: utf-8

File.expand_path('../redmine_medelexis', __FILE__)
require 'medelexis_helpers'

class Project
  def keineVerrechnung
    return false unless field = CustomField.find(:first, :conditions => { :name => 'Keine Verrechnung'} )
    return false unless custom = custom_value_for(field.id)
    custom.value.to_i > 0 ? true : false
  end
  def nrDoctors
    custom_value_for(CustomField.find(:first, :conditions => { :name => '# Ärzte'} ).id).value.to_i
  end
  def kundenstatus
    custom_field_values # forces evaluation. Avoids an error in test/functional
    value = custom_value_for(CustomField.find(:first, :conditions => { :name => 'Kundenstatus'} ).id)
    value ? value.value : nil
  end
end

module MedelexisInvoices
  OnlyFirst   = false # for debugging purposes
  DiscountMap = { 1 => 1,
                  2 => 1.7,
                  3 => 2.3,
                  4 => 2.9,
                  5 => 3.5,
                  6 => 4}
  MaxDiscount = 0.5
  DatumsFormat = '%Y-%m-%d'

  def self.stichtag(invoice)
    field = invoice.custom_value_for(CustomField.find(:first, :conditions => { :name => 'Stichtag'} ).id)
    return Date.new(invoice.invoice_date) unless field
    puts "invoice #{invoice.id} had invoice_date #{field} for #{invoice.subject}" if $VERBOSE
    Date.parse(field.value)
  end

  def self.findAllOpenServicesForProjectID(project_id)
    Issue.find(:all, :conditions => { :project_id => project_id, :tracker_id => RedmineMedelexis::Tracker_Is_Service } )
  end

  def self.getDateOfLastInvoice(project_id)
    projects = Project.find(:all, :conditions => { :id => project_id } )
    unless projects.size > 0
      puts "getDateOfLastInvoice no projects found for #{project_id}" if $VERBOSE
      return nil
    end
    project = projects.first
    invoices = Invoice.find(:all, :conditions => {:project_id => project.id})
    unless invoices.size > 0
      puts "getDateOfLastInvoice no invoices found for #{project_id}" if $VERBOSE
      return nil
    end
    last = invoices.max {|a,b| stichtag(a) <=> stichtag(b) }
    lastDate = stichtag(last)
    puts "getDateOfLastInvoice lastDate for #{project_id} was #{lastDate}" if $VERBOSE
    lastDate
  end

  def self.getDaysOfYearFactor(issue_id, invoice_since, day2invoice = Date.today.to_datetime.end_of_year)
    issue = Issue.find(:first, :conditions => {:id => issue_id})
    status = issue.custom_field_values.first.value
    daysThisYear = (day2invoice.end_of_year.to_date - day2invoice.beginning_of_year.to_date + 1).to_i
    return 0, 31 if status == 'TRIAL'
    if status == 'LICENSED'
      if issue.start_date < invoice_since
        nrDays = (day2invoice - invoice_since).to_i
      else
        nrDays = (day2invoice - issue.start_date).to_i
      end
      if nrDays == daysThisYear
        return 1, daysThisYear
      else
        return nrDays.to_f/daysThisYear, nrDays
      end
    end
    if (invoice_since < issue.start_date)
      nrDays = (day2invoice - invoice_since).to_i
    else
      nrDays = (day2invoice - issue.start_date).to_i
    end
    if status == 'CANCELLED' or status == 'EXPIRED'
      used_till = issue.updated_on.to_date
      if used_till < invoice_since # already invoiced
        return 0, 0
      else
        nrDays = (used_till - invoice_since).to_i
      end
      return nrDays.to_f/daysThisYear, nrDays
    end
    puts "What TODO with status #{status} day2invoice #{day2invoice} and issue.start_date #{issue.start_date}"
    puts issue.inspect
    100000 # Damit dieser Fall auch wirklich auffällt und kein Kunde dies bezahlt
  end

  def self.invoicedFeature(invoice)
    invoice.lines.collect{ |x| x.description.split('. ')[0] unless x.description.match(/gerundet/i) }.compact
    # or invoice.lines.collect{ |x| x.description.split('. ')[0] if x.description.match(/feature/) }.compact
  end

  def self.findProjects2invoice(day2invoice = Date.today.end_of_year, invoice_since = nil)
    idx = 0
    project_ids2invoice = []
    Project.all.each{
      | project|
        status = project.kundenstatus
        next if project.keineVerrechnung
        next unless status and ['Neukunde', 'Kunde'].index(status)
        last_invoiced = getDateOfLastInvoice(project.id)
        puts "Invoicing #{idx} project #{project.id}. last  #{last_invoiced} invoice_since #{invoice_since} >= #{day2invoice}? #{invoice_since ? 'No invoice found' : 'invoice_since ' + invoice_since.to_s}" if $VERBOSE
        next if last_invoiced and last_invoiced > day2invoice
        project_ids2invoice << project.id
        idx += 1
        break if OnlyFirst
    }
    project_ids2invoice
  end

  def self.invoice_for_project(identifier, stich_tag = Date.today.end_of_year.to_date, invoice_since = nil)
    round_to = BigDecimal.new('0.05')
    if identifier.to_i >0
      project= Project.find(identifier.to_i)
    else
      project= Project.find(:first,  :conditions => {:identifier => identifier})
    end
    raise "Projekt '#{identifier}' konnte weder als Zahl noch als Name gefunden werden" unless project
    admin = User.find(:first, :conditions => {:admin => true})
    nrDoctors = project.nrDoctors
    multiplier = nrDoctors <= 6 ? DiscountMap[nrDoctors] : DiscountMap[6] + (nrDoctors-6)*MaxDiscount
    puts "project identifier #{identifier} with #{nrDoctors} doctors multiplier #{multiplier} keineVerrechnung #{project.keineVerrechnung} is: #{project}" if $VERBOSE
    raise "project '#{identifier}' soll nicht verrechnet werden" if project.keineVerrechnung
    issues = findAllOpenServicesForProjectID(project.id)
    issues.flatten!
    stich_tag_string = stich_tag.strftime(DatumsFormat)
    contact = RedmineMedelexis.getHauptkontakt(project.id)
    raise "Konnte keinen Hauptkontakt für Projekt '#{identifier}' finden"  unless contact
    puts "Invoicing for #{identifier} contact #{contact} til #{stich_tag_string}" if $VERBOSE
    rechnungs_nummer = "Rechnung #{Time.now.strftime(DatumsFormat)}-#{Invoice.last ? Invoice.last.id+1 : 1}"
    invoice = Invoice.new
    invoice.number = rechnungs_nummer
    invoice.invoice_date = Time.now
    invoice_since ||= getDateOfLastInvoice(project.id)
    invoice_since ||= Date.today.beginning_of_year.to_date
    description = "Rechnung mit Stichtag vom #{stich_tag_string} für #{nrDoctors == 1 ? 'einen Arzt' : nrDoctors.to_s + ' Ärzte'}."
    description += "\nMultiplikator für abonnierte Features ist #{multiplier}." if multiplier != 1
    description += "\nVerrechnet werden Leistungen vom #{invoice_since.to_s} bis #{stich_tag.to_s}."
    invoice.subject = "Rechnung für Abonnement Medelexis"
    invoice.project = project
    invoice.contact_id = contact.id
    invoice.due_date = (Time.now.utc.to_date) + 31
    invoice.assigned_to = admin
    invoice.language = "DE"
    invoice.status_id  = Invoice::DRAFT_INVOICE
    invoice.currency ||= ContactsSetting.default_currency
    invoice.id = (Invoice.last.try(:id).to_i + 1).to_s
    issues.each{
      |issue|
        subject = issue.subject.sub('feature.group', 'feature').sub('feature.feature', 'feature')
        product = Product.find(:first, :conditions => {:code => subject})
        next unless product
        status = issue.custom_field_values.first.value
        line_description = product.name # + ". Wiki: http://wiki.elexis.info/#{subject}.feature.group"
        grund_price = product.price.to_f
        next if grund_price.to_i == 0
        factor, days = getDaysOfYearFactor(issue, invoice_since, stich_tag)
        price = grund_price
        if factor == 0
          next unless status.eql?('TRIAL')
          line_description += "\n#{subject} gratis da noch im ersten Monat"
          invoice.lines << InvoiceLine.new(:description => line_description, :quantity => multiplier, :price => 0, :units => "Feature")
          next
        elsif factor != 1
          factor = factor.round(2)
          line_description += ". Grundpreis von #{grund_price} wird für #{days} Tage verrechnet (Faktor #{factor})."
          price = grund_price * factor
        end
        puts "found product #{product} #{product.code} #{product.price.to_f} for issue #{issue} price is #{price}" if $VERBOSE
        invoice.lines << InvoiceLine.new(:description => line_description, :quantity => multiplier, :price => price, :units => "Feature")
        break if OnlyFirst
    }
    invoice.lines.sort! { |a,b| b.price.to_i <=> a.price.to_i } # by price descending
    puts "Added #{invoice.lines.size} lines (of #{issues.size} service tickets). Stich_tag #{stich_tag.strftime(DatumsFormat)} due #{invoice.due_date.strftime(DatumsFormat)} description is now #{description}" if $VERBOSE
    invoice.description  = description
    invoice.custom_field_values.first.value = stich_tag_string
    invoice.save_custom_field_values
    amount = BigDecimal.new(invoice.calculate_amount.to_d)
    rounding_difference  = (amount % round_to)
    unless rounding_difference == 0
      invoice.lines << InvoiceLine.new(:description => "Gerundet zugunsten Kunde", :quantity => 1, :price => -rounding_difference)
    end
    if invoice.calculate_amount < 5
      RedmineMedelexis.log_to_system "Invoicing for #{identifier} #{project.name} skipped as amount #{invoice.calculate_amount.round(2)} is < 5 Fr."
      invoice.delete
      raise "Würde weniger als 5 Franken (#{invoice.calculate_amount}) für '#{identifier}' verrechnen"
    end
    RedmineMedelexis.log_to_system "Invoicing for #{identifier} #{project.name} amount #{invoice.calculate_amount.round(2)}. Has #{invoice.lines.size} lines "
    invoice.save
    invoice
  end

  def self.startInvoicing(stich_tag = Date.today.end_of_year.to_date, invoice_since = nil)
    projects = []
    RedmineMedelexis.log_to_system("startInvoicing: stichtag #{stich_tag.strftime(DatumsFormat)}")
    ActiveRecord::Base.transaction do
      startTime = Time.now
      oldSize = Invoice.all.size
      projects = findProjects2invoice(stich_tag, invoice_since)
      RedmineMedelexis.log_to_system "Found #{projects.size} projects. #{projects}"
      projects.each{ |id| invoice_for_project(id, stich_tag, invoice_since) }
      duration = (Time.now-startTime).to_i
      RedmineMedelexis.log_to_system("startInvoicing created #{Invoice.all.size - oldSize} invoices for #{projects.size} of #{Project.all.size} projects. Ids were #{projects}")
    end
    projects
  end

end