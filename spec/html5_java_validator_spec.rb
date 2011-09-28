require 'html5_validator'

describe "Html5JavaValidator" do
  
  describe "when using the custom matcher" do
    it "should not be valid html5 when supplied with invalid content" do
      @html = File.open('spec/fixtures/invalid_html.html').read
      @html.should_not be_valid_html5
    end

    it "should be valid html5 when supplied with valid content" do
      @html = File.open('spec/fixtures/valid_html.html').read
      @html.should be_valid_html5
    end
  end

  before do
    @validator = Html5Validator::JavaValidator.new
  end

  it "should be an instance of Html5Validator::Validator" do
    @validator.should be_an_instance_of Html5Validator::JavaValidator
  end

  context "when parsing the validator output" do
    let :output do
      <<-end_of_doc.gsub(/^ +/, '')
        Error:
        Unclosed element “section”.
        File: Unknown
        Line: 8 Col: 11
        
        Warning:
        The character encoding of the document was not declared.
        File: Unknown
        Line: -1 Col: -1
        
        Error:
        End tag for “body” seen but there were unclosed elements.
        File: Unknown
        Line: 9 Col: 7
      end_of_doc
    end

    before do
      @errors, @warnings = @validator.send(:parse_error_output, output)
    end
    
    it "should find two errors" do
      @errors.should have(2).items
    end
    
    it "should have one error for unclosed element section" do
      @errors.select {|x| x['message'].match(/unclosed element.*section/i)}.should have(1).item
    end

    it "should have one error for unclosed elements while body closed" do
      @errors.select {|x| x['message'].match(/end tag for.*body.*unclosed/i)}.should have(1).item
    end

    it "should find one warning" do
      @warnings.should have(1).item
    end
    
    it "it should have a warning about document encoding" do
      @warnings[0]['message'].should == 'The character encoding of the document was not declared.'
    end

  end

  context "validating a uri" do
    describe "when supplied with an invalid url" do

      before do
        @validator.validate_uri('http://www.google.co.uk/')
      end

      it "should not be valid html5" do
        @validator.valid?.should be_false
      end

      it "should return thirty-nine errors" do
        # @validator.errors.each {|error| puts "Error msg = #{error['message']}\n\n" }
        @validator.errors.should have_at_least(39).items
      end
    end

    describe "when supplied with a valid url" do

      before do
        @validator.validate_uri('http://damiannicholson.com/')
      end

      it "should be valid html5" do
        @validator.valid?.should be_true
      end

      it "should return zero errors" do
        @validator.errors.should have(0).items
      end
    end
  end

  context "validating text" do
    describe "when supplied with invalid html" do

      before do
        @html = File.open('spec/fixtures/invalid_html.html').read
        @validator.validate_text(@html)
      end

      it "should not be valid html5" do
         @validator.valid?.should be_false
      end

      it "should return two errors" do
        @validator.errors.should have(2).items
      end

      it "should include an error complaining about the lack of a closing section tag" do
        @validator.inspect.should include('Unclosed element')
      end

    end

    describe "when supplied with valid html" do

      before do
        @html = File.open('spec/fixtures/valid_html.html').read
        @validator.validate_text(@html)
      end

      it "should be valid html5" do
         @validator.valid?.should be_true
      end

      it "should return no errors" do
        @validator.errors.should have(0).items
      end

    end
  end
end
