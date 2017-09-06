# frozen_string_literal: true
require 'rails_helper'

RSpec.describe SolrDocument do
  subject(:solr_document) { described_class.new(solr_hash) }
  let(:solr_adapter) { Valkyrie::MetadataAdapter.find(:index_solr) }
  let(:solr_hash) { solr_adapter.resource_factory.from_resource(book).to_h }
  let(:book) { Book.new }

  describe "#members" do
    context "when the book has members" do
      let(:book) { Persister.save(resource: Book.new(member_ids: Persister.save(resource: Book.new).id)) }
      it "returns them" do
        expect(solr_document.members.first.id).not_to eq book.id
      end
    end
  end

  describe "#member_ids" do
    context "when the book has members" do
      let(:book) { Persister.save(resource: Book.new(member_ids: Persister.save(resource: Book.new).id)) }
      it "returns them" do
        expect(solr_document.member_ids).to eq book.member_ids
      end
    end
    context "when the book has non-ID members" do
      let(:book) { Book.new(id: "test", member_ids: [Persister.save(resource: Book.new).id, "1"]) }
      it "returns them" do
        expect(solr_document.member_ids).to eq book.member_ids
      end
    end
  end

  describe "#children" do
    context "when the collection has children" do
      subject(:children) { solr_document.children }
      let(:solr_document) { described_class.new(solr_hash) }
      let(:solr_hash) { solr_adapter.resource_factory.from_resource(collection).to_h }
      let(:collection) { Persister.save(resource: Collection.new) }
      let(:child_book) { Persister.save(resource: Book.new(a_member_of: [collection.id])) }
      let(:other_book) { Persister.save(resource: Book.new) }
      before do
        child_book
        other_book
      end

      it "returns them" do
        expect(children.count).to eq 1
        expect(children.first.id).to eq child_book.id
      end
    end
  end

  describe '#book?' do
    subject { solr_document.book? }
    context "for a book" do
      let(:book) { Persister.save(resource: Book.new) }
      it { is_expected.to be_truthy }
    end

    context "for a collection" do
      let(:solr_hash) { solr_adapter.resource_factory.from_resource(collection).to_h }
      let(:collection) { Persister.save(resource: Collection.new) }

      it { is_expected.to be_falsey }
    end

    context "for a page" do
      let(:solr_hash) { solr_adapter.resource_factory.from_resource(page).to_h }
      let(:page) { Persister.save(resource: Page.new) }

      it { is_expected.to be_falsey }
    end
  end
end
