#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/module_files'

module ModuleFilesTerminusTesting
    def setup
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @module_files_class = Class.new(Puppet::Indirector::ModuleFiles) do
            def self.to_s
                "Testing::Mytype"
            end
        end

        @module_files = @module_files_class.new

        @uri = "puppetmounts://host/modules/my/local/file"
        @module = Puppet::Module.new("mymod", "/module/path")
    end
end

describe Puppet::Indirector::ModuleFiles, " when finding files" do
    include ModuleFilesTerminusTesting

    it "should strip off the leading '/modules' mount name" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        @module_files.find(@uri)
    end

    it "should not strip off leading terms that start with '/modules' but are longer words" do
        Puppet::Module.expects(:find).with('modulestart', nil).returns nil
        @module_files.find("puppetmounts://host/modulestart/my/local/file")
    end

    it "should search for a module whose name is the first term in the remaining file path" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        @module_files.find(@uri)
    end

    it "should search for a file relative to the module's files directory" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file")
        @module_files.find(@uri)
    end

    it "should return nil if the module does not exist" do
        Puppet::Module.expects(:find).with('my', nil).returns nil
        @module_files.find(@uri).should be_nil
    end

    it "should return nil if the module exists but the file does not" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file").returns(false)
        @module_files.find(@uri).should be_nil
    end

    it "should return an instance of the model created with the full path if a module is found and the file exists" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
        @model.expects(:new).with("/module/path/files/local/file", :links => nil).returns(:myinstance)
        @module_files.find(@uri).should == :myinstance
    end

    it "should use the node's environment to look up the module if the node name is provided" do
        node = stub "node", :environment => "testing"
        Puppet::Node.expects(:find).with("mynode").returns(node)
        Puppet::Module.expects(:find).with('my', "testing")
        @module_files.find(@uri, :node => "mynode")
    end

    it "should use the local environment setting to look up the module if the node name is not provided and the environment is not set to ''" do
        Puppet.settings.stubs(:value).with(:environment).returns("testing")
        Puppet::Module.expects(:find).with('my', "testing")
        @module_files.find(@uri)
    end

    it "should not use an environment when looking up the module if the node name is not provided and the environment is set to ''" do
        Puppet.settings.stubs(:value).with(:environment).returns("")
        Puppet::Module.expects(:find).with('my', nil)
        @module_files.find(@uri)
    end
end

describe Puppet::Indirector::ModuleFiles, " when returning instances" do
    include ModuleFilesTerminusTesting

    it "should pass the provided :links setting on to the instance if one is provided" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
        @model.expects(:new).with("/module/path/files/local/file", :links => :mytest)
        @module_files.find(@uri, :links => :mytest)
    end
end

describe Puppet::Indirector::ModuleFiles, " when authorizing" do
    include ModuleFilesTerminusTesting

    before do
        @configuration = mock 'configuration'
        Puppet::FileServing::Configuration.stubs(:create).returns(@configuration)
    end

    it "should have an authorization hook" do
        @module_files.should respond_to(:authorized?)
    end

    it "should deny the :destroy method" do
        @module_files.authorized?(:destroy, "whatever").should be_false
    end

    it "should deny the :save method" do
        @module_files.authorized?(:save, "whatever").should be_false
    end

    it "should use the file server configuration to determine authorization" do
        @configuration.expects(:authorized?)
        @module_files.authorized?(:find, "puppetmounts://host/my/file")
    end

    it "should use the path directly from the URI if it already includes /modules" do
        @configuration.expects(:authorized?).with { |uri, *args| uri == "/modules/my/file" }
        @module_files.authorized?(:find, "puppetmounts://host/modules/my/file")
    end

    it "should add /modules to the file path if it's not included in the URI" do
        @configuration.expects(:authorized?).with { |uri, *args| uri == "/modules/my/file" }
        @module_files.authorized?(:find, "puppetmounts://host/my/file")
    end

    it "should pass the node name to the file server configuration" do
        @configuration.expects(:authorized?).with { |key, options| options[:node] == "mynode" }
        @module_files.authorized?(:find, "puppetmounts://host/my/file", :node => "mynode")
    end

    it "should pass the IP address to the file server configuration" do
        @configuration.expects(:authorized?).with { |key, options| options[:ipaddress] == "myip" }
        @module_files.authorized?(:find, "puppetmounts://host/my/file", :ipaddress => "myip")
    end

    it "should return false if the file server configuration denies authorization" do
        @configuration.expects(:authorized?).returns(false)
        @module_files.authorized?(:find, "puppetmounts://host/my/file").should be_false
    end

    it "should return true if the file server configuration approves authorization" do
        @configuration.expects(:authorized?).returns(true)
        @module_files.authorized?(:find, "puppetmounts://host/my/file").should be_true
    end
end

describe Puppet::Indirector::ModuleFiles, " when searching for files" do
    include ModuleFilesTerminusTesting

    it "should strip off the leading '/modules' mount name" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        @module_files.search(@uri)
    end

    it "should not strip off leading terms that start with '/modules' but are longer words" do
        Puppet::Module.expects(:find).with('modulestart', nil).returns nil
        @module_files.search("puppetmounts://host/modulestart/my/local/file")
    end

    it "should search for a module whose name is the first term in the remaining file path" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        @module_files.search(@uri)
    end

    it "should search for a file relative to the module's files directory" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file")
        @module_files.search(@uri)
    end

    it "should return nil if the module does not exist" do
        Puppet::Module.expects(:find).with('my', nil).returns nil
        @module_files.search(@uri).should be_nil
    end

    it "should return nil if the module exists but the file does not" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file").returns(false)
        @module_files.search(@uri).should be_nil
    end

    it "should use the node's environment to look up the module if the node name is provided" do
        node = stub "node", :environment => "testing"
        Puppet::Node.expects(:find).with("mynode").returns(node)
        Puppet::Module.expects(:find).with('my', "testing")
        @module_files.search(@uri, :node => "mynode")
    end

    it "should use the local environment setting to look up the module if the node name is not provided and the environment is not set to ''" do
        Puppet.settings.stubs(:value).with(:environment).returns("testing")
        Puppet::Module.expects(:find).with('my', "testing")
        @module_files.search(@uri)
    end

    it "should not use an environment when looking up the module if the node name is not provided and the environment is set to ''" do
        Puppet.settings.stubs(:value).with(:environment).returns("")
        Puppet::Module.expects(:find).with('my', nil)
        @module_files.search(@uri)
    end

    it "should use :path2instances from the terminus_helper to return instances if a module is found and the file exists" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
        @module_files.expects(:path2instances).with("/module/path/files/local/file", {})
        @module_files.search(@uri)
    end

    it "should pass any options on to :path2instances" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
        @module_files.expects(:path2instances).with("/module/path/files/local/file", :testing => :one, :other => :two)
        @module_files.search(@uri, :testing => :one, :other => :two)
    end
end
