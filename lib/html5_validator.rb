require 'rubygems'
require 'bundler'
Bundler.require
require 'json'
require 'rest_client'
require 'spec'
require 'html5_validator/rspec'
require 'popen4'
require 'net/http'

module Html5Validator
  class Validator
    BASE_URI = 'http://html5.validator.nu'
    HEADERS = { 'Content-Type' => 'text/html; charset=utf-8', 'Content-Encoding' => 'UTF-8' }
    attr_reader :errors

    def initialize(proxy = nil)
      RestClient.proxy = proxy unless proxy.nil?
    end

    # Validate the markup of a String
    def validate_text(text)
      response = RestClient.post "#{BASE_URI}/?out=json", text, HEADERS
      @json = JSON.parse(response.body)
      @errors = retrieve_errors
    end

    # Validate the markup of a URI
    def validate_uri(uri)
      response = RestClient.get BASE_URI, :params => { :doc => uri, :out => 'json' }
      @json = JSON.parse(response.body)
      @errors = retrieve_errors
    end

    # TODO - Flesh out the file upload method
    # Validate the markup of a file
    def validate_file(file)
    end

    def inspect
      @errors.map do |err|
        "- Error: #{err['message']}"
      end.join("\n")
    end

    def valid?
      @errors.length == 0
    end

    private

    def retrieve_errors
      @json['messages'].select { |mssg| mssg['type'] == 'error' }
    end
  end

  class JavaValidator
    attr_reader :errors
    
    def initialize(path = nil)
      @validator_path = path || bundled_validator_path
    end

    # Validate the markup of a String
    def validate_text(text)
      res = nil
      Tempfile.open "html5_validator" do |file|
        file.write text
        file.rewind
        res = validate_file file
      end
      res
    end

    # Validate the markup of a URI
    def validate_uri(uri)
      validate_text(Net::HTTP.get(URI.parse(uri)))
    end

    # Validate the markup of a file
    def validate_file(file)
      status =
        POpen4::popen4("java -cp '#{@validator_path}' nu.validator.htmlparser.tools.HTML2HTML #{file.path}") do |stdout, stderr|
          stdout.read
          @errors, @warnings = parse_error_output(stderr.read)
        end
      @errors = ["Cannot run Java HTML5 validator #{@validator_path}: #{status.inspect}"] unless status.exitstatus == 0
    end

    def bundled_validator_path
      File.expand_path(File.join(File.dirname(__FILE__), "java", "htmlparser-1.3.1.jar"))
    end

    def inspect
      @errors.map do |err|
        "- Error: #{err['message']}"
      end.join("\n")
    end

    def valid?
      @errors.length == 0
    end

    private

    def find_blocks(lines, block_type, size = 4)
      i = 0
      blocks = []
      while i < lines.length
        line = lines[i]
        if lines[i].strip.downcase == "#{block_type.downcase}:" && i+3 < lines.length
          blocks << {'message' => lines[i+1],
                     'file'    => lines[i+2],
                     'line'    => lines[i+3],
                     'type'    => block_type}
          i += 4
        else
          i += 1
        end
      end
      blocks
    end

    def parse_error_output(stderr)
      @errors = []
      @warnings = []
      
      lines = stderr.strip.split("\n")
      
      @errors = find_blocks(lines, 'Error', 4)
      @warnings = find_blocks(lines, 'Warning', 4)
      
      [@errors, @warnings]
    end


  end
end
