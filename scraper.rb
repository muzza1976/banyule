require 'scraperwiki'
require 'mechanize'

agent = Mechanize.new

baseurl = "https://www.banyule.vic.gov.au/Planning-building/Review-local-planning-applications/Planning-applications-on-public-notice"
pageindex=1

loop do
  url = baseurl + "?dlv_OC%20CL%20Public%20Works%20and%20Projects=(pageindex=#{pageindex})"
  
  page = agent.get(url)

  page.search('.listing-results+.list-container .list-item-container a').each do |application|
    detail_page = agent.get(application.attributes['href'].to_s)
    notice_date = application.search('p').inner_text.strip.split(/Final da(y|te) of notice: /)[2]
    header = detail_page.search('h1.oc-page-title').inner_text.strip.to_s
    council_reference = header.split(/(.*) - (.*)/)[2]
    unless council_reference
      council_reference = header.split(/(.* )(P[0-9]+\/[0-9]+)/)[2]
    end

    unless council_reference
      puts "Could not extract a council_reference from: #{header}"
      puts "Skipping to next record"
      break
    end

    address = detail_page.search('p:contains("View Map")').inner_text.split("View Map")[0].gsub("\u00A0", " ").strip.to_s + " VIC"
    
    record = {
      "council_reference" => council_reference.to_s,
      "address" => address,
      "description" => detail_page.search('.project-details-list+p').inner_text.strip.to_s,
      "info_url"    => application.attributes['href'].to_s,
      "date_scraped" => Date.today.to_s,
      "on_notice_to" => DateTime.parse(notice_date).to_date.to_s
    }

    puts "Saving record " + record['council_reference'] + " - " + record['address']
    #puts record
    ScraperWiki.save_sqlite(['council_reference'], record)
  end
  
  next_button = page.search('.button-next input')[0]
  next_button_disabled = next_button.attributes.member? "disabled"
  break if next_button_disabled
  pageindex = pageindex + 1
  puts "Continuing to page #{pageindex}"
end
