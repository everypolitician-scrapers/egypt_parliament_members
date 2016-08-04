#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'scraped_page_archive'
require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'
require 'scraped_page_archive/capybara'

Capybara.default_max_wait_time = 5

# images are very slow to load and cause timeouts and
# as we don't need them skip
options = {
    timeout: 60,
    phantomjs_options: ['--load-images=no']
}

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, options)
end

include Capybara::DSL
Capybara.default_driver = :poltergeist


class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def scrape_list(url, count)
  visit(url)

  find(:id, 'ctl00_MainContent_Button4').click
  scrape_next_page(count, url)
end

def scrape_next_page(count, url)
  scrape_page(url)

  visit(url)
  find(:id, 'ctl00_MainContent_Button4').click
  count = count + 1
  count_link = "//a[contains(.,'" + count.to_s + "')]"
  while page.has_xpath?(count_link)
    find(:xpath, count_link).click
    scrape_next_page(count, url)
  end
end

def scrape_page(url)
  count = 0
  rows = all('table#ctl00_MainContent_GridView1 tr')
  while not rows[count].nil?
    scrape_person(rows[count], url)
    count = count + 1
    rows = all('table#ctl00_MainContent_GridView1 tr')
  end
end

def date_of_birth(str)
  matched = str.match(/(\d+)\/(\d+)\/(\d+)/) or return
  year, month, day = matched.captures
  "%d-%02d-%02d" % [ year, month.to_i, day.to_i ]
end

def scrape_person(row, url)
    if not row.has_css?('td')
        return
    end

    cells = row.all(:css, 'td')
    if cells.size != 7
        return
    end

    data = {
        id: cells[1].text,
        name: cells[3].text.tidy,
        photo: cells[5].find('img')[:src],
        source: url,
    }

    # this seems to timeout quite often so just skip over it in
    # the hope that we gather everything over time
    begin
        cells[0].find('a').click
    rescue
        puts "failed to get extra data for %s, skipping" % [ data[:id] ]
        return
    end

    data[:date_of_birth] = date_of_birth(page.find('#ctl00_MainContent_Label13').text) rescue ""
    data[:party] = page.find('span#ctl00_MainContent_Label26').text.tidy rescue ""
    data[:cons] = page.find('span#ctl00_MainContent_Label24').text.tidy rescue ""

    #puts "%s - %s" % [ data[:name], data[:id] ]
    ScraperWiki.save_sqlite([:id], data)
    go_back
end

url = 'http://www.parliament.gov.eg/members/'
scrape_list(url, 1)
