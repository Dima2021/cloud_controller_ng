require 'spec_helper'
require 'messages/route_create_message'

module VCAP::CloudController
  RSpec.describe RouteCreateMessage do
    subject { RouteCreateMessage.new(params) }

    describe 'validations' do
      context 'when valid params are given' do
        let(:params) do
          {
            host: 'some-host',
            relationships: {
              space: { data: { guid: 'space-guid' } },
              domain: { data: { guid: 'domain-guid' } },
            }
          }
        end

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:relationships]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            relationships: {
              space: { data: { guid: 'space-guid' } },
              domain: { data: { guid: 'domain-guid' } },
            },
            unexpected: 'meow',
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'host' do
        context 'when not provided' do
          let(:params) do
            {
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } },
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when not a string' do
          let(:params) do
            { host: 5 }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:host]).to include('must be a string')
          end
        end

        context 'when an empty string' do
          let(:params) do
            {
              host: '',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } },
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when it is too long' do
          let(:params) { { host: 'B' * (RouteCreateMessage::MAXIMUM_DOMAIN_LABEL_LENGTH + 1) } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:host]).to include "is too long (maximum is #{RouteCreateMessage::MAXIMUM_DOMAIN_LABEL_LENGTH} characters)"
          end
        end

        context 'when it contains non-alphanumeric characters other than - and _' do
          let(:params) { { host: 'somethingwitha.' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:host]).to match ['must be either "*" or contain only alphanumeric characters, "_", or "-"']
          end
        end

        context 'when its a wildcard' do
          let(:params) do
            {
              host: '*',
              relationships: {
                space: { data: { guid: 'space-guid' } },
                domain: { data: { guid: 'domain-guid' } },
              }
            }
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end
      end

      context 'relationships' do
        context 'relationships is not a hash' do
          let(:params) { { relationships: 'banana' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:relationships]).to include "'relationships' is not a hash"
          end
        end

        context 'when space is missing' do
          let(:params) do
            {
              relationships: {}
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include("'relationships' must include one or more valid relationships")
          end
        end

        context 'when space has an invalid guid' do
          let(:params) do
            {
              relationships: { space: { data: { guid: 32 } } },
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Space guid'))
          end
        end

        context 'when space is malformed' do
          let(:params) do
            {
              relationships: { space: 'asdf' }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Space must be structured like'))
          end
        end

        context 'when domain has an invalid guid' do
          let(:params) do
            {
              relationships: { domain: { data: { guid: 32 } } },
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Domain guid'))
          end
        end

        context 'when domain is malformed' do
          let(:params) do
            {
              relationships: { domain: 'asdf' }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors_on(:relationships)).to include(include('Domain must be structured like'))
          end
        end

        context 'when additional keys are present' do
          let(:params) do
            {
              relationships: {
                space: { data: { guid: 'guid' } },
                other: 'stuff'
              }
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:relationships]).to include("Unknown field(s): 'other'")
          end
        end
      end
    end

    describe 'accessor methods' do
      let(:params) do
        {
          relationships: {
            space: { data: { guid: 'space-guid' } },
            domain: { data: { guid: 'domain-guid' } },
          }
        }
      end

      context 'space_guid' do
        it 'makes the guid accessible' do
          expect(subject).to be_valid
          expect(subject.space_guid).to eq('space-guid')
        end
      end

      context 'domain_guid' do
        it 'makes the guid accessible' do
          expect(subject).to be_valid
          expect(subject.domain_guid).to eq('domain-guid')
        end
      end
    end
  end
end
