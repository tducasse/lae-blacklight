# -*- encoding : utf-8 -*-
# frozen_string_literal: true
class SolrDocument
  include Blacklight::Solr::Document
  # include Blacklight::Gallery::OpenseadragonSolrDocument

  # self.unique_key = 'id'

  # Email uses the semantic field mappings below to generate the body of an email.
  SolrDocument.use_extension(Blacklight::Document::Email)

  # SMS uses the semantic field mappings below to generate the body of an SMS email.
  SolrDocument.use_extension(Blacklight::Document::Sms)

  SolrDocument.use_extension(LaeExportExtension)

  # DublinCore uses the semantic field mappings below to assemble an OAI-compliant Dublin Core document
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Solr::Document::ExtendableClassMethods#field_semantics
  # and Blacklight::Solr::Document#to_semantic_values
  # Recommendation: Use field names from Dublin Core
  # use_extension( Blacklight::Solr::Document::DublinCore)
end
