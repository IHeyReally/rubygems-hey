# frozen_string_literal: true
require "spec_helper"
require "bundler/fetcher"

RSpec.describe Bundler::Fetcher do
  let(:uri) { URI("https://example.com") }
  let(:remote) { double("remote", :uri => uri, :original_uri => nil) }

  subject(:fetcher) { Bundler::Fetcher.new(remote) }

  before do
    allow(Bundler).to receive(:root) { Pathname.new("root") }
  end

  describe "#connection" do
    context "when Gem.configuration doesn't specify http_proxy" do
      it "specify no http_proxy" do
        expect(fetcher.http_proxy).to be_nil
      end
      it "consider environment vars when determine proxy" do
        with_env_vars("HTTP_PROXY" => "http://proxy-example.com") do
          expect(fetcher.http_proxy).to match("http://proxy-example.com")
        end
      end
    end
    context "when Gem.configuration specifies http_proxy " do
      let(:proxy) { "http://proxy-example2.com" }
      before do
        allow(Bundler.rubygems.configuration).to receive(:[]).with(:http_proxy).and_return(proxy)
      end
      it "consider Gem.configuration when determine proxy" do
        expect(fetcher.http_proxy).to match("http://proxy-example2.com")
      end
      it "consider Gem.configuration when determine proxy" do
        with_env_vars("HTTP_PROXY" => "http://proxy-example.com") do
          expect(fetcher.http_proxy).to match("http://proxy-example2.com")
        end
      end
      context "when the proxy is :no_proxy" do
        let(:proxy) { :no_proxy }
        it "does not set a proxy" do
          expect(fetcher.http_proxy).to be_nil
        end
      end
    end

    context "when a rubygems source mirror is set" do
      let(:orig_uri) { URI("http://zombo.com") }
      let(:remote_with_mirror) do
        double("remote", :uri => uri, :original_uri => orig_uri, :anonymized_uri => uri)
      end

      let(:fetcher) { Bundler::Fetcher.new(remote_with_mirror) }

      it "sets the 'X-Gemfile-Source' header containing the original source" do
        expect(
          fetcher.send(:connection).override_headers["X-Gemfile-Source"]
        ).to eq("http://zombo.com")
      end
    end

    context "when there is no rubygems source mirror set" do
      let(:remote_no_mirror) do
        double("remote", :uri => uri, :original_uri => nil, :anonymized_uri => uri)
      end

      let(:fetcher) { Bundler::Fetcher.new(remote_no_mirror) }

      it "does not set the 'X-Gemfile-Source' header" do
        expect(fetcher.send(:connection).override_headers["X-Gemfile-Source"]).to be_nil
      end
    end

    context "when there are proxy environment variable(s) set" do
      it "consider http_proxy" do
        with_env_vars("HTTP_PROXY" => "http://proxy-example3.com") do
          expect(fetcher.http_proxy).to match("http://proxy-example3.com")
        end
      end
      it "consider no_proxy" do
        with_env_vars("HTTP_PROXY" => "http://proxy-example4.com", "NO_PROXY" => ".example.com,.example.net") do
          expect(
            fetcher.send(:connection).no_proxy
          ).to eq([".example.com", ".example.net"])
        end
      end
    end
  end

  describe "#user_agent" do
    it "builds user_agent with current ruby version and Bundler settings" do
      allow(Bundler.settings).to receive(:all).and_return(%w(foo bar))
      expect(fetcher.user_agent).to match(%r{bundler/(\d.)})
      expect(fetcher.user_agent).to match(%r{rubygems/(\d.)})
      expect(fetcher.user_agent).to match(%r{ruby/(\d.)})
      expect(fetcher.user_agent).to match(%r{options/foo,bar})
    end

    describe "include CI information" do
      it "from one CI" do
        with_env_vars("JENKINS_URL" => "foo") do
          ci_part = fetcher.user_agent.split(" ").find {|x| x.match(%r{\Aci/}) }
          expect(ci_part).to match("jenkins")
        end
      end

      it "from many CI" do
        with_env_vars("TRAVIS" => "foo", "CI_NAME" => "my_ci") do
          ci_part = fetcher.user_agent.split(" ").find {|x| x.match(%r{\Aci/}) }
          expect(ci_part).to match("travis")
          expect(ci_part).to match("my_ci")
        end
      end
    end
  end
end
