require 'rails_helper'
require 'nokogiri'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.preserve_exact_body_bytes do |http_message|
    http_message.body.encoding.name == 'ASCII-8BIT' ||
    !http_message.body.valid_encoding?
  end
end

vcr_options = {
  record: :new_episodes, # See https://www.relishapp.com/vcr/vcr/v/1-6-0/docs/record-modes
  serialize_with: :json
}

RSpec.describe IndexEvent, type: :model, vcr: vcr_options do

  let(:fixture_box_id) { 'puls:00014' }
  let(:doc_ids) { ['004kr', '006tx', '00b84'] }
  let(:solr_xml_string) { IO.read(File.join(Rails.root, 'spec/fixtures/files/solr.xml')) }
  let(:solr) { RSolr.connect(url: described_class.send(:solr_url)) }

  describe 'IndexEvent.get_boxes_data' do

    it 'gets a an Array of Hashes' do
      boxes = described_class.get_boxes_data
      expect(boxes.class).to be Array
      expect(boxes.all? { |box| box.kind_of?(Hash) }).to be_truthy
    end

    it 'raises an error if the service in not available (bad url or whatever)' do
      bogus = 'http://notaurl.foo'
      expect { described_class.get_boxes_data(url: bogus) }.to raise_error
    end

  end

  describe 'IndexEvent.get_solr_xml' do

    it 'gets solr-flavored XML' do
      # use #send to test this protected method
      folder_xml = described_class.send(:get_solr_xml, box_id: fixture_box_id)
      doc = Nokogiri::XML(folder_xml)
      expect(doc.xpath('/*').first.name).to eq 'add'
    end

    it 'raises an error if the service in not available (bad url or whatever)' do
      bogus_id = '12345'
      expect { described_class.send(:get_solr_xml, box_id: bogus_id) }.to raise_error
    end

  end

  describe 'IndexEvent.post_to_solr' do
    # You may find these helpful as well to double check that your Solr is working.
    # curl -v -X POST -H "Content-Type:application/xml" --data-binary @spec/fixtures/files/solr.xml "http://localhost:8983/solr/blacklight-core/update"
    # curl -v -X POST -H "Content-Type:application/xml" --data '<commit/>' "http://localhost:8983/solr/blacklight-core/update"
    # curl -v -X POST -H "Content-Type:application/xml" --data '<delete><query>*:*</query></delete>' "http://localhost:8983/solr/blacklight-core/update"
    before do
      described_class.post_to_solr('<delete><query>*:*</query></delete>')
    end
    it 'does' do
      described_class.post_to_solr(solr_xml_string)
      # check
      params = { fl: ['id'] }
      resp = solr.get('select', params: params )
      expect(resp['response']['numFound']).to eq doc_ids.length
    end

  end

  describe 'IndexEvent.record' do

    it 'registers a new event' do
      before_count = IndexEvent.count
      IndexEvent.record { x = 1 }
      expect(IndexEvent.count).to eq before_count + 1
    end

    it 'tells records exception messages' do
      msg = 'You have died'
      IndexEvent.record { raise msg }
      expect(IndexEvent.last.error_text).to eq "RuntimeError: #{msg}"
    end

    # Can't get this to work...
    # it 'records the name of the Rake task when called as part of one' do
    #   task_name = 'lae:do_nothing'
    #   Rake.application.rake_require '../../lib/tasks/lae'
    #   Rake::Task[task_name].invoke
    #   expect(IndexEvent.last.task).to eq task_name
    # end

    describe 'success' do
      it 'assumes success' do
        IndexEvent.record { x = 1 }
        expect(IndexEvent.last.success).to be_truthy
      end
      it 'sets success to false when there is an exception' do
        IndexEvent.record { raise }
        expect(IndexEvent.last.success).to be_falsey
      end
    end

    describe 'time stamps' do
      it 'registers a start time' do
        IndexEvent.record { x = 1 }
        expect(IndexEvent.last.start).to_not be nil
      end
      it 'registers a finish time' do
        IndexEvent.record { x = 1 }
        expect(IndexEvent.last.finish).to_not be nil
      end
      it 'registers a finish time when an exception occurs' do
        IndexEvent.record { raise }
        expect(IndexEvent.last.finish).to_not be nil
      end
    end

  end

  describe 'IndexEvent.latest_successful' do
    it 'gets it' do
      good = IndexEvent.create(start: Time.now.utc, success: true, task: 'lae:index')
      # bad because not successful
      IndexEvent.create(start: Time.now.utc, success: false, task: 'lae:index')
      # successful, but not lae:index or lae:update
      IndexEvent.create(start: Time.now.utc, success: true, task: 'lae:drop_index')
      expect(IndexEvent.latest_successful).to eq good
    end
  end

  describe 'delete methods', vcr: vcr_options do
    before do
      described_class.post_to_solr('<delete><query>*:*</query></delete>')
      described_class.post_to_solr(solr_xml_string)
    end

    describe 'IndexEvent.delete_one' do
      it 'does' do
        IndexEvent.delete_one(doc_ids[0])
        resp = solr.get('select', params: { fl: ['id'] } )
        expect(resp['response']['numFound']).to eq doc_ids.length-1
      end
    end

    describe 'IndexEvent.delete_index' do
      it 'does' do
        IndexEvent.delete_index
        resp = solr.get('select', params: { fl: ['id'] } )
        expect(resp['response']['numFound']).to eq 0
      end
    end

  end

end






