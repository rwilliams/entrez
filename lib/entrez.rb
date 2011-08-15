require 'httparty'
require 'httparty/response_ext'
require 'query_string_normalizer'

class Entrez

  include HTTParty
  base_uri 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils'
  default_params tool: 'ruby', email: (ENV['ENTREZ_EMAIL'] || raise('please set ENTREZ_EMAIL environment variable'))
  query_string_normalizer QueryStringNormalizer

  class << self

    # E.g. Entrez.EFetch('snp', id: 123, retmode: :xml)
    def EFetch(db, params = {})
      perform '/efetch.fcgi', db, params
    end

    # E.g. Entrez.EInfo('gene', retmode: :xml)
    def EInfo(db, params = {})
      perform '/einfo.fcgi', db, params
    end

    # E.g. Entrez.ESearch('genomeprj', {WORD: 'hapmap', SEQS: 'inprogress'}, retmode: :xml)
    # search_terms can also be string literal.
    def ESearch(db, search_terms = {}, params = {})
      params[:term] = search_terms.is_a?(Hash) ? convert_search_term_hash(search_terms) : search_terms
      response = perform '/esearch.fcgi', db, params
      response
    end

    # E.g. Entrez.ESummary('snp', id: 123, retmode: :xml)
    def ESummary(db, params = {})
      perform '/esummary.fcgi', db, params
    end

    def perform(utility_path, db, params = {})
      respect_query_limit
      request_times << Time.now.to_f
      get utility_path, :query => {db: db}.merge(params)
    end

    # Take a ruby hash and convert it to an ENTREZ search term.
    # E.g. convert_search_term_hash {WORD: 'low coverage', SEQS: 'inprogress'}
    # #=> 'low coverage[WORD]+AND+inprogress[SEQS]'
    def convert_search_term_hash(hash, operator = 'AND')
      raise UnknownOperator.new(operator) unless ['AND', 'OR'].include?(operator)
      str = hash.map do |field, value|
        value = value.join(',') if value.is_a?(Array)
        "#{value}[#{field}]"
      end.join("+#{operator}+")
      if operator == 'OR'
        str = "(#{str})"
      end
      str
    end

    private

    # NCBI does not allow more than 3 requests per second.
    # Unless 3 requests ago was more than 1 second ago,
    # sleep for enough time to honor limit.
    def respect_query_limit
      three_requests_ago = request_times[-3]
      return unless three_requests_ago
      time_for_last_3_requeests = Time.now.to_f - three_requests_ago
      enough_time_has_passed = time_for_last_3_requeests >= 1
      unless enough_time_has_passed
        sleep_time = 1 - time_for_last_3_requeests
        STDERR.puts "sleeping #{sleep_time}"
        sleep(sleep_time)
      end
    end

    def request_times
      @request_times ||= []
    end

  end

  class UnknownOperator < StandardError
    def initialize(operator)
      super "Unknown operator: #{operator}"
    end
  end

end
