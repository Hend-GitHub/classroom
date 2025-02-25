# frozen_string_literal: true

require "rails_helper"

RSpec.describe Orgs::LtiConfigurationsController, type: :controller do
  let(:organization) { classroom_org }
  let(:user)         { classroom_teacher }

  before(:each) do
    sign_in_as(user)
  end

  describe "GET #new", :vcr do
    context "with flipper disabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].disable
      end

      it "returns not_found" do
        get :new, params: { id: organization.slug }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with flipper enabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].enable
        get :new, params: { id: organization.slug }
      end

      it "returns success status" do
        expect(response).to have_http_status(:success)
      end

      it "renders new template" do
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET #info", :vcr do
    context "with flipper disabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].disable
      end

      it "returns not_found" do
        get :info, params: { id: organization.slug }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with flipper enabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].enable
        get :info, params: { id: organization.slug }
      end

      it "returns success status" do
        expect(response).to have_http_status(:success)
      end

      it "renders new template" do
        expect(response).to render_template(:info)
      end
    end
  end

  describe "GET #show", :vcr do
    context "with flipper disabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].disable
      end

      it "returns not_found" do
        get :show, params: { id: organization.slug }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with flipper enabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].enable
      end

      context "with lti_configuration present" do
        before(:each) do
          create(:lti_configuration, organization: organization)
          get :show, params: { id: organization.slug }
        end

        it "returns success status" do
          expect(response).to have_http_status(:success)
        end

        it "renders show template" do
          expect(response).to render_template(:show)
        end
      end

      context "with no existing lti_configuration" do
        it "redirects to new" do
          get :show, params: { id: organization.slug }
          expect(response).to redirect_to(info_lti_configuration_path(organization))
        end
      end
    end
  end

  describe "POST #create", :vcr do
    context "with flipper enabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].enable
      end

      it "creates lti_configuration if lms_type is set" do
        post :create, params: { id: organization.slug, lti_configuration: { lms_type: :other } }
        expect(organization.lti_configuration).to_not be_nil
        expect(response).to redirect_to(lti_configuration_path(organization))
      end

      it "redirects to :new if lms_type is unset" do
        post :create, params: { id: organization.slug }
        expect(organization.lti_configuration).to be_nil
        expect(response).to redirect_to(new_lti_configuration_path(organization))
      end

      context "with existing google classrom" do
        before do
          organization.update_attributes(google_course_id: "1234")
        end

        it "alerts user about existing configuration" do
          get :create, params: { id: organization.slug }
          expect(response).to redirect_to(edit_organization_path(organization))
          expect(flash[:alert]).to eq(
            "A Google Classroom configuration exists. Please remove configuration before creating a new one."
          )
        end
      end

      context "with an existing roster" do
        before do
          organization.roster = create(:roster)
          organization.save!
          organization.reload
        end

        it "alerts user that there is an existing roster" do
          post :create, params: { id: organization.slug }
          expect(response).to redirect_to(edit_organization_path(organization))
          expect(flash[:alert]).to eq(
            "We are unable to link your classroom organization to an LMS"\
            "because a roster already exists. Please delete your current roster and try again."
          )
        end
      end
    end

    context "with flipper disabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].disable
      end

      it "does not create lti_configuration" do
        post :create, params: { id: organization.slug }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE #destroy", :vcr do
    context "with flipper enabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].enable
      end

      context "with lti configuration present" do
        before(:each) do
          create(:lti_configuration, organization: organization)
          get :show, params: { id: organization.slug }
        end

        it "deletes lti_configuration" do
          delete :destroy, params: { id: organization.slug }
          organization.reload
          expect(organization.lti_configuration).to be_nil
          expect(response).to redirect_to(edit_organization_path(id: organization))
          expect(flash[:alert]).to be_present
        end
      end
    end

    context "with flipper disabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].disable
      end

      it "does not create lti_configuration" do
        post :create, params: { id: organization.slug }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH #update", :vcr do
    context "with flipper on" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].enable
      end

      context "with existing lti_configuration" do
        before(:each) do
          create(:lti_configuration, organization: organization)
        end

        it "updates with new LMS url" do
          options = { lms_link: "https://github.com" }
          patch :update, params: { id: organization.slug, lti_configuration: options }

          organization.lti_configuration.reload
          expect(organization.lti_configuration.lms_link).to eq("https://github.com")
          expect(flash[:success]).to eq("The configuration was sucessfully updated.")
          expect(response).to redirect_to(lti_configuration_path(organization))
        end
      end

      context "with no existing lti_configuration" do
        it "does not update or create" do
          options = { lms_link: "https://github.com" }
          patch :update, params: { id: organization.slug, lti_configuration: options }
          expect(response).to redirect_to(info_lti_configuration_path(organization))
          expect(organization.lti_configuration).to be_nil
        end
      end
    end

    context "with flipper disabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].disable
      end

      it "returns a not_found" do
        options = { lms_link: "https://github.com" }
        patch :update, params: { id: organization.slug, lti_configuration: options }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET #autoconfigure", :vcr do
    context "with existing lti_configuration" do
      before(:each) do
        create(:lti_configuration, organization: organization)
      end

      it "returns an xml configuration" do
        get :autoconfigure, params: { id: organization.slug }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to eq "application/xml"
      end
    end

    context "with no existing lti_configuration" do
      it "does not generate an xml configuration" do
        patch :autoconfigure, params: { id: organization.slug }
        expect(response).to redirect_to(info_lti_configuration_path(organization))
        expect(organization.lti_configuration).to be_nil
      end
    end
  end

  describe "GET #complete", :vcr do
    context "with flipper on" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].enable
      end

      context "with existing lti_configuration" do
        before(:each) do
          create(:lti_configuration, organization: organization)
        end

        context "with user who is an instructor" do
          it "returns success page" do
            get :complete, params: { id: organization.slug }
            expect(response).to have_http_status(:success)
          end
        end
      end
    end

    context "with flipper disabled" do
      before(:each) do
        GitHubClassroom.flipper[:lti_launch].disable
      end

      it "returns a not_found" do
        get :complete, params: { id: organization.slug }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
