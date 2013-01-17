require 'spec_helper'

describe Sidekiq::Queue do
  context 'singleton' do
    shared_examples :constructor do
      it 'with default name' do
        new_object = -> { described_class.send constructor }
        new_object.call.should == new_object.call
      end

      it 'with given name' do
        new_object = ->(name) { described_class.send constructor, name }
        new_object.call('name').should == new_object.call('name')
      end
    end

    context '.new' do
      let(:constructor) { :new }
      it_behaves_like :constructor
    end

    context '.[]' do
      let(:constructor) { :[] }
      it_behaves_like :constructor
    end
  end
end
