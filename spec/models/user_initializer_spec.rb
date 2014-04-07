require 'spec_helper'

describe UserInitializer do
  subject { described_class.new(omniauth_user_data, user) }
  let(:omniauth_data) do
    omniauth_fixture = Rails.root.join(
      'spec',
      'fixtures',
      'omniauth_data.yml'
    )
    YAML.load(File.read(omniauth_fixture)).with_indifferent_access
  end
  let(:omniauth_user_data) do
    OmniauthUserSerializer.new(omniauth_data).to_h
  end
  let!(:oauth_provider) do
    OauthProvider.create(
      name:   omniauth_data['provider'],
      key:    '123',
      secret: '123'
    )
  end

  describe 'setup' do
    context 'when allowed to setup' do
      before { subject.stub(:can_setup?).and_return(true) }

      context 'when receiving a valid user in the initialization' do
        let(:user) { FactoryGirl.create(:user) }

        context 'when authorization already exists' do
          let!(:authorization) do
            FactoryGirl.create(
              :authorization,
              oauth_provider: oauth_provider,
              uid:            omniauth_data[:uid],
              user:           user
            )
          end

          it 'updates user\'s attributes with omniauth urls data' do
            omniauth_urls_data = { facebook_url: 'http://fb.com/juquinhadasilva' }
            subject.stub(:omniauth_urls_data).and_return(omniauth_urls_data)
            expect(user).to receive(:update_attributes).with(omniauth_urls_data)
            subject.setup
          end

          it 'updates authorization\'s access_token' do
            expect {
              subject.setup
            }.to change { authorization.reload.access_token }
          end
        end

        context 'when no related authorization exists' do
          it 'creates one' do
            subject.setup
            expect(
              Authorization.exists?(
                oauth_provider: oauth_provider,
                user:           user,
                uid:            omniauth_user_data[:authorizations_attributes].first[:uid],
                access_token:   omniauth_user_data[:authorizations_attributes].first[:access_token]
              )
            ).to be_true
          end
        end
      end

      context 'when no user is given in the initialization' do
        let(:user) { nil }

        it 'creates an user' do
          subject.setup
          expect(
            User.exists?(email: omniauth_user_data[:email])
          ).to be_true
        end

        it 'creates an authorization' do
          subject.setup
          user = User.find_by(email: omniauth_user_data[:email])
          expect(
            Authorization.exists?(
              oauth_provider: oauth_provider,
              user:           user,
              uid:            omniauth_user_data[:authorizations_attributes].first[:uid],
              access_token:   omniauth_user_data[:authorizations_attributes].first[:access_token]
            )
          ).to be_true
        end
      end
    end

    context 'when not allowed to setup' do
      let(:user) { FactoryGirl.create(:user) }
      before { subject.stub(:can_setup?).and_return(false) }

      it 'creates no user' do
        expect {
          subject.setup
        }.to_not change(User, :count)
      end

      it 'creates no authorization' do
        expect {
          subject.setup
        }.to_not change(Authorization, :count)
      end
    end
  end
end
