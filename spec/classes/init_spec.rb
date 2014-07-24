require 'spec_helper'
describe 'puma' do

  context 'with defaults for all parameters' do
    it { should contain_class('puma') }
  end
end
