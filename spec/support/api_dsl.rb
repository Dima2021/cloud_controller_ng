require 'active_support/concern'

module ApiDsl
  extend ActiveSupport::Concern

  def validate_response(model, json, expected_values = {}, ignored_attributes = [])
    ignored_attributes.push :guid
    expected_attributes_for_model(model).each do |expected_attribute|
      # refactor: pass exclusions, and figure out which are valid to not be there
      next if ignored_attributes.include? expected_attribute

      # if a relationship is not present, its url should not be present
      next if field_is_url_and_relationship_not_present?(json, expected_attribute)

      json.should have_key expected_attribute.to_s
      if expected_values.has_key? expected_attribute.to_sym
        json[expected_attribute.to_s].should == expected_values[expected_attribute.to_sym]
      end
    end
  end

  def standard_list_response response_json, model
    standard_paginated_response_format? response_json
    resource = response_json["resources"].first
    standard_entity_response resource, model
  end

  def standard_entity_response json, model, expected_values={}
    json.should include("metadata")
    json.should include("entity")
    standard_metadata_response_format? json["metadata"], model
    validate_response model, json["entity"], expected_values
  end

  def standard_paginated_response_format? json
    validate_response VCAP::RestAPI::PaginatedResponse, json
  end

  def standard_metadata_response_format? json, model
    ignored_attributes = []
    ignored_attributes = [:updated_at] unless model_has_updated_at?(model)
    validate_response VCAP::RestAPI::MetadataMessage, json, {}, ignored_attributes
  end

  def expected_attributes_for_model model
    return model.fields.keys if model.respond_to? :fields
    "VCAP::CloudController::#{model.to_s.classify}".constantize.export_attrs
  end

  def parsed_response
    parse(response_body)
  end

  def field_is_url_and_relationship_not_present?(json, field)
    if field =~ /(.*)_url$/
      !json["#$1_guid".to_sym]
    end
  end

  def audited_event event
    attributes = event.columns.map do |column|
      if column == :metadata
        {attribute_name: column.to_s, value: JSON.pretty_generate(JSON.parse(event[column])), is_json: true}
      else
        {attribute_name: column.to_s, value: event[column], is_json: false}
      end
    end

    RSpec.current_example.metadata[:audit_records] ||= []
    RSpec.current_example.metadata[:audit_records] << {type: event[:type], attributes: attributes}
  end

  def fields_json(overrides = {})
    Yajl::Encoder.encode(required_fields.merge(overrides), pretty: true)
  end

  def required_fields
    self.class.metadata[:fields].inject({}) do |memo, field|
      memo[field[:name]] = (field[:valid_values] || field[:example_values]).first if field[:required]
      memo
    end
  end

  private

  def model_has_updated_at?(model)
    "VCAP::CloudController::#{model.to_s.classify}".constantize.columns.include?(:updated_at)
  end

  module ClassMethods
    def api_version
      "/v2"
    end

    def root(model)
      "#{api_version}/#{model.to_s.pluralize}"
    end

    def standard_model_list(model, controller, options = {})
      outer_model_description = ''
      model_name = options[:path] || model
      if options[:outer_model]
        model_name = options[:path] if options[:path]
        path = "#{options[:outer_model].to_s.pluralize}/:guid/#{model_name}"
        outer_model_description = " in #{options[:outer_model]}"
      else
        path = options[:path] || model
      end

      get root(path) do
        standard_list_parameters controller
        example_request "List all #{model_name.to_s.pluralize.titleize}#{outer_model_description}" do
          standard_list_response parsed_response, model
        end
      end
    end

    def standard_model_get(model, options = {})
      path = options[:path] || model
      get "#{root(path)}/:guid" do
        example_request "Retrieve a Particular #{path.to_s.capitalize}" do
          standard_entity_response parsed_response, model
          if options[:nested_associations]
            options[:nested_associations].each do |association_name|
              expect(parsed_response['entity'].keys).to include("#{association_name}_url")
            end
          end
        end
      end
    end

    def standard_model_delete(model)
      delete "#{root(model)}/:guid" do
        request_parameter :async, "Will run the delete request in a background job. Recommended: 'true'."

        example_request "Delete a Particular #{model.to_s.capitalize}" do
          expect(status).to eq 204
          after_standard_model_delete(guid) if respond_to?(:after_standard_model_delete)
        end
      end
    end

    def standard_model_delete_without_async(model)
      delete "#{root(model)}/:guid" do
        example_request "Delete a Particular #{model.to_s.capitalize}" do
          expect(status).to eq 204
          after_standard_model_delete(guid) if respond_to?(:after_standard_model_delete)
        end
      end
    end

    def standard_list_parameters(controller)
      if controller.query_parameters.size > 0
        query_parameter_description = "Parameters used to filter the result set."
        query_parameter_description += " Valid filters: #{controller.query_parameters.to_a.join(", ")}"
        request_parameter :q, query_parameter_description
      end
      request_parameter :page, "Page of results to fetch"
      request_parameter :'results-per-page', "Number of results per page"
      request_parameter :'inline-relations-depth', "0 - don't inline any relations and return URLs.  Otherwise, inline to depth N.", deprecated: true
    end

    def request_parameter(name, description, options = {})
      parameter name, description, options
      metadata[:request_parameters] ||= []
      metadata[:request_parameters].push(options.merge(:name => name.to_s, :description => description))
    end

    def field(name, description = "", options = {})
      metadata[:fields] = metadata[:fields] ? metadata[:fields].dup : []
      metadata[:fields].push(options.merge(:name => name.to_s, :description => description))
    end

    def authenticated_request
      header "AUTHORIZATION", :admin_auth_header
    end
  end
end
