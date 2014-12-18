#!/usr/bin/env ruby
#encoding: utf-8

File.expand_path('../redmine_medelexis', __FILE__)
require 'medelexis_helpers'

class Project
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
    Date.parse(field.value)
  end

  def self.findAllOpenServicesForProjectID(project_id)
    Issue.find(:all, :conditions => { :project_id => project_id, :tracker_id => 4 } )
  end

  def self.getDateOfLastInvoice(project_id)
    projects = Project.find(:all, :conditions => { :id => project_id } )
    return nil unless projects.size > 0
    project = projects.first
    invoices = Invoice.find(:all, :conditions => {:project_id => project.id})
    return nil unless invoices.size > 0
    last = invoices.max {|a,b| stichtag(a) <=> stichtag(b) }
    stichtag(last)
  end

  def self.getDaysOfYearFactor(issue_id, date_last_invoice, day2invoice = Date.today.to_datetime.end_of_year)
    issue = Issue.find(:first, :conditions => {:id => issue_id})
    status = issue.custom_field_values.first.value
    daysThisYear = (day2invoice.end_of_year.to_date - day2invoice.beginning_of_year + 1).to_i
    return 0, 31 if status == 'TRIAL'
    return 1, daysThisYear if issue.start_date == Date.today.beginning_of_year and status == 'LICENSED'
    if date_last_invoice
      nrDays = (day2invoice.end_of_year.to_date - date_last_invoice).to_i
    else
      nrDays = (day2invoice.end_of_year.to_date - issue.start_date).to_i
    end
    return nrDays.to_f/daysThisYear, nrDays if status == 'LICENSED'
    nrDays = issue.updated_on.utc.yday - issue.start_date.yday
    return nrDays.to_f/daysThisYear, nrDays if status == 'CANCELLED' or status == 'EXPIRED'
    puts "What TODO with status #{status} day2invoice #{day2invoice} and issue.start_date #{issue.start_date}"
    puts issue.inspect
    100000 # Damit dieser Fall auch wirklich auffällt und kein Kunde dies bezahlt
  end

  def self.invoicedFeature(invoice)
    invoice.lines.collect{ |x| x.description.split('. ')[0] unless x.description.match(/gerundet/i) }.compact
    # or invoice.lines.collect{ |x| x.description.split('. ')[0] if x.description.match(/feature/) }.compact
  end

  def self.findProjects2invoice(day2invoice = Date.today.end_of_year)
    idx = 0
    project_ids2invoice = []
    Project.all.each{
      | project|
        status = project.custom_value_for(CustomField.find(:first, :conditions => { :name => 'Kundenstatus'} ).id)
        status = status.value if status
        next unless status and ['Neukunde', 'Kunde'].index(status)
        dateLastInvoice = getDateOfLastInvoice(project.id)
        puts "Invoicing #{idx} project #{project.id}. #{dateLastInvoice ? 'No invoice found' : 'dateLastInvoice ' + dateLastInvoice.to_s}" if $VERBOSE
        next if dateLastInvoice and dateLastInvoice >= day2invoice
        project_ids2invoice << project.id
        idx += 1
        break if OnlyFirst
    }
    project_ids2invoice
  end

  def self.invoice_for_project(identifier, stich_tag = Date.today.end_of_year.to_date, round_to = BigDecimal.new('0.05'))
    if identifier.to_i >0
      project= Project.find(identifier.to_i)
    else
      project= Project.find(:first,  :conditions => {:identifier => identifier})
    end
    admin = User.find(:first, :conditions => {:admin => true})
    nrDoctors = project.nrDoctors
    multiplier = nrDoctors <= 6 ? DiscountMap[nrDoctors] : DiscountMap[6] + (nrDoctors-6)*MaxDiscount
    puts "project identifier #{identifier} with #{nrDoctors} doctors multiplier #{multiplier} is #{project}" if $VERBOSE

    issues = findAllOpenServicesForProjectID(project.id)
    issues.flatten!
    stich_tag_string = stich_tag.strftime(DatumsFormat)
    contact = Contact.find(:first, :conditions => {:first_name => project.name})
    unless contact
      RedmineMedelexis.log_to_system("Could not find a contact for #{project.name} #{project.inspect}")
      puts("Could not find a contact for #{project.name} #{project.inspect} ")
      return
    end
    puts "Invoicing for #{identifier} contact #{contact} til #{stich_tag_string}" if $VERBOSE
    rechnungs_nummer = "Rechnung #{Time.now.strftime(DatumsFormat)}-#{Invoice.last ? Invoice.last.id+1 : 1}"
    invoice = Invoice.new
    invoice.number = rechnungs_nummer
    invoice.invoice_date = Time.now
    description = "Rechnung mit Stichtag vom #{stich_tag_string} für #{nrDoctors == 1 ? 'einen Arzt' : nrDoctors.to_s + ' Ärzte'}."
    description += "\nMultiplikator für abonnierte Features ist #{multiplier}." if multiplier != 1
    invoice.subject = "Rechnung für Abonnment Medelexis"
    invoice.project = project
    invoice.contact_id = contact.id
    invoice.due_date = (stich_tag + 30).to_datetime # to_datetime needed or we would get local time!
    invoice.assigned_to = admin
    invoice.language = "DE"
    invoice.status_id  = Invoice::DRAFT_INVOICE
    invoice.currency ||= ContactsSetting.default_currency
    invoice.id = (Invoice.last.try(:id).to_i + 1).to_s
    date_last_invoice = getDateOfLastInvoice(project.id)
    issues.each{
      |issue|
        subject = issue.subject.sub('feature.group', 'feature').sub('feature.feature', 'feature')
        product = Product.find(:first, :conditions => {:code => subject})
        next unless product
        line_description = product.name # + ". Wiki: http://wiki.elexis.info/#{subject}.feature.group"
        price = product.price.to_f
        factor, days = getDaysOfYearFactor(issue, date_last_invoice, stich_tag)
        if factor == 0
          line_description += "\n#{subject} gratis da noch im ersten Monat"
          next
        elsif factor != 1
          factor = factor.round(2)
          subject += ". Grundpreis von #{price} wird für #{days} Tage verrechnet (Faktor #{factor})."
          price = price * factor
        end
        puts "found product #{product} for issue #{issue} price is #{price}" if $VERBOSE
        invoice.lines << InvoiceLine.new(:description => line_description, :quantity => multiplier, :price => price, :units => "Feature")
        break if OnlyFirst
    }
    invoice.lines.sort! { |a,b| b.price <=> a.price } # by price descending
    puts "Added #{invoice.lines.size} lines (of #{issues.size} service tickets). Stich_tag #{stich_tag.strftime(DatumsFormat)} due #{invoice.due_date.strftime(DatumsFormat)} description is now #{description}" if $VERBOSE
    invoice.description  = description
    invoice.custom_field_values.first.value = stich_tag_string
    invoice.save_custom_field_values
    amount = BigDecimal.new(invoice.calculate_amount.to_d)
    rounding_difference  = (amount % round_to)
    unless rounding_difference == 0
      invoice.lines << InvoiceLine.new(:description => "Gerundet zugunsten Kunde", :quantity => 1, :price => -rounding_difference)
      puts "Invoice for #{identifier}: rounded by #{rounding_difference.to_f.round(2)}. Now #{invoice.calculate_amount.round(2)}"
    end
    invoice.save
    invoice
  end

  def self.startInvoicing(stich_tag = Date.today.end_of_year.to_date, round_to = BigDecimal.new('0.05'))
    projects = []
    RedmineMedelexis.log_to_system("startInvoicing: stichtag #{stich_tag.strftime(DatumsFormat)} and round_to #{round_to}")
    ActiveRecord::Base.transaction do
      startTime = Time.now
      oldSize = Invoice.all.size
      projects = findProjects2invoice(stich_tag)
      RedmineMedelexis.log_to_system "Found #{projects.size} projects. #{projects}"
      projects.each{ |id| invoice_for_project(id, stich_tag, round_to) }
      duration = (Time.now-startTime).to_i
      RedmineMedelexis.log_to_system("startInvoicing created #{Invoice.all.size - oldSize} invoices for #{projects.size} of #{Project.all.size} projects. Ids were #{projects}")
    end
    projects
  end

end