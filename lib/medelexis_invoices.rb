#!/usr/bin/env ruby
#encoding: utf-8

File.expand_path('../redmine_medelexis', __FILE__)
require 'medelexis_helpers'
require 'redmine_medelexis'

class Project
  CustomFieldIdKundenstatus = CustomField.find(:first, :conditions => { :name => 'Kundenstatus'} ).id
  CustomFieldIdNrDoctors    = CustomField.find(:first, :conditions => { :name => '# Ärzte'} ).id
  def nrDoctors
    custom_value_for(CustomFieldIdNrDoctors).value.to_i
  end
  def kundenstatus
    custom_field_values # forces evaluation. Avoids an error in test/functional
    custom_value_for(CustomFieldIdKundenstatus).value
  end
end

class Invoice
  CustomFieldIdStichtag     = CustomField.find(:first, :conditions => { :name => 'Stichtag'} ).id
  def stichtag
    Date.parse(custom_value_for(CustomFieldIdStichtag).value)
  end
end

module MedelexisInvoices
  DiscountMap = { 1 => 1,
                  2 => 1.7,
                  3 => 2.3,
                  4 => 2.9,
                  5 => 3.5,
                  6 => 4}
  MaxDiscount = 0.5
  # DatumsFormat = '%d.%m.%Y'
  DatumsFormat = '%Y-%m-%d'

  def self.findAllOpenServicesForProjectID(project_id)
    Issue.find(:all, :conditions => { :project_id => project_id, :tracker_id => 4 } )
  end

  def self.findLastInvoice(project_id)
    project = Project.find(project_id)
    invoices = Invoice.find(:all, :conditions => {:project_id => project.id})
    invoices.max {|a,b| a.stichtag <=> b.stichtag }
  end

  def self.getDaysOfYearFactor(issue_id, stichtag = Date.today.to_datetime.end_of_year)
    issue = Issue.find(:first, :conditions => {:id => issue_id})
    status = issue.custom_field_values.first.value
    daysThisYear = (stichtag.end_of_year.to_date - stichtag.beginning_of_year + 1).to_i
    return 0, 31 if status == 'TRIAL'
    return 1, daysThisYear if issue.start_date == Date.today.beginning_of_year and status == 'LICENSED'
    nrDays = (stichtag.end_of_year.to_date - issue.start_date).to_i
    return nrDays.to_f/daysThisYear, nrDays if status == 'LICENSED'
    nrDays = issue.updated_on.utc.yday - issue.start_date.yday
    return nrDays.to_f/daysThisYear, nrDays if status == 'CANCELLED' or status == 'EXPIRED'
    puts "What TODO with status #{status} stichtag #{stichtag} and issue.start_date #{issue.start_date}"
    puts issue.inspect
    100000 # Damit dieser Fall auch wirklich auffällt und kein Kunde dies bezahlt
  end

  def self.invoicedFeature(invoice)
    invoice.lines.collect{ |x| x.description.split('. ')[0] unless x.description.match(/gerundet/i) }.compact
    # or invoice.lines.collect{ |x| x.description.split('. ')[0] if x.description.match(/feature/) }.compact
  end

  def self.findProjects2invoice(stichtag = Date.today.end_of_year)
    idx = 0
    project_ids2invoice = []
    Project.all.each{
      | project|
        next unless ['Neukunde', 'Kunde'].index(project.kundenstatus)
        lastInvoice = findLastInvoice(project.id)
        puts "Invoicing #{idx} project #{project.id}. #{lastInvoice ? "Last invoice was #{lastInvoice.id} of #{lastInvoice.custom_field_values}" : 'No last invoice'} " if $VERBOSE
        next if lastInvoice and lastInvoice.stichtag >= stichtag
        project_ids2invoice << project.id
        idx += 1
        # break if idx > 5
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

    issues.each{
      |issue|
        subject = issue.subject.sub('feature.group', 'feature').sub('feature.feature', 'feature')
        product = Product.find(:first, :conditions => {:code => subject})
        next unless product
        price = product.price.to_f
        factor, days = getDaysOfYearFactor(issue)
        if factor == 0
          description += "\n#{subject} gratis da noch im ersten Monat"
          next
        elsif factor != 1
          factor = factor.round(2)
          subject += ". Grundpreis von #{price} wird für #{days} Tage verrechnet (Faktor #{factor})."
          price = price * factor
        end
        puts "found product #{product} for issue #{issue} price is #{price}" if $VERBOSE
        invoice.lines << InvoiceLine.new(:description => subject, :quantity => multiplier, :price => price, :units => "Feature")
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
      projects.each{ |id| invoice_for_project(id, stich_tag, round_to) }
      duration = (Time.now-startTime).to_i
      RedmineMedelexis.log_to_system("startInvoicing created #{Invoice.all.size - oldSize} invoices for #{projects.size} of #{Project.all.size} projects. Ids were #{projects}")
    end
    projects
  end

end